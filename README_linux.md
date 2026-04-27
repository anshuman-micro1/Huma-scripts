# OBS + Python Setup — README (Linux)

## Overview

`setup_obs_linux.sh` is an automated setup script for Linux (Debian/Ubuntu-based distributions) that installs and configures OBS Studio with a Python-based keylogging script. The keylogger records keypresses in sync with OBS screen recordings, useful for session auditing, tutorial creation, and QA workflows.

---

## What the Script Does

1. Installs **Python 3**, `pip`, and `x11-utils` via `apt-get` (if available).
2. Installs **OBS Studio** via PPA.
3. Downloads the Python scripts (`keylogging_trigger.py` and `keylogging.py`) from GitHub.
4. Installs the `pynput` Python library for keylogging.
5. Configures OBS to use the correct Python path (`/usr`).
6. Deploys a pre-configured OBS **profile** (`basic.ini`).
7. Deploys a pre-configured OBS **scene collection** (`HUMA.json`) with:
   - Linux Screen Capture (XSHM)
   - Linux Audio Capture (PulseAudio)
   - SYNC_FLASH colour source (white, hidden by default — used for sync marking)
8. Registers `keylogging_trigger.py` into OBS Scripts so it loads automatically.

---

## Requirements

- Debian/Ubuntu-based Linux Distribution (e.g., Ubuntu 20.04/22.04/24.04, Pop!_OS, Linux Mint)
- Internet connection (for downloading installers and scripts)
- Administrator/sudo privileges
- **Display Server**: X11 is highly recommended. Wayland has strict security models that often prevent global keystroke capturing by applications like `pynput`. If keylogging fails to start or record properly, log out and choose an "Ubuntu on Xorg" or "GNOME on Xorg" session from your display manager.

---

## How to Run

1. Download `setup_obs_linux.sh`
2. Open **Terminal**
3. Make the script executable and run it:
   ```bash
   chmod +x setup_obs_linux.sh
   ./setup_obs_linux.sh
   ```
4. Enter your sudo password when prompted.

---

## After the Script Completes

1. Open **OBS Studio** from your application launcher.
2. Verify the profile loaded:
   - Click the **Profile** menu in the top menu bar.
   - `HUMA` should be the active profile. If not, select it.
3. Verify the scene collection loaded:
   - Click the **Scene Collection** menu in the top menu bar.
   - `HUMA` should be active. If not, select it.
4. Verify the script is registered:
   - Go to **Tools → Scripts → Scripts tab**.
   - `keylogging_trigger.py` should appear in the Loaded Scripts list.
   - If not, click `+` and navigate to `~/Downloads/OBS_Scripts/keylogging_trigger.py`.
5. Restart OBS if the script or scene collection does not appear correctly.

---

## File Locations After Setup

| Item | Location |
|---|---|
| OBS Config Directory | `~/.config/obs-studio/` |
| Python Scripts | `~/Downloads/OBS_Scripts/` |
| OBS Profile | `~/.config/obs-studio/basic/profiles/HUMA/basic.ini` |
| Scene Collection | `~/.config/obs-studio/basic/scenes/HUMA.json` |

---

## Troubleshooting

**Wayland Compatibility**
If your system is using Wayland (default on newer versions of Ubuntu and Fedora), `pynput` may fail to hook into keyboard events. You will need to switch to an X11 session. On your login screen, click your username, click the gear icon in the bottom right corner, and select the "Xorg" session before typing your password.

**"No module named pynput" Error**
If the script fails to load in OBS due to a missing `pynput` library, install it manually using your package manager:
```bash
sudo apt-get install python3-pynput
```
Alternatively, use pip:
```bash
python3 -m pip install pynput --user --break-system-packages
```

**Script not appearing in OBS**
- Make sure OBS was **closed** before running the setup script.
- OBS overwrites its configuration files on exit, which can undo changes made by the setup script while OBS was running.
- Manually add the script via **Tools → Scripts → `+`**.

**Black Screen for Screen Capture**
If you are running Wayland, the `xshm_input` (X11 capture) might show a black screen. Switch your scene source to `PipeWire Screen Capture` manually in OBS, or switch your entire desktop session to X11.

---

## Notes
- Make sure OBS is **closed** before running the script to prevent OBS from overwriting the configuration on exit.
