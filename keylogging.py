#!/usr/bin/env python3
"""
Cross-platform keyboard + mouse recorder (macOS / Linux / Windows) using pynput.

Writes newline-delimited JSON (JSONL) with both wall-clock and monotonic timestamps
so you can sync with screen recordings.

Features:
- Records keyboard press/release, mouse move/click/scroll
- Timestamp fields: ts_wall (time.time), ts_wall_ms (string, wall seconds with 3 decimals), ts_mono (time.monotonic)
- Non-blocking callbacks: event queue + dedicated writer thread
- Optional mouse-move rate limiting
- Flush on every line, optional fsync interval
- Signal-safe shutdown (SIGINT/SIGTERM)
- Watchdog restarts listeners if they stop unexpectedly

Usage:
If on macOS, you may need to grant accessibility permissions to the terminal or Python interpreter.
pip install pynput
python3 record_inputs.py --out /path/to/events.jsonl --move-interval 0.05
"""

from __future__ import annotations

import argparse
import ctypes
import json
import os
import platform
import queue
import signal
import sys
import threading
import time
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from pynput import keyboard, mouse  # type: ignore
from pynput.keyboard import Key, KeyCode  # type: ignore
from pynput.mouse import Button  # type: ignore


def minimize_console() -> None:
    if platform.system() == "Windows":
        hwnd = ctypes.windll.kernel32.GetConsoleWindow()
        if hwnd:
            SW_MINIMIZE = 6
            ctypes.windll.user32.ShowWindow(hwnd, SW_MINIMIZE)
    return None


minimize_console()


# ----------------------------
# Scale factor helpers
# ----------------------------


def _get_logical_screen_width() -> float:
    """Return the OS logical coordinate space width that pynput reports in."""
    if platform.system() == "Darwin":
        try:
            cg = ctypes.cdll.LoadLibrary(
                "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics"
            )
            cg.CGMainDisplayID.restype = ctypes.c_uint32

            class CGRect(ctypes.Structure):
                _fields_ = [
                    ("x", ctypes.c_double), ("y", ctypes.c_double),
                    ("width", ctypes.c_double), ("height", ctypes.c_double),
                ]

            cg.CGDisplayBounds.argtypes = [ctypes.c_uint32]
            cg.CGDisplayBounds.restype = CGRect
            bounds = cg.CGDisplayBounds(cg.CGMainDisplayID())
            if bounds.width > 0:
                return float(bounds.width)
        except Exception:
            pass
    elif platform.system() == "Windows":
        try:
            return float(ctypes.windll.user32.GetSystemMetrics(0))
        except Exception:
            pass
    return 0.0


def _compute_scale_factor(obs_canvas_w: int | None) -> float:
    """
    factor = obs_canvas_width / pynput_logical_width.
    If no --obs-canvas provided, returns 1.0 (raw coordinates, no corruption).
    """
    if obs_canvas_w is None or obs_canvas_w <= 0:
        return 1.0
    logical_w = _get_logical_screen_width()
    if logical_w <= 0:
        return 1.0
    return obs_canvas_w / logical_w


# ----------------------------
# Formatting helpers
# ----------------------------


def _format_key(key: Key | KeyCode | Any) -> dict[str, Any]:
    """
    Return a structured key representation.
    """
    if isinstance(key, KeyCode):
        return {
            "kind": "keycode",
            "char": key.char,
            "vk": getattr(key, "vk", None),
        }
    if isinstance(key, Key):
        return {
            "kind": "key",
            "name": key.name or str(key),
        }
    return {"kind": "unknown", "repr": str(key)}


def _format_button(button: Button | Any) -> str:
    if isinstance(button, Button):
        return button.name
    return str(button)


def _ensure_parent_dir(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def _default_out_path() -> Path:
    # Timestamped default file name in current directory.
    ts = time.strftime("%Y%m%d_%H%M%S", time.localtime())
    return Path.cwd() / f"input_events_{ts}.jsonl"


# ----------------------------
# Writer thread
# ----------------------------


@dataclass
class WriterConfig:
    flush_every_event: bool = True
    fsync_interval_s: float = 0.0  # 0 disables fsync


class EventWriter(threading.Thread):
    def __init__(
        self,
        out_path: Path,
        q: "queue.Queue[dict[str, Any]]",
        stop_event: threading.Event,
        cfg: WriterConfig,
    ) -> None:
        super().__init__(name="event-writer", daemon=True)
        self._out_path = out_path
        self._q = q
        self._stop_event = stop_event
        self._cfg = cfg
        self._fp = None
        self._last_fsync = 0.0

    def _open(self) -> None:
        _ensure_parent_dir(self._out_path)
        # line-buffered text file
        self._fp = self._out_path.open("a", encoding="utf-8", buffering=1)

    def _write_line(self, payload: dict[str, Any]) -> None:
        assert self._fp is not None
        line = json.dumps(payload, separators=(",", ":"), ensure_ascii=False)
        self._fp.write(line + "\n")
        if self._cfg.flush_every_event:
            self._fp.flush()

        if self._cfg.fsync_interval_s > 0:
            now = time.monotonic()
            if now - self._last_fsync >= self._cfg.fsync_interval_s:
                self._last_fsync = now
                try:
                    os.fsync(self._fp.fileno())
                except Exception:
                    # fsync can fail on some filesystems; keep going
                    pass

    def run(self) -> None:
        try:
            self._open()
        except Exception as exc:
            # fallback to stdout if file cannot be opened
            sys.stderr.write(f"[input-recorder] failed to open log file {self._out_path}: {exc}\n")
            sys.stderr.write("[input-recorder] falling back to stdout\n")
            sys.stderr.flush()
            self._fp = sys.stdout

        # Drain queue until stop_event and queue empty
        while True:
            if self._stop_event.is_set():
                # drain remaining items quickly
                try:
                    payload = self._q.get_nowait()
                except queue.Empty:
                    break
            else:
                try:
                    payload = self._q.get(timeout=0.25)
                except queue.Empty:
                    continue

            try:
                self._write_line(payload)
            except Exception as exc:
                # If writing fails, emit to stderr and continue
                sys.stderr.write(f"[input-recorder] write error: {exc}\n")
                sys.stderr.flush()

        # Close file if it's a real file
        try:
            if self._fp not in (None, sys.stdout):
                self._fp.flush()
                self._fp.close()
        except Exception:
            pass


# ----------------------------
# Recorder
# ----------------------------


@dataclass
class RecorderConfig:
    out_path: Path
    move_interval_s: float
    queue_max: int
    restart_backoff_s: float
    include_modifiers: bool
    obs_canvas_w: int | None = None


class InputRecorder:
    def __init__(self, cfg: RecorderConfig, writer_cfg: WriterConfig) -> None:
        self.cfg = cfg
        self.stop_event = threading.Event()

        self.session_id = str(uuid.uuid4())
        self.pid = os.getpid()

        self.q: "queue.Queue[dict[str, Any]]" = queue.Queue(maxsize=cfg.queue_max)
        self.writer = EventWriter(cfg.out_path, self.q, self.stop_event, writer_cfg)

        self._keyboard_listener: keyboard.Listener | None = None
        self._mouse_listener: mouse.Listener | None = None

        self._pressed_keys_lock = threading.Lock()
        self._pressed_keys: set[str] = set()

        self._last_move_ts = 0.0  # monotonic time

        self._scale = _compute_scale_factor(cfg.obs_canvas_w)

    def _now_payload_base(self) -> dict[str, Any]:
        ts_wall = time.time()
        return {
            "session_id": self.session_id,
            "pid": self.pid,
            "ts_wall": ts_wall,
            "ts_wall_ms": f"{ts_wall:.3f}",
            "ts_mono": time.monotonic(),
        }

    def _enqueue(self, payload: dict[str, Any]) -> None:
        # Never block callback threads; drop if queue is full.
        try:
            self.q.put_nowait(payload)
        except queue.Full:
            # As a compromise: drop move events more readily, keep clicks/keys.
            # If queue is full, we try one best-effort get to make room.
            try:
                _ = self.q.get_nowait()
                self.q.put_nowait(payload)
            except Exception:
                pass

    def _modifiers_snapshot(self) -> list[str]:
        with self._pressed_keys_lock:
            # Only expose common modifier-like keys; you can expand this list.
            mods = []
            for m in (
                "shift",
                "shift_l",
                "shift_r",
                "ctrl",
                "ctrl_l",
                "ctrl_r",
                "alt",
                "alt_l",
                "alt_r",
                "cmd",
                "cmd_l",
                "cmd_r",
            ):
                if m in self._pressed_keys:
                    mods.append(m)
            return mods

    def _key_name_for_set(self, key: Key | KeyCode | Any) -> str:
        if isinstance(key, Key):
            return key.name or str(key)
        if isinstance(key, KeyCode):
            if key.char:
                return key.char
            return f"vk_{getattr(key, 'vk', None)}"
        return str(key)

    # ---- keyboard callbacks ----
    def on_press(self, key: Key | KeyCode) -> None:
        try:
            if self.cfg.include_modifiers:
                with self._pressed_keys_lock:
                    self._pressed_keys.add(self._key_name_for_set(key))

            payload = {
                **self._now_payload_base(),
                "device": "keyboard",
                "action": "press",
                "key": _format_key(key),
            }
            if self.cfg.include_modifiers:
                payload["modifiers"] = self._modifiers_snapshot()

            self._enqueue(payload)
        except Exception as exc:
            sys.stderr.write(f"[input-recorder] keyboard on_press error: {exc}\n")
            sys.stderr.flush()

    def on_release(self, key: Key | KeyCode) -> None:
        try:
            if self.cfg.include_modifiers:
                with self._pressed_keys_lock:
                    self._pressed_keys.discard(self._key_name_for_set(key))

            payload = {
                **self._now_payload_base(),
                "device": "keyboard",
                "action": "release",
                "key": _format_key(key),
            }
            if self.cfg.include_modifiers:
                payload["modifiers"] = self._modifiers_snapshot()

            self._enqueue(payload)
        except Exception as exc:
            sys.stderr.write(f"[input-recorder] keyboard on_release error: {exc}\n")
            sys.stderr.flush()

    # ---- mouse callbacks ----
    def on_move(self, x: int, y: int) -> None:
        try:
            now = time.monotonic()
            if (
                self.cfg.move_interval_s > 0
                and (now - self._last_move_ts) < self.cfg.move_interval_s
            ):
                return
            self._last_move_ts = now
            self._enqueue(
                {
                    **self._now_payload_base(),
                    "device": "mouse",
                    "action": "move",
                    "position": {"x": int(x * self._scale), "y": int(y * self._scale)},
                }
            )
        except Exception as exc:
            sys.stderr.write(f"[input-recorder] mouse on_move error: {exc}\n")
            sys.stderr.flush()

    def on_click(self, x: int, y: int, button: Button, pressed: bool) -> None:
        try:
            self._enqueue(
                {
                    **self._now_payload_base(),
                    "device": "mouse",
                    "action": "press" if pressed else "release",
                    "button": _format_button(button),
                    "position": {"x": int(x * self._scale), "y": int(y * self._scale)},
                }
            )
        except Exception as exc:
            sys.stderr.write(f"[input-recorder] mouse on_click error: {exc}\n")
            sys.stderr.flush()

    def on_scroll(self, x: int, y: int, dx: int, dy: int) -> None:
        try:
            self._enqueue(
                {
                    **self._now_payload_base(),
                    "device": "mouse",
                    "action": "scroll",
                    "delta": {"dx": dx, "dy": dy},
                    "position": {"x": int(x * self._scale), "y": int(y * self._scale)},
                }
            )
        except Exception as exc:
            sys.stderr.write(f"[input-recorder] mouse on_scroll error: {exc}\n")
            sys.stderr.flush()

    # ---- lifecycle ----
    def start(self) -> None:
        self.writer.start()
        self._start_listeners()

    def _start_listeners(self) -> None:
        self._keyboard_listener = keyboard.Listener(
            on_press=self.on_press,
            on_release=self.on_release,
        )
        self._mouse_listener = mouse.Listener(
            on_move=self.on_move,
            on_click=self.on_click,
            on_scroll=self.on_scroll,
        )
        self._keyboard_listener.start()
        self._mouse_listener.start()

    def _stop_listeners(self) -> None:
        for lst in (self._keyboard_listener, self._mouse_listener):
            if lst is None:
                continue
            try:
                lst.stop()
            except Exception:
                pass
        for lst in (self._keyboard_listener, self._mouse_listener):
            if lst is None:
                continue
            try:
                lst.join(timeout=2.0)
            except Exception:
                pass

    def stop(self, reason: str = "stop") -> None:
        if self.stop_event.is_set():
            return
        self.stop_event.set()
        self._stop_listeners()
        # Writer thread will drain remaining queue
        self.writer.join(timeout=5.0)

    def run_forever(self) -> int:
        backoff = self.cfg.restart_backoff_s

        try:
            while not self.stop_event.is_set():
                time.sleep(0.25)

                # Watchdog: restart listeners if they died
                kl = self._keyboard_listener
                ml = self._mouse_listener
                if kl is not None and not kl.is_alive() and not self.stop_event.is_set():
                    self._enqueue(
                        {
                            **self._now_payload_base(),
                            "device": "system",
                            "action": "warn",
                            "msg": "keyboard listener died; restarting",
                        }
                    )
                    self._stop_listeners()
                    time.sleep(backoff)
                    self._start_listeners()

                if ml is not None and not ml.is_alive() and not self.stop_event.is_set():
                    self._enqueue(
                        {
                            **self._now_payload_base(),
                            "device": "system",
                            "action": "warn",
                            "msg": "mouse listener died; restarting",
                        }
                    )
                    self._stop_listeners()
                    time.sleep(backoff)
                    self._start_listeners()

            return 0
        except KeyboardInterrupt:
            self.stop(reason="keyboardinterrupt")
            return 0
        except Exception as exc:
            sys.stderr.write(f"[input-recorder] fatal error: {exc}\n")
            sys.stderr.flush()
            self.stop(reason="fatal_error")
            return 2


# ----------------------------
# CLI
# ----------------------------


def _parse_args(argv: list[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Record global mouse+keyboard input to JSONL.")
    p.add_argument("--out", type=str, default=str(_default_out_path()), help="Output JSONL path.")
    p.add_argument(
        "--move-interval",
        type=float,
        default=0.05,
        help="Mouse move sampling interval (seconds). 0 = log all moves.",
    )
    p.add_argument(
        "--queue-max",
        type=int,
        default=10000,
        help="Max queued events (drops when full).",
    )
    p.add_argument(
        "--restart-backoff",
        type=float,
        default=0.5,
        help="Seconds to wait before restarting dead listeners.",
    )
    p.add_argument("--no-modifiers", action="store_true", help="Do not include modifier snapshot.")
    p.add_argument(
        "--fsync-interval",
        type=float,
        default=0.0,
        help="Call fsync every N seconds (0 disables).",
    )
    p.add_argument(
        "--obs-canvas",
        type=str,
        default=None,
        help="OBS canvas resolution as WxH (e.g. 1920x1080). Passed automatically by the OBS trigger.",
    )
    return p.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    ns = _parse_args(sys.argv[1:] if argv is None else argv)
    out_path = Path(ns.out).expanduser()

    obs_w: int | None = None
    if ns.obs_canvas:
        try:
            parts = ns.obs_canvas.lower().split("x")
            obs_w = int(parts[0])
        except (ValueError, IndexError):
            sys.stderr.write(f"[input-recorder] bad --obs-canvas '{ns.obs_canvas}', ignoring\n")

    recorder_cfg = RecorderConfig(
        out_path=out_path,
        move_interval_s=max(0.0, float(ns.move_interval)),
        queue_max=max(1000, int(ns.queue_max)),
        restart_backoff_s=max(0.1, float(ns.restart_backoff)),
        include_modifiers=not bool(ns.no_modifiers),
        obs_canvas_w=obs_w,
    )
    writer_cfg = WriterConfig(
        flush_every_event=True,
        fsync_interval_s=max(0.0, float(ns.fsync_interval)),
    )

    recorder = InputRecorder(recorder_cfg, writer_cfg)

    def _handle_signal(signum: int, _frame: Any) -> None:
        sys.stderr.write(f"[input-recorder] received signal {signum}, stopping\n")
        sys.stderr.flush()
        recorder.stop(reason=f"signal_{signum}")

    # SIGTERM/SIGINT are the common ones; Windows supports SIGINT; SIGTERM may be limited.
    for sig in (getattr(signal, "SIGTERM", None), getattr(signal, "SIGINT", None)):
        if sig is not None:
            try:
                signal.signal(sig, _handle_signal)
            except Exception:
                pass

    recorder.start()
    sys.stderr.write(f"[input-recorder] recording to {out_path}\n")
    sys.stderr.flush()
    return recorder.run_forever()


if __name__ == "__main__":
    raise SystemExit(main())