@echo off
setlocal enabledelayedexpansion

title HUMA Setup
color 0B

powershell -NoProfile -Command "cls; $lines = @('  ##  ##  ##  ##  ## ##   ###  ','  ##  ##  ##  ##  #####  ## ## ','  ######  ##  ##  ## ##  ##### ','  ##  ##  ##  ##  ## ##  ## ## ','  ##  ##   ####   ## ##   ###  '); Write-Host ''; foreach ($l in $lines) { Write-Host $l -ForegroundColor Cyan }; Write-Host ''; Write-Host '             Welcome to HUMA!' -ForegroundColor White; Write-Host '     OBS Studio Automated Setup for Windows' -ForegroundColor Gray; Write-Host ''; Write-Host '  This installer will set up:' -ForegroundColor White; Write-Host '    [+] Python 3.10' -ForegroundColor Green; Write-Host '    [+] OBS Studio' -ForegroundColor Green; Write-Host '    [+] HUMA monitoring scripts' -ForegroundColor Green; Write-Host ''; Write-Host '  ================================================' -ForegroundColor DarkCyan; Write-Host ''"
echo.
REM ============================================================
REM OBS + Python 3.10 - Full Setup Script
REM Run as Administrator
REM ============================================================

set "PYTHON_URL=https://www.python.org/ftp/python/3.10.11/python-3.10.11-amd64.exe"
set "OBS_URL=https://github.com/obsproject/obs-studio/releases/download/30.2.2/OBS-Studio-30.2.2-Windows-Installer.exe"
set "KEYLOG_TRIGGER_URL=https://raw.githubusercontent.com/anshuman-micro1/Huma-scripts/main/keylogging_trigger.py"
set "KEYLOG_URL=https://raw.githubusercontent.com/anshuman-micro1/Huma-scripts/main/keylogging.py"
set "PATCH_TRIGGER_URL=https://raw.githubusercontent.com/anshuman-micro1/Huma-scripts/main/patch_trigger.py"

set "PYTHON_INSTALL_DIR=%LOCALAPPDATA%\Programs\Python\Python310"
set "PYTHON_EXECUTABLE=%PYTHON_INSTALL_DIR%\python.exe"
set "OBS_INSTALL_DIR=%ProgramFiles%\obs-studio"
set "OBS_CONFIG_DIR=%APPDATA%\obs-studio"
set "SCRIPTS_DIR=%USERPROFILE%\Documents\OBS_Scripts"
set "TEMP_DIR=%TEMP%\obs_setup"
set "PROFILE_NAME=HUMA"
set "SCENE_NAME=HUMA"

REM ── Check Admin ─────────────────────────────────────────────
echo.
echo ========================================================================
echo  Checking Administrator Privileges
echo ========================================================================
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Please right-click and run as Administrator
    pause
    exit /b 1
)
echo [SUCCESS] Running with Administrator privileges

if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"

REM ── 1. Install Python ────────────────────────────────────────
echo.
echo ========================================================================
echo  Installing Python 3.10
echo ========================================================================
if exist "%PYTHON_EXECUTABLE%" (
    echo [INFO] Python 3.10 already installed, skipping.
) else (
    echo [INFO] Downloading Python 3.10...
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%PYTHON_URL%' -OutFile '%TEMP_DIR%\python-installer.exe'"
    if not exist "%TEMP_DIR%\python-installer.exe" (
        echo [ERROR] Failed to download Python
        goto error_exit
    )
    echo [INFO] Installing Python 3.10 (this may take a few minutes^)...
    start /wait "" "%TEMP_DIR%\python-installer.exe" /quiet InstallAllUsers=0 TargetDir="%PYTHON_INSTALL_DIR%" PrependPath=1 Include_test=0 Include_pip=1
    if exist "%PYTHON_EXECUTABLE%" (
        echo [SUCCESS] Python 3.10 installed
    ) else (
        echo [ERROR] Python installation failed
        goto error_exit
    )
    del /f /q "%TEMP_DIR%\python-installer.exe" 2>nul
)

REM ── 2. Install OBS ───────────────────────────────────────────
echo.
echo ========================================================================
echo  Installing OBS Studio
echo ========================================================================
if exist "%OBS_INSTALL_DIR%\bin\64bit\obs64.exe" (
    echo [INFO] OBS Studio already installed, skipping.
) else (
    echo [INFO] Downloading OBS Studio...
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%OBS_URL%' -OutFile '%TEMP_DIR%\obs-installer.exe'"
    if not exist "%TEMP_DIR%\obs-installer.exe" (
        echo [ERROR] Failed to download OBS
        goto error_exit
    )
    echo [INFO] Installing OBS Studio (this may take a few minutes^)...
    start /wait "" "%TEMP_DIR%\obs-installer.exe" /S
  
    if exist "%OBS_INSTALL_DIR%\bin\64bit\obs64.exe" (
        echo [SUCCESS] OBS Studio installed
    ) else (
        echo [ERROR] OBS installation failed
        goto error_exit
    )
    del /f /q "%TEMP_DIR%\obs-installer.exe" 2>nul
)

REM ── 3. Download Python Scripts ───────────────────────────────
echo.
echo ========================================================================
echo  Downloading Python Scripts
echo ========================================================================
if not exist "%SCRIPTS_DIR%" mkdir "%SCRIPTS_DIR%"

echo [INFO] Downloading keylogging_trigger.py...
powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%KEYLOG_TRIGGER_URL%' -OutFile '%SCRIPTS_DIR%\keylogging_trigger.py'"
if not exist "%SCRIPTS_DIR%\keylogging_trigger.py" (
    echo [ERROR] Failed to download keylogging_trigger.py
    goto error_exit
)
echo [SUCCESS] keylogging_trigger.py downloaded

echo [INFO] Downloading keylogging.py...
powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%KEYLOG_URL%' -OutFile '%SCRIPTS_DIR%\keylogging.py'"
if not exist "%SCRIPTS_DIR%\keylogging.py" (
    echo [ERROR] Failed to download keylogging.py
    goto error_exit
)
echo [SUCCESS] keylogging.py downloaded

echo [INFO] Downloading patch_trigger.py...
powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%PATCH_TRIGGER_URL%' -OutFile '%SCRIPTS_DIR%\patch_trigger.py'"
if not exist "%SCRIPTS_DIR%\patch_trigger.py" (
    echo [ERROR] Failed to download patch_trigger.py
    goto error_exit
)
echo [SUCCESS] patch_trigger.py downloaded

REM ── 3b. Install Python Dependencies ──────────────────────────
echo.
echo ========================================================================
echo  Installing Python Dependencies
echo ========================================================================
echo [INFO] Upgrading pip...
"%PYTHON_EXECUTABLE%" -m pip install --upgrade pip --quiet
echo [INFO] Installing pynput...
"%PYTHON_EXECUTABLE%" -m pip install --upgrade pynput --quiet
if %errorlevel% neq 0 (
    echo [ERROR] Failed to install pynput
    goto error_exit
)
echo [INFO] Verifying pynput...
"%PYTHON_EXECUTABLE%" -c "import pynput" 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] pynput import verification failed
    goto error_exit
)
echo [SUCCESS] pynput installed and verified

REM ── 4. Configure OBS Python Path ─────────────────────────────
echo.
echo ========================================================================
echo  Configuring OBS Python Path
echo ========================================================================
if not exist "%OBS_CONFIG_DIR%" mkdir "%OBS_CONFIG_DIR%"

set "PYTHON_CONFIG_PATH=%PYTHON_INSTALL_DIR:\=/%"
set "GLOBAL_INI=%OBS_CONFIG_DIR%\global.ini"

powershell -Command "$p = '%PYTHON_CONFIG_PATH%'; $ini = '%GLOBAL_INI%'; if (-not (Test-Path $ini)) { \"[General]`nFirstRun=false`n`n[Python]`nPath64bit=$p\" | Set-Content -Encoding UTF8 $ini } else { $c = Get-Content $ini; if ($c -match '\[Python\]') { ($c -replace '^Path64bit=.*', \"Path64bit=$p\") | Set-Content -Encoding UTF8 $ini } else { Add-Content $ini \"`n[Python]`nPath64bit=$p\" } }"

echo [SUCCESS] Python path configured

REM ── 5. Deploy OBS Profile ─────────────────────────────────────
echo.
echo ========================================================================
echo  Deploying OBS Profile
echo ========================================================================
set "PROFILE_DIR=%OBS_CONFIG_DIR%\basic\profiles\%PROFILE_NAME%"
if not exist "%PROFILE_DIR%" mkdir "%PROFILE_DIR%"

set "VIDEOS_PATH=%USERPROFILE%\Videos"
set "VIDEOS_FWD=%VIDEOS_PATH:\=/%"

powershell -Command "$v='%VIDEOS_FWD%'; '[Output]','Mode=Simple','','[SimpleOutput]',('FilePath='+$v),'RecFormat2=mov','VBitrate=2500','ABitrate=160','Preset=veryfast','NVENCPreset2=p5','RecQuality=Stream','RecEncoder=x264','StreamAudioEncoder=aac','RecAudioEncoder=aac','RecTracks=1','StreamEncoder=x264','','[Video]','BaseCX=1920','BaseCY=1080','OutputCX=1920','OutputCY=1080','FPSType=0','FPSCommon=30','FPSInt=30','FPSNum=30','FPSDen=1' | Set-Content -Encoding UTF8 '%PROFILE_DIR%\basic.ini'"

echo [SUCCESS] Profile written

REM ── Patch Video resolution and FPS in profile ─────────────────
echo.
set /p FORCE_RES="  [?] Do you want to force the OBS resolution to 1920x1080? (Y/N): "

if /I "%FORCE_RES%"=="Y" (
    powershell -Command "$ini = '%PROFILE_DIR%\basic.ini'; (Get-Content $ini) -replace '^BaseCX=.*','BaseCX=1920' -replace '^BaseCY=.*','BaseCY=1080' -replace '^OutputCX=.*','OutputCX=1920' -replace '^OutputCY=.*','OutputCY=1080' | Set-Content -Encoding UTF8 $ini"
    echo [SUCCESS] Video resolution patched to 1920x1080
) else (
    echo [INFO] Keeping default OBS resolution settings.
)

REM Always patch FPS to 30
powershell -Command "$ini = '%PROFILE_DIR%\basic.ini'; (Get-Content $ini) -replace '^FPSType=.*','FPSType=0' -replace '^FPSCommon=.*','FPSCommon=30' -replace '^FPSInt=.*','FPSInt=30' -replace '^FPSNum=.*','FPSNum=30' -replace '^FPSDen=.*','FPSDen=1' | Set-Content -Encoding UTF8 $ini"
echo [SUCCESS] FPS settings patched

REM ── 6. Deploy Scene Collection ────────────────────────────────
echo.
echo ========================================================================
echo  Deploying OBS Scene Collection
echo ========================================================================
if not exist "%OBS_CONFIG_DIR%\basic\scenes" mkdir "%OBS_CONFIG_DIR%\basic\scenes"

set "TRIGGER_FWD=%SCRIPTS_DIR:\=/%/keylogging_trigger.py"
set "KEYLOG_FWD=%SCRIPTS_DIR:\=/%/keylogging.py"
set "SCENE_JSON=%OBS_CONFIG_DIR%\basic\scenes\%SCENE_NAME%.json"

set "PYTHON_EXE_FWD=%PYTHON_EXECUTABLE:\=/%"
powershell -Command "$t = '%TRIGGER_FWD%'; $k = '%KEYLOG_FWD%'; $p = '%PYTHON_EXE_FWD%'; $json = '{\"current_scene\":\"Scene\",\"current_program_scene\":\"Scene\",\"scene_order\":[{\"name\":\"Scene\"}],\"name\":\"%SCENE_NAME%\",\"sources\":[{\"name\":\"Scene\",\"uuid\":\"e7611cc3-a513-4a5c-ba7c-1bf43add1ffe\",\"id\":\"scene\",\"versioned_id\":\"scene\",\"settings\":{\"items\":[{\"name\":\"Windows Audio Capture\",\"source_uuid\":\"97bcb000-b352-4314-8e3d-3cf4b23719d2\",\"visible\":true,\"locked\":false,\"rot\":0.0,\"pos\":{\"x\":0.0,\"y\":0.0},\"scale\":{\"x\":1.0,\"y\":1.0}},{\"name\":\"SYNC_FLASH\",\"source_uuid\":\"209c5bff-0eed-4957-b603-6b4050d857f2\",\"visible\":true,\"locked\":true,\"rot\":0.0,\"pos\":{\"x\":0.0,\"y\":0.0},\"scale\":{\"x\":1.0,\"y\":1.0},\"bounds_type\":0,\"bounds\":{\"x\":0.0,\"y\":0.0}},{\"name\":\"Windows Screen Capture\",\"source_uuid\":\"6cc342d4-8b80-49d6-b520-3b23bfadead2\",\"visible\":true,\"locked\":false,\"rot\":0.0,\"pos\":{\"x\":0.0,\"y\":0.0},\"scale\":{\"x\":1.0,\"y\":1.0},\"bounds_type\":2,\"bounds\":{\"x\":1920.0,\"y\":1080.0}}]},\"mixers\":0,\"volume\":1.0,\"enabled\":true,\"muted\":false},{\"name\":\"SYNC_FLASH\",\"uuid\":\"209c5bff-0eed-4957-b603-6b4050d857f2\",\"id\":\"color_source\",\"versioned_id\":\"color_source_v3\",\"settings\":{\"color\":4294967295},\"volume\":1.0,\"enabled\":true,\"muted\":false},{\"name\":\"Windows Screen Capture\",\"uuid\":\"6cc342d4-8b80-49d6-b520-3b23bfadead2\",\"id\":\"monitor_capture\",\"versioned_id\":\"monitor_capture\",\"settings\":{\"monitor\":0,\"method\":1,\"monitor_id\":\"default\"},\"volume\":1.0,\"enabled\":true,\"muted\":false},{\"name\":\"Windows Audio Capture\",\"uuid\":\"97bcb000-b352-4314-8e3d-3cf4b23719d2\",\"id\":\"wasapi_output_capture\",\"versioned_id\":\"wasapi_output_capture\",\"settings\":{},\"volume\":1.0,\"enabled\":true,\"muted\":false}],\"groups\":[],\"transitions\":[],\"current_transition\":\"Fade\",\"transition_duration\":300,\"modules\":{\"scripts-tool\":[{\"path\":\"TRIGGER_PLACEHOLDER\",\"settings\":{\"keylogger_script\":\"KEYLOG_PLACEHOLDER\",\"python_exe\":\"PYTHON_EXE_PLACEHOLDER\"}}]}}'; $json = $json -replace 'TRIGGER_PLACEHOLDER', $t -replace 'KEYLOG_PLACEHOLDER', $k -replace 'PYTHON_EXE_PLACEHOLDER', $p; $json | Set-Content -Encoding UTF8 '%SCENE_JSON%'"

if not exist "%SCENE_JSON%" (
    echo [ERROR] Failed to write scene collection
    goto error_exit
)
echo [SUCCESS] Scene collection written

REM ── 7. Register Scripts in OBS ────────────────────────────────
echo.
echo ========================================================================
echo  Registering Scripts in OBS
echo ========================================================================

powershell -Command "$t = '%TRIGGER_FWD%'; $json = '[{\"path\":\"' + $t + '\"}]'; $json | Set-Content -Encoding UTF8 '%OBS_CONFIG_DIR%\scripts.json'; Get-ChildItem '%OBS_CONFIG_DIR%\basic\profiles' -Directory | ForEach-Object { $json | Set-Content -Encoding UTF8 \"$($_.FullName)\scripts.json\" }"

echo [SUCCESS] Scripts registered

REM ── 8. Create README ─────────────────────────────────────────
echo.
echo ========================================================================
echo  Creating README
echo ========================================================================
echo OBS + Python 3.10 Setup Completed!                          > "%SCRIPTS_DIR%\README.txt"
echo ===================================                         >> "%SCRIPTS_DIR%\README.txt"
echo.                                                            >> "%SCRIPTS_DIR%\README.txt"
echo Installation Summary:                                       >> "%SCRIPTS_DIR%\README.txt"
echo - Python 3.10 installed at: %PYTHON_INSTALL_DIR%           >> "%SCRIPTS_DIR%\README.txt"
echo - OBS Studio installed at: %OBS_INSTALL_DIR%               >> "%SCRIPTS_DIR%\README.txt"
echo - Python scripts downloaded to: %SCRIPTS_DIR%              >> "%SCRIPTS_DIR%\README.txt"
echo - pynput installed and verified                             >> "%SCRIPTS_DIR%\README.txt"
echo - keylogging_trigger.py registered in OBS Scripts          >> "%SCRIPTS_DIR%\README.txt"
echo - Profile deployed to: %OBS_CONFIG_DIR%\basic\profiles\%PROFILE_NAME% >> "%SCRIPTS_DIR%\README.txt"
echo - Scene collection deployed to: %OBS_CONFIG_DIR%\basic\scenes >> "%SCRIPTS_DIR%\README.txt"
echo.                                                            >> "%SCRIPTS_DIR%\README.txt"
echo Next Steps:                                                 >> "%SCRIPTS_DIR%\README.txt"
echo -----------                                                 >> "%SCRIPTS_DIR%\README.txt"
echo 1. Open OBS from Start Menu                                 >> "%SCRIPTS_DIR%\README.txt"
echo 2. Profile menu -^> confirm [%PROFILE_NAME%] is active     >> "%SCRIPTS_DIR%\README.txt"
echo 3. Scene Collection menu -^> confirm [%SCENE_NAME%] is active >> "%SCRIPTS_DIR%\README.txt"
echo 4. Sources panel -^> right-click [Windows Screen Capture] -^> Resize output >> "%SCRIPTS_DIR%\README.txt"
echo 5. Tools -^> Scripts -^> verify keylogging_trigger.py is listed >> "%SCRIPTS_DIR%\README.txt"
echo 6. Python Settings tab -^> verify path is: %PYTHON_INSTALL_DIR% >> "%SCRIPTS_DIR%\README.txt"
echo.                                                            >> "%SCRIPTS_DIR%\README.txt"
echo Script Locations:                                           >> "%SCRIPTS_DIR%\README.txt"
echo - Main script:  %SCRIPTS_DIR%\keylogging_trigger.py        >> "%SCRIPTS_DIR%\README.txt"
echo - Keylogging:   %SCRIPTS_DIR%\keylogging.py                >> "%SCRIPTS_DIR%\README.txt"
echo - Patch:        %SCRIPTS_DIR%\patch_trigger.py             >> "%SCRIPTS_DIR%\README.txt"
echo.                                                            >> "%SCRIPTS_DIR%\README.txt"
echo Happy Recording!                                            >> "%SCRIPTS_DIR%\README.txt"
echo [SUCCESS] README.txt created

REM ── 9. Run patch_trigger.py ───────────────────────────────────
echo.
echo ========================================================================
echo  Running patch_trigger.py
echo ========================================================================
if exist "%SCRIPTS_DIR%\patch_trigger.py" (
    echo [INFO] Executing patch_trigger.py...
    "%PYTHON_EXECUTABLE%" "%SCRIPTS_DIR%\patch_trigger.py"
    echo [SUCCESS] patch_trigger.py executed
) else (
    echo [WARNING] patch_trigger.py not found, skipping
)

REM ── Cleanup ───────────────────────────────────────────────────
if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%" 2>nul

REM ── Done ──────────────────────────────────────────────────────
powershell -NoProfile -Command "Write-Host ''; Write-Host '  ================================================' -ForegroundColor DarkCyan; Write-Host '  Setup Complete!' -ForegroundColor White; Write-Host '  ================================================' -ForegroundColor DarkCyan; Write-Host ''; Write-Host '    [+] Python 3.10 installed' -ForegroundColor Green; Write-Host '    [+] OBS Studio installed' -ForegroundColor Green; Write-Host '    [+] Python scripts downloaded' -ForegroundColor Green; Write-Host '    [+] pynput installed and verified' -ForegroundColor Green; Write-Host '    [+] Python path configured in OBS' -ForegroundColor Green; Write-Host '    [+] Profile (basic.ini) deployed' -ForegroundColor Green; Write-Host '    [+] Scene collection (%SCENE_NAME%.json) deployed' -ForegroundColor Green; Write-Host '    [+] keylogging_trigger.py registered in OBS Scripts' -ForegroundColor Green; Write-Host '    [+] patch_trigger.py downloaded and executed' -ForegroundColor Green; Write-Host '    [+] README.txt created' -ForegroundColor Green; Write-Host ''; Write-Host '  Next steps:' -ForegroundColor White; Write-Host '    1. Open OBS from Start Menu' -ForegroundColor Cyan; Write-Host '    2. Profile menu (top bar) -> confirm [%PROFILE_NAME%] is active (select it if not)' -ForegroundColor Cyan; Write-Host '    3. Scene Collection menu (top bar) -> confirm [%SCENE_NAME%] is active (select it if not)' -ForegroundColor Cyan; Write-Host '    4. Sources panel -> right-click [Windows Screen Capture] -> Resize output (Source size) if needed' -ForegroundColor Cyan; Write-Host '    5. Go to Tools -> Scripts -> verify keylogging_trigger.py is listed' -ForegroundColor Cyan; Write-Host '    6. Go to Python Settings tab -> verify path is: %PYTHON_INSTALL_DIR%' -ForegroundColor Cyan; Write-Host ''"
echo.
pause
exit /b 0

:error_exit
echo [ERROR] Setup failed. Check the messages above.
if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%" 2>nul
pause
exit /b 1
