# OBS + Python 3.10 Setup — README

## Overview

`setup_obs_windows.cmd` is an automated setup script for Windows that installs and configures OBS Studio with a Python-based keylogging script. The keylogger records keypresses in sync with OBS screen recordings, useful for session auditing, tutorial creation, and QA workflows.

---

## What the Script Does

1. Installs **Python 3.10** (if not already installed)
2. Installs **OBS Studio 30.2.2** (if not already installed)
3. Downloads the Python scripts (`keylogging_trigger.py` and `keylogging.py`) from GitHub
4. Configures OBS to use the correct Python path
5. Deploys a pre-configured OBS **profile** (`basic.ini`)
6. Deploys a pre-configured OBS **scene collection** (`Untitled.json`) with:
   - Windows Screen Capture source
   - Windows Audio Capture source
   - SYNC_FLASH colour source (white, hidden by default — used for sync marking)
7. Registers `keylogging_trigger.py` into OBS Scripts so it loads automatically

---

## Requirements

- Windows 10 or 11 (64-bit)
- Internet connection (for downloading installers and scripts)
- Administrator privileges

---

## How to Run

1. Download `setup_obs_windows.cmd`
2. Open **Command Prompt as Administrator**:
   - Press `Win + S`
   - Search for **cmd**
   - Right-click → **Run as administrator**
3. Run the script:
   ```
   cmd /k C:\Users\YourName\Downloads\setup_obs_windows.cmd
   ```
   Or simply right-click the file in File Explorer and select **Run as administrator**

---

## After the Script Completes

1. Open **OBS Studio** from the Start Menu
2. Verify the profile loaded:
   - Click the **Profile** menu in the top bar
   - `Untitled` should be the active profile
   - If not, select it manually
3. Verify the scene collection loaded:
   - Click the **Scene Collection** menu in the top bar
   - `Untitled` should be active
   - If not, select it manually
4. Verify the script is registered:
   - Go to **Tools → Scripts → Scripts tab**
   - `keylogging_trigger.py` should appear in the Loaded Scripts list
   - If not, click `+` and navigate to `%USERPROFILE%\Downloads\OBS_Scripts\keylogging_trigger.py`
5. Verify the Python path:
   - Go to **Tools → Scripts → Python Settings tab**
   - The path should be set to: `%LOCALAPPDATA%\Programs\Python\Python310`
   - If not, paste it in and click OK
6. Restart OBS if the script or scene collection does not appear

---

## File Locations After Setup

| Item | Location |
|---|---|
| Python | `%LOCALAPPDATA%\Programs\Python\Python310` |
| OBS Studio | `%ProgramFiles%\obs-studio` |
| keylogging_trigger.py | `%USERPROFILE%\Downloads\OBS_Scripts\keylogging_trigger.py` |
| keylogging.py | `%USERPROFILE%\Downloads\OBS_Scripts\keylogging.py` |
| OBS Profile | `%APPDATA%\obs-studio\basic\profiles\Untitled\basic.ini` |
| Scene Collection | `%APPDATA%\obs-studio\basic\scenes\Untitled.json` |
| OBS Global Config | `%APPDATA%\obs-studio\global.ini` |

---

## Recording Settings (Pre-configured)

| Setting | Value |
|---|---|
| Resolution | 1920×1080 |
| Frame Rate | 30 FPS |
| Format | MP4 |
| Video Bitrate | 6000 Kbps |
| Audio Bitrate | 160 Kbps |
| Encoder | x264 |
| Save Location | `%USERPROFILE%\Videos` |

---

## Troubleshooting

**Script says "not recognized as an internal or external command"**
- Make sure there are no spaces or parentheses in the filename
- Run from an admin command prompt using the full path

**OBS installation failed**
- Install OBS manually from https://obsproject.com/download
- Use the default install path: `C:\Program Files\obs-studio`
- Then re-run the script — it will skip the OBS install and continue with the rest

**Script not appearing in OBS**
- Make sure OBS was closed before running the script
- OBS can overwrite `scripts.json` on exit, undoing the registration
- Manually add the script via Tools → Scripts → `+`

**Python path not set in OBS**
- Go to Tools → Scripts → Python Settings
- Paste in: `%LOCALAPPDATA%\Programs\Python\Python310`

**To do a clean reinstall**

Follow these steps in order:

1. **Uninstall OBS Studio**
   - Press `Win + S` and search for **Add or remove programs**
   - Find **OBS Studio** in the list
   - Click it and select **Uninstall**
   - Follow the uninstall wizard to completion

2. **Uninstall Python 3.10**
   - In the same **Add or remove programs** list
   - Find **Python 3.10.11 (64-bit)**
   - Click it and select **Uninstall**
   - Follow the uninstall wizard to completion

3. **Remove leftover files** by running the following in an admin PowerShell:
   ```powershell
   Remove-Item -Recurse -Force "$env:ProgramFiles\obs-studio" -ErrorAction SilentlyContinue
   Remove-Item -Recurse -Force "$env:APPDATA\obs-studio" -ErrorAction SilentlyContinue
   Remove-Item -Recurse -Force "$env:USERPROFILE\Downloads\OBS_Scripts" -ErrorAction SilentlyContinue
   Remove-Item -Recurse -Force "$env:LOCALAPPDATA\Programs\Python\Python310" -ErrorAction SilentlyContinue
   ```

4. Re-run `setup_obs_windows.cmd`

---

## Notes

- `keylogging.py` must remain in the same folder as `keylogging_trigger.py`
- Only `keylogging_trigger.py` is loaded into OBS directly — it calls `keylogging.py` internally
- Make sure OBS is **closed** before running the script to prevent OBS from overwriting the configuration on exit
