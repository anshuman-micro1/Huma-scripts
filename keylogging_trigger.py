"""
Start/stop keylogging alongside OBS recording.

When recording starts, this script:
1. Reads the OBS canvas resolution automatically
2. Launches keylogging.py with --obs-canvas WxH for auto coordinate scaling
3. Writes a recording_start anchor event to the JSONL for time sync
4. Fires a visual sync flash (SYNC_FLASH source)

When recording stops, the keylogger process is stopped and a recording_stop
event is written.
"""

import configparser
import os
import shlex
import subprocess
import sys
import time
import json
import traceback

import obspython as obs

# User-configurable via script properties
python_exe = "python3"
keylogger_script = ""
extra_args = ""  # optional extra args passed to keylogging.py
flash_source_name = "SYNC_FLASH"
flash_duration_ms = 150

_current_jsonl_path = None
_flash_active = False
_proc: subprocess.Popen | None = None
_log_fp = None


def _default_keylogger_path() -> str:
    """Returns the expected path of keylogging.py in the same directory."""
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(here, "keylogging.py")


def _default_python_exe() -> str:
    """Returns 'python' for Windows and 'python3' for others by default."""
    return "python" if os.name == "nt" else "python3"


def _obs_format_to_strftime(fmt: str) -> str:
    """Convert common OBS filename tokens to strftime equivalents."""
    replacements = {
        "%CCYY": "%Y",
        "%YY": "%y",
        "%MM": "%m",
        "%DD": "%d",
        "%hh": "%H",
        "%mm": "%M",
        "%ss": "%S",
    }
    out = fmt
    for k, v in replacements.items():
        out = out.replace(k, v)
    return out


def _get_obs_canvas_resolution() -> tuple[int, int] | None:
    """
    Read the OBS Base (Canvas) Resolution from the current video settings.
    This is the coordinate space that the recorded video uses.
    
    Returns (width, height) or None if detection fails.
    """
    # Primary: OBS API
    try:
        video_info = obs.obs_video_info()
        if obs.obs_get_video_info(video_info):
            w = video_info.base_width
            h = video_info.base_height
            if w > 0 and h > 0:
                return (w, h)
    except Exception:
        pass

    # Fallback: read from profile config
    try:
        profile_name = obs.obs_frontend_get_current_profile()
        home = os.path.expanduser("~")
        if os.name == "nt":
            base = os.path.join(os.environ.get("APPDATA", home),
                                "obs-studio", "basic", "profiles")
        elif sys.platform == "darwin":
            base = os.path.join(home, "Library", "Application Support",
                                "obs-studio", "basic", "profiles")
        else:
            base = os.path.join(home, ".config", "obs-studio",
                                "basic", "profiles")

        ini_path = os.path.join(base, profile_name or "", "basic.ini")
        if os.path.isfile(ini_path):
            cfg = configparser.ConfigParser(interpolation=None)
            with open(ini_path, "r", encoding="utf-8-sig") as f:
                cfg.read_file(f)
            cx = cfg.get("Video", "BaseCX", fallback="")
            cy = cfg.get("Video", "BaseCY", fallback="")
            if cx and cy:
                return (int(cx), int(cy))
    except Exception:
        pass

    return None


def _recording_base_path() -> str | None:
    """
    Determines the recording path.
    Updated to prioritize a 'Videos' folder fallback on Windows.
    """
    # 1. Try official OBS API
    if hasattr(obs, "obs_frontend_get_recording_output_path"):
        try:
            path = obs.obs_frontend_get_recording_output_path()
            if path:
                base, _ext = os.path.splitext(path)
                return base
        except Exception:
            pass

    # 2. Try reading from OBS config files (basic.ini)
    profile_name = obs.obs_frontend_get_current_profile()
    profiles_path = None
    if hasattr(obs, "obs_frontend_get_profiles_path"):
        try:
            profiles_path = obs.obs_frontend_get_profiles_path()
        except Exception:
            profiles_path = None

    if profiles_path and profile_name:
        ini_path = os.path.join(profiles_path, profile_name, "basic.ini")
    else:
        home = os.path.expanduser("~")
        if os.name == "nt":
            base = os.path.join(os.environ.get("APPDATA", home), "obs-studio", "basic", "profiles")
        elif sys.platform == "darwin":
            base = os.path.join(home, "Library", "Application Support", "obs-studio", "basic", "profiles")
        else:
            base = os.path.join(home, ".config", "obs-studio", "basic", "profiles")
        ini_path = os.path.join(base, profile_name or "", "basic.ini")

    if os.path.isfile(ini_path):
        try:
            cfg = configparser.ConfigParser(interpolation=None)
            with open(ini_path, "r", encoding="utf-8-sig") as f:
                cfg.read_file(f)

            fmt = cfg.get("Output", "FilenameFormatting", fallback="%CCYY-%MM-%DD %hh-%mm-%ss")
            fmt = _obs_format_to_strftime(fmt)
            mode = cfg.get("Output", "Mode", fallback="Simple").lower()

            directory = ""
            if mode == "simple":
                directory = cfg.get("SimpleOutput", "FilePath", fallback="")
            else:
                directory = cfg.get("AdvOut", "RecFilePath", fallback="")
                if not directory:
                    directory = cfg.get("AdvOut", "FFFilePath", fallback="")

            if directory:
                name = time.strftime(fmt, time.localtime()).replace(" ", "_")
                return os.path.join(directory, name)
        except Exception:
            pass

    # 3. Windows Fallback: Force "Videos" directory if everything else fails
    if os.name == "nt":
        video_dir = os.path.join(os.environ.get("USERPROFILE", os.path.expanduser("~")), "Videos")
        timestamp = time.strftime("%Y-%m-%d_%H-%M-%S", time.localtime())
        return os.path.join(video_dir, timestamp)

    return None


def _log(level, msg: str) -> None:
    try:
        obs.script_log(level, msg)
    except Exception:
        pass


def _jsonl_system_event(action: str, ts_wall: float, ts_mono: float, meta: dict | None = None) -> str:
    payload = {
        "device": "system",
        "action": action,
        "ts_wall": ts_wall,
        "ts_wall_ms": f"{ts_wall:.3f}",
        "ts_mono": ts_mono,
    }
    if meta:
        payload["meta"] = meta
    return json.dumps(payload, separators=(",", ":"), ensure_ascii=False)


def _append_jsonl_line(line: str) -> None:
    global _current_jsonl_path
    if not _current_jsonl_path:
        return
    try:
        with open(_current_jsonl_path, "a", encoding="utf-8") as fp:
            fp.write(line + "\n")
    except Exception as exc:
        _log(obs.LOG_WARNING, f"Could not append event to JSONL: {exc}")


def _set_scene_item_visible(source_name: str, visible: bool) -> bool:
    scene_src = obs.obs_frontend_get_current_scene()
    if scene_src is None:
        return False
    try:
        scene = obs.obs_scene_from_source(scene_src)
        if scene is None:
            return False
        item = obs.obs_scene_find_source(scene, source_name)
        if item is None:
            return False
        obs.obs_sceneitem_set_visible(item, visible)
        return True
    finally:
        obs.obs_source_release(scene_src)


def _ensure_flash_hidden() -> None:
    global _flash_active
    if flash_source_name.strip():
        _set_scene_item_visible(flash_source_name, False)
    _flash_active = False


def _flash_off() -> None:
    global _flash_active
    obs.timer_remove(_flash_off)
    if not _flash_active:
        return

    ts_wall = time.time()
    ts_mono = time.monotonic()
    if _set_scene_item_visible(flash_source_name, False):
        _append_jsonl_line(
            _jsonl_system_event(
                "sync_flash_off",
                ts_wall,
                ts_mono,
                {"source": flash_source_name, "duration_ms": int(flash_duration_ms)},
            )
        )
    _flash_active = False


def _flash_on() -> None:
    global _flash_active
    if not flash_source_name.strip():
        return

    obs.timer_remove(_flash_off)
    ts_wall = time.time()
    ts_mono = time.monotonic()
    if _set_scene_item_visible(flash_source_name, True):
        _flash_active = True
        _append_jsonl_line(
            _jsonl_system_event(
                "sync_flash_on",
                ts_wall,
                ts_mono,
                {"source": flash_source_name, "duration_ms": int(flash_duration_ms)},
            )
        )
        obs.timer_add(_flash_off, int(flash_duration_ms))


def _stop_keylogger() -> None:
    global _proc, _log_fp
    if _proc is None:
        return

    # Log who is calling _stop_keylogger for debugging
    caller_stack = ''.join(traceback.format_stack(limit=4))
    _log(obs.LOG_WARNING, f"_stop_keylogger called! Caller stack:\n{caller_stack}")

    # Write recording_stop anchor event before terminating
    ts_wall = time.time()
    ts_mono = time.monotonic()
    _append_jsonl_line(
        _jsonl_system_event("recording_stop", ts_wall, ts_mono)
    )

    try:
        # Send SIGTERM to the keylogger's own process group
        # (it runs in start_new_session=True so it has its own pgid)
        if os.name != "nt":
            try:
                os.killpg(os.getpgid(_proc.pid), 15)  # SIGTERM
            except (ProcessLookupError, PermissionError):
                _proc.terminate()
        else:
            _proc.terminate()
        _proc.wait(timeout=3)
    except Exception:
        try:
            _proc.kill()
        except Exception:
            pass
    _log(obs.LOG_INFO, "Stopped keylogging process.")
    _proc = None

    if _log_fp is not None:
        try:
            _log_fp.close()
        except Exception:
            pass
    _log_fp = None


def _start_keylogger() -> None:
    global _proc, _log_fp, _current_jsonl_path

    # Guard: if process is already alive, skip
    if _proc is not None:
        if _proc.poll() is None:
            _log(obs.LOG_INFO, "Keylogger already running (pid={}).".format(_proc.pid))
            return
        else:
            # Previous process ended unexpectedly; clean up
            _log(obs.LOG_WARNING, "Previous keylogger process exited (rc={}). Restarting.".format(_proc.returncode))
            _proc = None

    base = _recording_base_path()
    if not base:
        _log(obs.LOG_ERROR, "Path detection failed. Cannot start keylogger.")
        return

    out_path = os.path.abspath(f"{base}.jsonl")
    log_path = os.path.abspath(f"{base}.keylog.log")
    _current_jsonl_path = out_path

    os.makedirs(os.path.dirname(out_path), exist_ok=True)

    script_path = keylogger_script or _default_keylogger_path()
    if not os.path.isfile(script_path):
        _log(obs.LOG_ERROR, f"keylogging.py not found at {script_path}")
        return

    cmd = [python_exe, script_path, "--out", out_path]

    # Auto-detect OBS canvas resolution and pass to keylogger
    canvas = _get_obs_canvas_resolution()
    if canvas:
        cmd.extend(["--obs-canvas", f"{canvas[0]}x{canvas[1]}"])
        _log(obs.LOG_INFO, f"OBS canvas resolution: {canvas[0]}x{canvas[1]}")
    else:
        _log(obs.LOG_WARNING,
             "Could not detect OBS canvas resolution. "
             "Keylogger will use raw coordinates (scale=1.0).")

    if extra_args.strip():
        cmd.extend(shlex.split(extra_args))

    try:
        _log_fp = open(log_path, "a", encoding="utf-8")
        _log(obs.LOG_INFO, f"Starting keylogger: {' '.join(shlex.quote(c) for c in cmd)}")

        # start_new_session=True puts the keylogger in its own process group
        # so OBS's internal signal handling won't accidentally SIGTERM it
        popen_kwargs = dict(stdout=_log_fp, stderr=subprocess.STDOUT)
        if os.name != "nt":
            popen_kwargs["start_new_session"] = True

        _proc = subprocess.Popen(cmd, **popen_kwargs)
        _log(obs.LOG_INFO, f"Keylogger started (pid={_proc.pid}, new_session=True)")
    except Exception as exc:
        _log(obs.LOG_ERROR, f"Failed to start keylogging: {exc}")
        _proc = None
        return

    # Write recording_start anchor AFTER subprocess is launched
    ts_wall = time.time()
    ts_mono = time.monotonic()
    _append_jsonl_line(
        _jsonl_system_event(
            "recording_start",
            ts_wall,
            ts_mono,
            {"obs_canvas": f"{canvas[0]}x{canvas[1]}" if canvas else "unknown"},
        )
    )
    _log(obs.LOG_INFO, f"recording_start anchor at ts_wall={ts_wall:.3f}")


def _on_event(event) -> None:
    _log(obs.LOG_INFO, f"_on_event received: {event}")
    if event == obs.OBS_FRONTEND_EVENT_RECORDING_STARTED:
        _log(obs.LOG_INFO, "Event: RECORDING_STARTED")
        _start_keylogger()
        _flash_on()
    elif event == obs.OBS_FRONTEND_EVENT_RECORDING_STOPPING:
        _log(obs.LOG_INFO, "Event: RECORDING_STOPPING")
        _flash_off()
        _stop_keylogger()
    elif event == obs.OBS_FRONTEND_EVENT_RECORDING_STOPPED:
        _log(obs.LOG_INFO, "Event: RECORDING_STOPPED")
        _stop_keylogger()


def script_description():
    return (
        "Automatically triggers keylogging.py when OBS recording starts/stops.\n"
        "Auto-detects canvas resolution for coordinate scaling."
    )


def script_properties():
    props = obs.obs_properties_create()
    obs.obs_properties_add_text(props, "python_exe", "Python Path", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_text(props, "keylogger_script", "keylogging.py Path", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_text(props, "extra_args", "Extra Arguments", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_text(props, "flash_source_name", "Sync Flash Source", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_int(props, "flash_duration_ms", "Flash Duration (ms)", 1, 5000, 1)
    return props


def script_defaults(settings):
    obs.obs_data_set_default_string(settings, "python_exe", _default_python_exe())
    obs.obs_data_set_default_string(settings, "keylogger_script", _default_keylogger_path())
    obs.obs_data_set_default_string(settings, "flash_source_name", "SYNC_FLASH")
    obs.obs_data_set_default_int(settings, "flash_duration_ms", 150)


def script_update(settings):
    global python_exe, keylogger_script, extra_args, flash_source_name, flash_duration_ms
    python_exe = obs.obs_data_get_string(settings, "python_exe")
    keylogger_script = obs.obs_data_get_string(settings, "keylogger_script")
    extra_args = obs.obs_data_get_string(settings, "extra_args")
    flash_source_name = obs.obs_data_get_string(settings, "flash_source_name")
    flash_duration_ms = obs.obs_data_get_int(settings, "flash_duration_ms")
    _ensure_flash_hidden()


def script_load(settings):
    _log(obs.LOG_INFO, ">>> script_load() called — registering event callback")
    obs.obs_frontend_add_event_callback(_on_event)
    _ensure_flash_hidden()


def script_unload():
    _log(obs.LOG_WARNING, ">>> script_unload() called — will stop keylogger if running")
    obs.timer_remove(_flash_off)
    _ensure_flash_hidden()
    _stop_keylogger()