#!/bin/bash

################################################################################
# OBS + Python 3.10 Setup Script for macOS
# This script automates the installation of Python 3.10, OBS Studio, and
# configures the required Python scripts for OBS.
# Deploys a pre-configured profile (basic.ini) and scene collection
# (HUMA.json) with paths adjusted to the current user.
################################################################################

set -e  # Exit on error

# =============================================================================
# COLORS
# =============================================================================

BOLD=$'\033[1m'
DIM=$'\033[2m'
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
CYAN=$'\033[0;36m'
NC=$'\033[0m'

# =============================================================================
# CONFIGURATION - Edit these URLs as needed
# =============================================================================

PYTHON_URL="https://www.python.org/ftp/python/3.10.11/python-3.10.11-macos11.pkg"
if [ "$(uname -m)" = "arm64" ]; then
    OBS_URL="https://github.com/obsproject/obs-studio/releases/download/30.2.2/obs-studio-30.2.2-macos-apple.dmg"
else
    OBS_URL="https://github.com/obsproject/obs-studio/releases/download/30.2.2/obs-studio-30.2.2-macos-x86_64.dmg"
fi

KEYLOGGING_TRIGGER_URL="https://raw.githubusercontent.com/anshuman-micro1/Huma-scripts/main/keylogging_trigger.py"
KEYLOGGING_URL="https://raw.githubusercontent.com/anshuman-micro1/Huma-scripts/main/keylogging.py"
PATCH_TRIGGER_URL="https://raw.githubusercontent.com/anshuman-micro1/Huma-scripts/main/patch_trigger.py"

PYTHON_VERSION="3.10"
PYTHON_FRAMEWORK_PATH="/Library/Frameworks/Python.framework/Versions/${PYTHON_VERSION}"
PYTHON_EXECUTABLE="${PYTHON_FRAMEWORK_PATH}/bin/python3.10"
OBS_APP_PATH="/Applications/OBS.app"
SCRIPTS_DIR="$HOME/Downloads/OBS_Scripts"

# Profile and scene collection names (must match the filenames)
PROFILE_NAME="HUMA"
SCENE_COLLECTION_NAME="HUMA"

# =============================================================================
# COMMAND LINE ARGUMENTS (Override defaults)
# =============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --python-url)
            PYTHON_URL="$2"
            shift 2
            ;;
        --obs-url)
            OBS_URL="$2"
            shift 2
            ;;
        --script-url)
            KEYLOGGING_TRIGGER_URL="$2"
            shift 2
            ;;
        --keylogging-url)
            KEYLOGGING_URL="$2"
            shift 2
            ;;
        --patch-trigger-url)
            PATCH_TRIGGER_URL="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--python-url URL] [--obs-url URL] [--script-url URL] [--keylogging-url URL] [--patch-trigger-url URL]"
            exit 1
            ;;
    esac
done

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

print_welcome() {
    clear
    printf "\n"
    printf "${CYAN}${BOLD}  ██╗  ██╗██╗   ██╗███╗   ███╗  █████╗ \n"
    printf "  ██║  ██║██║   ██║████╗ ████║ ██╔══██╗\n"
    printf "  ███████║██║   ██║██╔████╔██║ ███████║\n"
    printf "  ██╔══██║██║   ██║██║╚██╔╝██║ ██╔══██║\n"
    printf "  ██║  ██║╚██████╔╝██║ ╚═╝ ██║ ██║  ██║\n"
    printf "  ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝ ╚═╝  ╚═╝${NC}\n"
    printf "\n"
    printf "  ${BOLD}Welcome to HUMA${NC}\n"
    printf "  ${DIM}OBS Studio Automated Setup for macOS${NC}\n"
    printf "\n"
    printf "  ${DIM}This installer will set up:${NC}\n"
    printf "  ${GREEN}  ●${NC} Python 3.10\n"
    printf "  ${GREEN}  ●${NC} OBS Studio\n"
    printf "  ${GREEN}  ●${NC} HUMA monitoring scripts\n"
    printf "\n"
    printf "  ${DIM}──────────────────────────────────────────────${NC}\n"
    printf "\n"
}

print_header() {
    printf "\n"
    printf "${BLUE}${BOLD}  ════════════════════════════════════════════${NC}\n"
    printf "${BLUE}${BOLD}  %s${NC}\n" "$1"
    printf "${BLUE}${BOLD}  ════════════════════════════════════════════${NC}\n"
}

print_info() {
    printf "  ${YELLOW}→${NC} %s\n" "$1"
}

print_success() {
    printf "  ${GREEN}✓${NC} %s\n" "$1"
}

print_error() {
    printf "  ${RED}✗ ERROR:${NC} %s\n" "$1" >&2
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        return 1
    fi
    return 0
}

# =============================================================================
# INSTALLATION FUNCTIONS
# =============================================================================

install_python() {
    print_header "Installing Python ${PYTHON_VERSION}"

    if [ -f "$PYTHON_EXECUTABLE" ]; then
        print_info "Python ${PYTHON_VERSION} is already installed at ${PYTHON_EXECUTABLE}"
        return 0
    fi

    print_info "Downloading Python ${PYTHON_VERSION} installer..."
    PYTHON_PKG="/tmp/python-${PYTHON_VERSION}.pkg"
    curl -L --progress-bar -o "$PYTHON_PKG" "$PYTHON_URL"

    if [ ! -f "$PYTHON_PKG" ]; then
        print_error "Failed to download Python installer"
        exit 1
    fi

    print_info "Installing Python ${PYTHON_VERSION} (requires sudo)..."
    sudo installer -pkg "$PYTHON_PKG" -target /

    if [ -f "$PYTHON_EXECUTABLE" ]; then
        print_success "Python ${PYTHON_VERSION} installed successfully"
        "$PYTHON_EXECUTABLE" --version
    else
        print_error "Python installation failed"
        exit 1
    fi

    rm -f "$PYTHON_PKG"
}

install_obs() {
    print_header "Installing OBS Studio"

    if [ -d "$OBS_APP_PATH" ]; then
        print_info "OBS Studio is already installed at ${OBS_APP_PATH}"
        return 0
    fi

    print_info "Downloading OBS Studio..."
    OBS_DMG="/tmp/obs-studio.dmg"
    curl -L --progress-bar -o "$OBS_DMG" "$OBS_URL"

    if [ ! -f "$OBS_DMG" ]; then
        print_error "Failed to download OBS Studio"
        exit 1
    fi

    # Detach any previously stuck mounts of this DMG
    print_info "Cleaning up any previous mounts..."
    STALE_VOLUME=$(hdiutil info | awk -F'\t' '/\/Volumes\//{print $NF}' | head -1 | xargs)
    if [ -n "$STALE_VOLUME" ]; then
        print_info "Detaching stale mount: ${STALE_VOLUME}"
        hdiutil detach "$STALE_VOLUME" -force -quiet || true
    fi

    print_info "Mounting DMG..."
    MOUNT_OUTPUT=$(hdiutil attach "$OBS_DMG" -noverify)
    echo "$MOUNT_OUTPUT"

    # Use tab delimiter to correctly capture volume paths that contain spaces
    VOLUME=$(echo "$MOUNT_OUTPUT" | awk -F'\t' '/\/Volumes\//{print $NF}' | tail -1 | xargs)

    if [ -z "$VOLUME" ]; then
        print_error "Failed to detect mounted volume. Full hdiutil output:"
        echo "$MOUNT_OUTPUT"
        exit 1
    fi

    print_info "Mounted at: ${VOLUME}"
    print_info "Contents of volume:"
    ls -la "$VOLUME"

    # Find .app dynamically regardless of exact name
    APP_PATH=$(find "$VOLUME" -maxdepth 1 -name "*.app" | head -1)

    if [ -z "$APP_PATH" ]; then
        print_error "Could not find .app in mounted volume: ${VOLUME}"
        hdiutil detach "$VOLUME" -force -quiet
        exit 1
    fi

    print_info "Copying $(basename "$APP_PATH") to Applications..."
    sudo cp -R "$APP_PATH" /Applications/
    sudo xattr -dr com.apple.quarantine /Applications/OBS.app 2>/dev/null || true

    print_info "Unmounting DMG..."
    hdiutil detach "$VOLUME" -force -quiet

    if [ -d "$OBS_APP_PATH" ]; then
        print_success "OBS Studio installed successfully"
    else
        print_error "OBS installation failed"
        exit 1
    fi

    rm -f "$OBS_DMG"
}

install_python_packages() {
    print_header "Installing Required Python Packages"

    PIP_EXECUTABLE="${PYTHON_FRAMEWORK_PATH}/bin/pip3.10"

    # Ensure pip is available
    if [ ! -f "$PIP_EXECUTABLE" ]; then
        print_info "pip not found at ${PIP_EXECUTABLE}, bootstrapping via ensurepip..."
        "$PYTHON_EXECUTABLE" -m ensurepip --upgrade
        "$PYTHON_EXECUTABLE" -m pip install --upgrade pip --quiet
    fi

    print_info "Installing pynput..."
    "$PYTHON_EXECUTABLE" -m pip install --upgrade pynput --quiet

    if "$PYTHON_EXECUTABLE" -c "import pynput" 2>/dev/null; then
        print_success "pynput installed successfully"
    else
        print_error "pynput installation failed"
        exit 1
    fi
}

download_scripts() {
    print_header "Downloading Python Scripts"

    mkdir -p "$SCRIPTS_DIR"

    print_info "Downloading keylogging_trigger.py..."
    curl -L -f --progress-bar -o "${SCRIPTS_DIR}/keylogging_trigger.py" "$KEYLOGGING_TRIGGER_URL" || {
        print_error "Failed to download keylogging_trigger.py"
        print_info "Please download manually from: https://github.com/anshuman-micro1/Huma-scripts/blob/main/keylogging_trigger.py"
        print_info "Save it to: ${SCRIPTS_DIR}/keylogging_trigger.py"
        exit 1
    }
    print_success "keylogging_trigger.py downloaded successfully"

    print_info "Downloading keylogging.py..."
    curl -L -f --progress-bar -o "${SCRIPTS_DIR}/keylogging.py" "$KEYLOGGING_URL" || {
        print_error "Failed to download keylogging.py"
        print_info "Please download manually from: https://github.com/anshuman-micro1/Huma-scripts/blob/main/keylogging.py"
        print_info "Save it to: ${SCRIPTS_DIR}/keylogging.py"
        exit 1
    }
    print_success "keylogging.py downloaded successfully"

    print_info "Downloading patch_trigger.py..."
    curl -L -f --progress-bar -o "${SCRIPTS_DIR}/patch_trigger.py" "$PATCH_TRIGGER_URL" || {
        print_error "Failed to download patch_trigger.py"
        print_info "Please download manually from: https://github.com/anshuman-micro1/Huma-scripts/blob/main/patch_trigger.py"
        print_info "Save it to: ${SCRIPTS_DIR}/patch_trigger.py"
        exit 1
    }
    print_success "patch_trigger.py downloaded successfully"

    print_success "All scripts downloaded to ${SCRIPTS_DIR}"
}

run_patch_trigger() {
    print_header "Running patch_trigger.py"

    PATCH_TRIGGER_PATH="${SCRIPTS_DIR}/patch_trigger.py"

    if [ ! -f "$PATCH_TRIGGER_PATH" ]; then
        print_error "patch_trigger.py not found at: ${PATCH_TRIGGER_PATH}"
        exit 1
    fi

    print_info "Executing patch_trigger.py with ${PYTHON_EXECUTABLE}..."
    "$PYTHON_EXECUTABLE" "$PATCH_TRIGGER_PATH"
    print_success "patch_trigger.py executed successfully"
}

configure_obs_python() {
    print_header "Configuring OBS Python Settings"

    OBS_CONFIG_DIR="$HOME/Library/Application Support/obs-studio"
    GLOBAL_INI="${OBS_CONFIG_DIR}/global.ini"

    mkdir -p "$OBS_CONFIG_DIR"

    print_info "Setting Python path in OBS configuration..."

    if [ ! -f "$GLOBAL_INI" ]; then
        print_info "Creating new OBS configuration file..."
        cat > "$GLOBAL_INI" << EOF
[General]
FirstRun=false

[Python]
Path64bit=${PYTHON_FRAMEWORK_PATH}
EOF
    else
        if grep -q "\[Python\]" "$GLOBAL_INI"; then
            sed -i.bak "/\[Python\]/,/^\[/ s|^Path64bit=.*|Path64bit=${PYTHON_FRAMEWORK_PATH}|" "$GLOBAL_INI"
        else
            echo "" >> "$GLOBAL_INI"
            echo "[Python]" >> "$GLOBAL_INI"
            echo "Path64bit=${PYTHON_FRAMEWORK_PATH}" >> "$GLOBAL_INI"
        fi
    fi

    print_success "OBS Python path configured"
    print_info "Python Framework Path: ${PYTHON_FRAMEWORK_PATH}"
    print_info "Python Executable: ${PYTHON_EXECUTABLE}"
}

# -----------------------------------------------------------------------------
# deploy_obs_profile
# Writes basic.ini into:
#   $HOME/Library/Application Support/obs-studio/basic/profiles/HUMA/
# All recording FilePath entries are set to the current user's ~/Movies.
# -----------------------------------------------------------------------------
deploy_obs_profile() {
    print_header "Deploying OBS Profile (basic.ini)"

    OBS_PROFILE_DIR="$HOME/Library/Application Support/obs-studio/basic/profiles/${PROFILE_NAME}"
    mkdir -p "$OBS_PROFILE_DIR"

    PROFILE_INI="${OBS_PROFILE_DIR}/basic.ini"
    MOVIES_PATH="$HOME/Movies"

    print_info "Writing profile to: ${PROFILE_INI}"

    # Write only the settings we need — OBS fills in all other defaults on first launch
    printf '%s\n' \
        '[Output]' \
        'Mode=Simple' \
        '' \
        '[SimpleOutput]' \
        "FilePath=${MOVIES_PATH}" \
        'RecFormat2=mov' \
        'VBitrate=2500' \
        'ABitrate=160' \
        'Preset=veryfast' \
        'NVENCPreset2=p5' \
        'RecQuality=Stream' \
        'RecEncoder=apple_h264' \
        'StreamAudioEncoder=aac' \
        'RecAudioEncoder=aac' \
        'RecTracks=1' \
        'StreamEncoder=x264' \
        '' \
        '[Video]' \
        'BaseCX=1920' \
        'BaseCY=1080' \
        'OutputCX=1920' \
        'OutputCY=1080' \
        'FPSType=0' \
        'FPSCommon=30' \
        'FPSInt=30' \
        'FPSNum=30' \
        'FPSDen=1' \
        > "$PROFILE_INI"

    # Detect display resolution
    RESOLUTION_LINE=$(system_profiler SPDisplaysDataType 2>/dev/null | grep -i "Resolution:" | head -1)
    SCREEN_W=$(echo "$RESOLUTION_LINE" | grep -oE '[0-9]+' | sed -n '1p')
    SCREEN_H=$(echo "$RESOLUTION_LINE" | grep -oE '[0-9]+' | sed -n '2p')
    if [ -n "$SCREEN_W" ] && [ -n "$SCREEN_H" ] && [ "$SCREEN_W" -ge 1920 ] && [ "$SCREEN_H" -ge 1080 ]; then
        CANVAS_W=1920
        CANVAS_H=1080
    else
        CANVAS_W=${SCREEN_W:-2880}
        CANVAS_H=${SCREEN_H:-1800}
    fi
    
    printf "  ${YELLOW}?${NC} Do you want to force the OBS canvas and output resolution to ${CANVAS_W}x${CANVAS_H}? (y/n): "
    read -r FORCE_RES < /dev/tty

    if [[ "$FORCE_RES" =~ ^[Yy]$ ]]; then
        sed -i '' \
            -e "s/^BaseCX=.*/BaseCX=${CANVAS_W}/" \
            -e "s/^BaseCY=.*/BaseCY=${CANVAS_H}/" \
            -e "s/^OutputCX=.*/OutputCX=${CANVAS_W}/" \
            -e "s/^OutputCY=.*/OutputCY=${CANVAS_H}/" \
            "$PROFILE_INI"
        print_info "Canvas resolution forced to: ${CANVAS_W}x${CANVAS_H}"
    else
        print_info "Keeping default OBS resolution settings."
    fi

    # Still patch FPS to 30
    sed -i '' \
        -e "s/^FPSType=.*/FPSType=0/" \
        -e "s/^FPSCommon=.*/FPSCommon=30/" \
        -e "s/^FPSInt=.*/FPSInt=30/" \
        -e "s/^FPSNum=.*/FPSNum=30/" \
        -e "s/^FPSDen=.*/FPSDen=1/" \
        "$PROFILE_INI"

    print_success "Profile written to: ${PROFILE_INI}"
    print_info "Recording save path set to: ${MOVIES_PATH}"
}

# -----------------------------------------------------------------------------
# deploy_obs_scene_collection
# Writes HUMA.json into the scenes directory, substituting the current
# user's SCRIPTS_DIR paths and Python executable into the JSON.
# -----------------------------------------------------------------------------
deploy_obs_scene_collection() {
    print_header "Deploying OBS Scene Collection (${SCENE_COLLECTION_NAME}.json)"

    OBS_SCENES_DIR="$HOME/Library/Application Support/obs-studio/basic/scenes"
    mkdir -p "$OBS_SCENES_DIR"

    SCENE_JSON="${OBS_SCENES_DIR}/${SCENE_COLLECTION_NAME}.json"
    SCRIPT_PATH="${SCRIPTS_DIR}/keylogging_trigger.py"
    KEYLOGGER_PATH="${SCRIPTS_DIR}/keylogging.py"

    print_info "Writing scene collection to: ${SCENE_JSON}"

    # Write the scene collection JSON with placeholder tokens, then substitute
    # the real paths in a single sed pass so no hardcoded usernames remain.
    cat > "$SCENE_JSON" << 'JSONEOF'
{"DesktopAudioDevice1":{"prev_ver":503447554,"name":"__unnamed0000","uuid":"58cc23b8-efcc-4035-84ea-89bec2c8fd18","id":"","versioned_id":"","settings":{},"mixers":63,"sync":0,"flags":0,"volume":1.0,"balance":0.5,"enabled":true,"muted":false,"push-to-mute":false,"push-to-mute-delay":0,"push-to-talk":false,"push-to-talk-delay":0,"hotkeys":{},"deinterlace_mode":0,"deinterlace_field_order":0,"monitoring_type":0,"private_settings":{}},"AuxAudioDevice1":{"prev_ver":503447554,"name":"__unnamed0001","uuid":"460a9e03-e3af-4b4b-95f2-8c9f283e9363","id":"","versioned_id":"","settings":{},"mixers":63,"sync":0,"flags":0,"volume":1.0,"balance":0.5,"enabled":true,"muted":false,"push-to-mute":false,"push-to-mute-delay":0,"push-to-talk":false,"push-to-talk-delay":0,"hotkeys":{},"deinterlace_mode":0,"deinterlace_field_order":0,"monitoring_type":0,"private_settings":{}},"AuxAudioDevice2":{"prev_ver":503447554,"name":"__unnamed0002","uuid":"0985f61c-95b0-407c-bba8-043f7bb55ef7","id":"","versioned_id":"","settings":{},"mixers":63,"sync":0,"flags":0,"volume":1.0,"balance":0.5,"enabled":true,"muted":false,"push-to-mute":false,"push-to-mute-delay":0,"push-to-talk":false,"push-to-talk-delay":0,"hotkeys":{},"deinterlace_mode":0,"deinterlace_field_order":0,"monitoring_type":0,"private_settings":{}},"AuxAudioDevice3":{"prev_ver":503447554,"name":"__unnamed0003","uuid":"806620b6-b1ec-4d38-97ae-bcd0bf5bf8c4","id":"","versioned_id":"","settings":{},"mixers":63,"sync":0,"flags":0,"volume":1.0,"balance":0.5,"enabled":true,"muted":false,"push-to-mute":false,"push-to-mute-delay":0,"push-to-talk":false,"push-to-talk-delay":0,"hotkeys":{},"deinterlace_mode":0,"deinterlace_field_order":0,"monitoring_type":0,"private_settings":{}},"AuxAudioDevice4":{"prev_ver":503447554,"name":"__unnamed0004","uuid":"8fa3c1e1-2e24-41ae-afa6-c032c199e533","id":"","versioned_id":"","settings":{},"mixers":63,"sync":0,"flags":0,"volume":1.0,"balance":0.5,"enabled":true,"muted":false,"push-to-mute":false,"push-to-mute-delay":0,"push-to-talk":false,"push-to-talk-delay":0,"hotkeys":{},"deinterlace_mode":0,"deinterlace_field_order":0,"monitoring_type":0,"private_settings":{}},"current_scene":"Scene","current_program_scene":"Scene","scene_order":[{"name":"Scene"}],"name":"HUMA","sources":[{"prev_ver":503447554,"name":"Scene","uuid":"e7611cc3-a513-4a5c-ba7c-1bf43add1ffe","id":"scene","versioned_id":"scene","settings":{"items":[{"name":"SYNC_FLASH","source_uuid":"209c5bff-0eed-4957-b603-6b4050d857f2","visible":true,"locked":true,"rot":0.0,"pos":{"x":0.0,"y":0.0},"scale":{"x":1.0,"y":1.0},"align":5,"bounds_type":0,"bounds_align":0,"bounds_crop":false,"bounds":{"x":0.0,"y":0.0},"crop_left":0,"crop_top":0,"crop_right":0,"crop_bottom":0,"id":1,"group_item_backup":false,"scale_filter":"disable","blend_method":"default","blend_type":"normal","show_transition":{"duration":0},"hide_transition":{"duration":0},"private_settings":{}},{"name":"macOS Screen Capture","source_uuid":"6cc342d4-8b80-49d6-b520-3b23bfadead2","visible":true,"locked":false,"rot":0.0,"pos":{"x":0.0,"y":0.0},"scale":{"x":1.0,"y":1.0},"align":5,"bounds_type":2,"bounds_align":0,"bounds_crop":false,"bounds":{"x":2880.0,"y":1800.0},"crop_left":0,"crop_top":0,"crop_right":0,"crop_bottom":0,"id":2,"group_item_backup":false,"scale_filter":"disable","blend_method":"default","blend_type":"normal","show_transition":{"duration":0},"hide_transition":{"duration":0},"private_settings":{}},{"name":"macOS Audio Capture","source_uuid":"97bcb000-b352-4314-8e3d-3cf4b23719d2","visible":true,"locked":false,"rot":0.0,"pos":{"x":0.0,"y":0.0},"scale":{"x":1.0,"y":1.0},"align":5,"bounds_type":0,"bounds_align":0,"bounds_crop":false,"bounds":{"x":0.0,"y":0.0},"crop_left":0,"crop_top":0,"crop_right":0,"crop_bottom":0,"id":3,"group_item_backup":false,"scale_filter":"disable","blend_method":"default","blend_type":"normal","show_transition":{"duration":0},"hide_transition":{"duration":0},"private_settings":{}}],"id_counter":3,"custom_size":false},"mixers":0,"sync":0,"flags":0,"volume":1.0,"balance":0.5,"enabled":true,"muted":false,"push-to-mute":false,"push-to-mute-delay":0,"push-to-talk":false,"push-to-talk-delay":0,"hotkeys":{"OBSBasic.SelectScene":[],"libobs.show_scene_item.1":[],"libobs.hide_scene_item.1":[],"libobs.show_scene_item.2":[],"libobs.hide_scene_item.2":[],"libobs.show_scene_item.3":[],"libobs.hide_scene_item.3":[]},"deinterlace_mode":0,"deinterlace_field_order":0,"monitoring_type":0,"private_settings":{}},{"prev_ver":503447554,"name":"SYNC_FLASH","uuid":"209c5bff-0eed-4957-b603-6b4050d857f2","id":"color_source","versioned_id":"color_source_v3","settings":{"color":4294967295},"mixers":0,"sync":0,"flags":0,"volume":1.0,"balance":0.5,"enabled":true,"muted":false,"push-to-mute":false,"push-to-mute-delay":0,"push-to-talk":false,"push-to-talk-delay":0,"hotkeys":{},"deinterlace_mode":0,"deinterlace_field_order":0,"monitoring_type":0,"private_settings":{}},{"prev_ver":503447554,"name":"macOS Screen Capture","uuid":"6cc342d4-8b80-49d6-b520-3b23bfadead2","id":"screen_capture","versioned_id":"screen_capture","settings":{},"mixers":255,"sync":0,"flags":0,"volume":1.0,"balance":0.5,"enabled":true,"muted":false,"push-to-mute":false,"push-to-mute-delay":0,"push-to-talk":false,"push-to-talk-delay":0,"hotkeys":{"libobs.mute":[],"libobs.unmute":[],"libobs.push-to-mute":[],"libobs.push-to-talk":[]},"deinterlace_mode":0,"deinterlace_field_order":0,"monitoring_type":0,"private_settings":{}},{"prev_ver":503447554,"name":"macOS Audio Capture","uuid":"97bcb000-b352-4314-8e3d-3cf4b23719d2","id":"sck_audio_capture","versioned_id":"sck_audio_capture","settings":{},"mixers":255,"sync":0,"flags":0,"volume":1.0,"balance":0.5,"enabled":true,"muted":false,"push-to-mute":false,"push-to-mute-delay":0,"push-to-talk":false,"push-to-talk-delay":0,"hotkeys":{"libobs.mute":[],"libobs.unmute":[],"libobs.push-to-mute":[],"libobs.push-to-talk":[]},"deinterlace_mode":0,"deinterlace_field_order":0,"monitoring_type":0,"private_settings":{}}],"groups":[],"quick_transitions":[],"transitions":[],"saved_projectors":[],"current_transition":"Fade","transition_duration":300,"preview_locked":false,"scaling_enabled":false,"scaling_level":0,"scaling_off_x":0.0,"scaling_off_y":0.0,"virtual-camera":{"type2":3},"modules":{"scripts-tool":[{"path":"SCRIPT_PATH_PLACEHOLDER","settings":{"keylogger_script":"KEYLOGGER_PATH_PLACEHOLDER","python_exe":"PYTHON_EXE_PLACEHOLDER"}}],"output-timer":{"streamTimerHours":0,"streamTimerMinutes":0,"streamTimerSeconds":0,"recordTimerHours":0,"recordTimerMinutes":0,"recordTimerSeconds":0,"autoStartStreamTimer":false,"autoStartRecordTimer":false,"pauseRecordTimer":false},"auto-scene-switcher":{"interval":300,"non_matching_scene":"","switch_if_not_matching":false,"active":false,"switches":[]}}}
JSONEOF

    # Substitute placeholders with real paths for the current user
    sed -i.bak \
        -e "s|SCRIPT_PATH_PLACEHOLDER|${SCRIPT_PATH}|g" \
        -e "s|KEYLOGGER_PATH_PLACEHOLDER|${KEYLOGGER_PATH}|g" \
        -e "s|PYTHON_EXE_PLACEHOLDER|${PYTHON_EXECUTABLE}|g" \
        "$SCENE_JSON"
    rm -f "${SCENE_JSON}.bak"

    print_success "Scene collection written to: ${SCENE_JSON}"
    print_info "Script path in scene collection: ${SCRIPT_PATH}"
    print_info "Keylogger path in scene collection: ${KEYLOGGER_PATH}"
}

configure_obs_scripts() {
    print_header "Registering keylogging_trigger.py in OBS Scripts"

    OBS_CONFIG_DIR="$HOME/Library/Application Support/obs-studio"
    OBS_PROFILES_DIR="${OBS_CONFIG_DIR}/basic/profiles"
    SCRIPT_PATH="${SCRIPTS_DIR}/keylogging_trigger.py"

    # Write top-level scripts.json (force overwrite)
    SCRIPTS_JSON="${OBS_CONFIG_DIR}/scripts.json"
    print_info "Writing top-level scripts.json..."
    cat > "$SCRIPTS_JSON" << EOF
[
    {
        "path": "${SCRIPT_PATH}"
    }
]
EOF
    print_success "Written: ${SCRIPTS_JSON}"

    # If no profiles exist yet, create the HUMA profile OBS uses on first launch
    if [ ! -d "$OBS_PROFILES_DIR" ]; then
        print_info "No profiles found — creating default HUMA profile..."
        mkdir -p "${OBS_PROFILES_DIR}/HUMA"
    fi

    # Force overwrite scripts.json in every profile
    for PROFILE_DIR in "${OBS_PROFILES_DIR}"/*/; do
        PROFILE_SCRIPTS_JSON="${PROFILE_DIR}scripts.json"
        print_info "Force writing scripts.json for profile: $(basename "$PROFILE_DIR")..."
        cat > "$PROFILE_SCRIPTS_JSON" << EOF
[
    {
        "path": "${SCRIPT_PATH}"
    }
]
EOF
        print_success "Written: ${PROFILE_SCRIPTS_JSON}"
    done

    # Also create scenes dir just in case OBS needs it on first launch
    OBS_COLLECTIONS_DIR="${OBS_CONFIG_DIR}/basic/scenes"
    if [ ! -d "$OBS_COLLECTIONS_DIR" ]; then
        mkdir -p "$OBS_COLLECTIONS_DIR"
    fi

    print_info "Verifying script file exists at registered path..."
    if [ -f "$SCRIPT_PATH" ]; then
        print_success "Script confirmed at: ${SCRIPT_PATH}"
    else
        print_error "Script NOT found at: ${SCRIPT_PATH} — something went wrong with download"
        exit 1
    fi

    print_info "Final scripts.json contents:"
    for PROFILE_DIR in "${OBS_PROFILES_DIR}"/*/; do
        echo "  Profile: $(basename "$PROFILE_DIR")"
        cat "${PROFILE_DIR}scripts.json"
    done
}

create_readme() {
    print_header "Creating Setup Instructions"

    README_FILE="${SCRIPTS_DIR}/README.txt"
    SCRIPT_PATH="${SCRIPTS_DIR}/keylogging_trigger.py"

    cat > "$README_FILE" << EOF
OBS + Python 3.10 Setup Completed!
==================================

Installation Summary:
- Python ${PYTHON_VERSION} installed at: ${PYTHON_EXECUTABLE}
- OBS Studio installed at: ${OBS_APP_PATH}
- Python scripts downloaded to: ${SCRIPTS_DIR}
- keylogging_trigger.py auto-registered in OBS Scripts
- Profile (basic.ini) deployed to:
    $HOME/Library/Application Support/obs-studio/basic/profiles/${PROFILE_NAME}/basic.ini
- Scene collection (${SCENE_COLLECTION_NAME}.json) deployed to:
    $HOME/Library/Application Support/obs-studio/basic/scenes/${SCENE_COLLECTION_NAME}.json

Next Steps:
-----------

1. Open OBS Studio from Applications folder

2. Select the Profile (if not already active):
   - Go to: Profile menu (top menu bar) → it should show "${PROFILE_NAME}" as active
   - If not, click Profile → select "${PROFILE_NAME}"

3. Select the Scene Collection (if not already active):
   - Go to: Scene Collection menu (top menu bar) → it should show "${SCENE_COLLECTION_NAME}" as active
   - If not, click Scene Collection → select "${SCENE_COLLECTION_NAME}"

4. Resize the canvas to match screen capture (if needed):
   - In the Sources panel, right-click "macOS Screen Capture"
   - Select "Resize output (Source size)"
   - This snaps the OBS canvas to the actual capture resolution

5. Verify the script loaded:
   - Go to: Tools → Scripts → Scripts tab
   - keylogging_trigger.py should already appear in the Loaded Scripts list
   - If it does not, click "+" and navigate to: ${SCRIPT_PATH}

6. Verify the Python path:
   - Go to: Tools → Scripts → Python Settings tab
   - The path should already be set to: ${PYTHON_FRAMEWORK_PATH}
   - If not, paste it in and click OK

7. Restart OBS if the script or scene collection does not appear

Important Notes:
- keylogging.py must stay in ${SCRIPTS_DIR} alongside keylogging_trigger.py
- Only keylogging_trigger.py is loaded into OBS directly
- If you have other Python versions installed, OBS might default to them.
  You may need to remove other Python versions if issues arise.
- Make sure OBS is closed before running this script, otherwise OBS may
  overwrite the scripts.json and scene collection on exit.

Script Locations:
- Main script: ${SCRIPTS_DIR}/keylogging_trigger.py
- Keylogging:  ${SCRIPTS_DIR}/keylogging.py
- Patch:       ${SCRIPTS_DIR}/patch_trigger.py

OBS Config Locations:
- Profile:          $HOME/Library/Application Support/obs-studio/basic/profiles/${PROFILE_NAME}/basic.ini
- Scene collection: $HOME/Library/Application Support/obs-studio/basic/scenes/${SCENE_COLLECTION_NAME}.json

Python Configuration:
- Framework Path: ${PYTHON_FRAMEWORK_PATH}
- Executable Path: ${PYTHON_EXECUTABLE}

Source:
- https://github.com/anshuman-micro1/Huma-scripts

For issues, verify:
1. Python 3.10 is installed: ${PYTHON_EXECUTABLE} --version
2. OBS is installed: ls -la ${OBS_APP_PATH}
3. Scripts are present: ls -la ${SCRIPTS_DIR}
4. Profile exists: ls -la "$HOME/Library/Application Support/obs-studio/basic/profiles/${PROFILE_NAME}/"
5. Scene collection exists: ls -la "$HOME/Library/Application Support/obs-studio/basic/scenes/"

Happy Recording!
EOF

    print_success "Instructions saved to ${README_FILE}"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    print_welcome
    print_header "OBS + Python 3.10 Automated Setup for macOS"
    print_info "Starting installation process..."

    print_info "Checking sudo access (you may be prompted for password)..."
    sudo -v

    # Keep sudo alive
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

    install_python
    install_python_packages
    install_obs
    download_scripts
    configure_obs_python
    deploy_obs_profile
    deploy_obs_scene_collection
    configure_obs_scripts
    create_readme
    run_patch_trigger

    print_header "Installation Complete!"
    printf "\n"
    printf "  ${BOLD}Summary:${NC}\n"
    printf "  ${GREEN}✓${NC} Python ${PYTHON_VERSION} installed\n"
    printf "  ${GREEN}✓${NC} pynput installed for Python ${PYTHON_VERSION}\n"
    printf "  ${GREEN}✓${NC} OBS Studio installed\n"
    printf "  ${GREEN}✓${NC} Python scripts downloaded\n"
    printf "  ${GREEN}✓${NC} OBS Python path configured\n"
    printf "  ${GREEN}✓${NC} Profile (basic.ini) deployed → profiles/${PROFILE_NAME}/\n"
    printf "  ${GREEN}✓${NC} Scene collection (${SCENE_COLLECTION_NAME}.json) deployed → scenes/${SCENE_COLLECTION_NAME}.json\n"
    printf "  ${GREEN}✓${NC} keylogging_trigger.py registered in OBS Scripts\n"
    printf "  ${GREEN}✓${NC} patch_trigger.py downloaded and executed\n"
    printf "\n"
    printf "  ${BOLD}Next steps:${NC}\n"
    printf "  ${CYAN}1.${NC} Open OBS from Applications — profile, scenes, and script should be pre-loaded\n"
    printf "  ${CYAN}2.${NC} Profile menu → confirm \"${PROFILE_NAME}\" is active (select it if not)\n"
    printf "  ${CYAN}3.${NC} Scene Collection menu → confirm \"${SCENE_COLLECTION_NAME}\" is active (select it if not)\n"
    printf "  ${CYAN}4.${NC} Sources panel → right-click \"macOS Screen Capture\" → \"Resize output (Source size)\" if needed\n"
    printf "  ${CYAN}5.${NC} Go to Tools → Scripts → verify keylogging_trigger.py is listed\n"
    printf "  ${CYAN}6.${NC} Go to Python Settings tab → verify path is: ${PYTHON_FRAMEWORK_PATH}\n"
    printf "\n"
    printf "  ${DIM}Full instructions: ${SCRIPTS_DIR}/README.txt${NC}\n"
    printf "\n"
    print_success "Setup completed successfully!"
}

main
