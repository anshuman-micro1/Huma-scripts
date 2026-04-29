# OBS + Python 3.10 Setup — README (macOS)

## Overview

`setup_obs_mac.sh` is an automated setup script for macOS that installs and configures OBS Studio with a Python-based keylogging script. The keylogger records keypresses in sync with OBS screen recordings, useful for session auditing, tutorial creation, and QA workflows.

---

## What the Script Does

1. Installs **Python 3.10** (if not already installed)
2. Installs **OBS Studio 30.2.2** (if not already installed)
3. Downloads the Python scripts (`keylogging_trigger.py` and `keylogging.py`) from GitHub
4. Configures OBS to use the correct Python framework path
5. Deploys a pre-configured OBS **profile** (`basic.ini`)
6. Deploys a pre-configured OBS **scene collection** (`Untitled.json`) with:
   - macOS Screen Capture source
   - macOS Audio Capture source
   - SYNC_FLASH colour source (white, hidden by default — used for sync marking)
7. Registers `keylogging_trigger.py` into OBS Scripts so it loads automatically

---

## Requirements

- macOS 11 (Big Sur) or later
- Apple Silicon or Intel Mac
- Internet connection (for downloading installers and scripts)
- Administrator privileges (the script will prompt for your password via `sudo`)

---

## How to Run

1. Download `setup_obs_mac.sh`
2. Open **Terminal** (Applications → Utilities → Terminal)
3. Make the script executable and run it:
   ```zsh
   chmod +x ~/Documents/setup_obs_mac.sh
   ~/Documents/setup_obs_mac.sh
   ```
   Or run it directly without changing permissions:
   ```zsh
   zsh ~/Documents/setup_obs_mac.sh
   ```
4. Enter your macOS password when prompted — this is required to install Python and OBS

### Optional: Override Download URLs

You can override any of the default download URLs via command-line flags:

```zsh
zsh setup_obs_mac.sh \
  --python-url <URL> \
  --obs-url <URL> \
  --script-url <URL> \
  --keylogging-url <URL>
```

---

## After the Script Completes

1. Open **OBS Studio** from the Applications folder
2. Verify the profile loaded:
   - Click the **Profile** menu in the top menu bar
   - `Untitled` should be the active profile
   - If not, select it manually
3. Verify the scene collection loaded:
   - Click the **Scene Collection** menu in the top menu bar
   - `Untitled` should be active
   - If not, select it manually
4. Verify the script is registered:
   - Go to **Tools → Scripts → Scripts tab**
   - `keylogging_trigger.py` should appear in the Loaded Scripts list
   - If not, click `+` and navigate to `~/Documents/OBS_Scripts/keylogging_trigger.py`
5. Verify the Python path:
   - Go to **Tools → Scripts → Python Settings tab**
   - The path should be set to: `/Library/Frameworks/Python.framework/Versions/3.10`
   - If not, paste it in and click OK
6. Restart OBS if the script or scene collection does not appear

---

## File Locations After Setup

| Item | Location |
|---|---|
| Python | `/Library/Frameworks/Python.framework/Versions/3.10` |
| Python Executable | `/Library/Frameworks/Python.framework/Versions/3.10/bin/python3.10` |
| OBS Studio | `/Applications/OBS.app` |
| keylogging_trigger.py | `~/Documents/OBS_Scripts/keylogging_trigger.py` |
| keylogging.py | `~/Documents/OBS_Scripts/keylogging.py` |
| OBS Profile | `~/Library/Application Support/obs-studio/basic/profiles/Untitled/basic.ini` |
| Scene Collection | `~/Library/Application Support/obs-studio/basic/scenes/Untitled.json` |
| OBS Global Config | `~/Library/Application Support/obs-studio/global.ini` |

---

## Recording Settings (Pre-configured)

| Setting | Value |
|---|---|
| Resolution | 2880×1800 (native Retina) |
| Frame Rate | 30 FPS |
| Format | MP4 |
| Video Bitrate | 6000 Kbps |
| Audio Bitrate | 160 Kbps |
| Video Encoder | Apple H.264 (`apple_h264`) |
| Audio Encoder | CoreAudio AAC |
| Save Location | `~/Movies` |

---

## Troubleshooting

**"Permission denied" when running the script**
- Make sure you've made the script executable: `chmod +x setup_obs_mac.sh`
- Or run it directly with `zsh setup_obs_mac.sh`

**Script fails asking for sudo password**
- The script requires administrator privileges to install Python and copy OBS to `/Applications`
- Enter your macOS login password when prompted — it will not be echoed to the screen

**OBS installation failed**
- Install OBS manually from https://obsproject.com/download
- Select the Apple Silicon or Intel build as appropriate for your Mac
- Drag OBS to `/Applications` (the default location)
- Then re-run the script — it will skip the OBS install and continue with the rest

**Script not appearing in OBS**
- Make sure OBS was **closed** before running the script
- OBS can overwrite `scripts.json` on exit, undoing the registration
- Manually add the script via **Tools → Scripts → `+`**

**Python path not set in OBS**
- Go to **Tools → Scripts → Python Settings**
- Paste in: `/Library/Frameworks/Python.framework/Versions/3.10`

**Conflict with other Python versions**
- If you have other Python versions installed (e.g. via Homebrew or pyenv), OBS may default to a different one
- If the script fails to load in OBS, verify the Python Settings path is set to exactly: `/Library/Frameworks/Python.framework/Versions/3.10`
- As a last resort, temporarily remove or deactivate other Python installations

**"Failed to detect mounted volume" during OBS install**
- A previous DMG mount may have been left behind
- Run the following to clean up stale mounts, then re-run the script:
  ```bash
  hdiutil detach /Volumes/OBS* -force
  ```

**To do a clean reinstall**

Follow these steps in order:

1. **Uninstall OBS Studio**
   - Open **Finder → Applications**
   - Drag **OBS** to the Trash
   - Empty the Trash

2. **Uninstall Python 3.10**
   - Run the following in Terminal:
     ```bash
     sudo rm -rf /Library/Frameworks/Python.framework/Versions/3.10
     sudo rm -f /usr/local/bin/python3.10
     ```

3. **Remove leftover files** by running the following in Terminal:
   ```bash
   rm -rf "$HOME/Library/Application Support/obs-studio"
   rm -rf "$HOME/Documents/OBS_Scripts"
   ```

4. Re-run `setup_obs_mac.sh`

---

## Notes

- `keylogging.py` must remain in the same folder as `keylogging_trigger.py`
- Only `keylogging_trigger.py` is loaded into OBS directly — it calls `keylogging.py` internally
- Make sure OBS is **closed** before running the script to prevent OBS from overwriting the configuration on exit
- On Apple Silicon Macs, OBS runs natively — the script downloads the Apple Silicon DMG by default
