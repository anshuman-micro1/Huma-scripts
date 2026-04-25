#!/usr/bin/env python3
"""
Run this once to fix "Path detection failed. Cannot start keylogger."

Usage:
  /Library/Frameworks/Python.framework/Versions/3.10/bin/python3.10 ~/Downloads/patch_trigger.py
"""
import re, sys, os

SCRIPTS_DIR = os.path.expanduser("~/Downloads/OBS_Scripts")
TRIGGER     = os.path.join(SCRIPTS_DIR, "keylogging_trigger.py")
KEYLOGGER   = os.path.join(SCRIPTS_DIR, "keylogging.py")
PYTHON_EXE  = "/Library/Frameworks/Python.framework/Versions/3.10/bin/python3.10"
MOVIES      = os.path.expanduser("~/Movies")

if not os.path.isfile(TRIGGER):
    print(f"ERROR: {TRIGGER} not found.")
    sys.exit(1)

with open(TRIGGER, "r", encoding="utf-8") as f:
    src = f.read()

changes = []

# Patch A: hardcode module-level keylogger_script (currently calls _default_keylogger_path())
OLD_A = "keylogger_script = _default_keylogger_path()"
NEW_A = f'keylogger_script = "{KEYLOGGER}"  # HUMA_PATH_PATCH'
if OLD_A in src:
    src = src.replace(OLD_A, NEW_A, 1)
    changes.append(f"A: module-level keylogger_script -> {KEYLOGGER}")

# Patch B: hardcode python_exe in script_update() — OBS default is "python3", wrong interpreter
OLD_B = 'python_exe = obs.obs_data_get_string(settings, "python_exe")'
NEW_B = f'python_exe = "{PYTHON_EXE}"  # HUMA_PATH_PATCH'
if OLD_B in src:
    src = src.replace(OLD_B, NEW_B, 1)
    changes.append(f"B: python_exe -> {PYTHON_EXE}")

# Patch C: hardcode keylogger_script in script_update() — OBS settings override our module-level fix
OLD_C = 'keylogger_script = obs.obs_data_get_string(settings, "keylogger_script")'
NEW_C = f'keylogger_script = "{KEYLOGGER}"  # HUMA_PATH_PATCH'
if OLD_C in src:
    src = src.replace(OLD_C, NEW_C, 1)
    changes.append("C: script_update keylogger_script hardcoded")

# Patch D: add macOS fallback in _recording_base_path() so it never returns None.
# The function currently only has a Windows fallback; on macOS it returns None
# when the profile ini read fails, which triggers "Path detection failed."
FALLBACK = f"""
    # macOS guaranteed fallback - HUMA_PATH_PATCH
    if sys.platform == "darwin":
        import time as _t
        _ts = _t.strftime("%Y-%m-%d_%H-%M-%S", _t.localtime())
        return os.path.join("{MOVIES}", _ts)
"""
fn_body = src.split("def _recording_base_path")[1].split("\ndef ")[0]
if "HUMA_PATH_PATCH" not in fn_body:
    pattern = r"(def _recording_base_path\b.*?)\n    return None(\n\n)"
    def ins(m):
        return m.group(1) + FALLBACK + "\n    return None" + m.group(2)
    new_src, n = re.subn(pattern, ins, src, count=1, flags=re.DOTALL)
    if n:
        src = new_src
        changes.append(f"D: macOS path fallback added -> {MOVIES}/<timestamp>.jsonl")
    else:
        print("  WARNING: Could not find insertion point for Patch D")
else:
    print("  Patch D already present — skipping")

if not changes:
    print("No changes needed — script may already be fully patched.")
    sys.exit(0)

with open(TRIGGER, "w", encoding="utf-8") as f:
    f.write(src)

print("Patches applied successfully:")
for c in changes:
    print(f"  ✓ {c}")
print(f"\nNext steps:")
print("  1. Quit OBS completely")
print("  2. Reopen OBS")
print("  3. Start a recording — keylogging should begin without errors")
print(f"  4. Keystroke logs will appear in: {MOVIES}/")
