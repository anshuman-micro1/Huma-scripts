#!/bin/bash

################################################################################
# OBS + Python 3 Setup Script for Linux (Debian/Ubuntu)
# This script automates the installation of Python 3, OBS Studio, and
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

KEYLOGGING_TRIGGER_URL="https://raw.githubusercontent.com/anshuman-micro1/Huma-scripts/main/keylogging_trigger.py"
KEYLOGGING_URL="https://raw.githubusercontent.com/anshuman-micro1/Huma-scripts/main/keylogging.py"
PATCH_TRIGGER_URL="https://raw.githubusercontent.com/anshuman-micro1/Huma-scripts/main/patch_trigger.py"

PYTHON_EXECUTABLE="/usr/bin/python3"
OBS_CONFIG_DIR="$HOME/.config/obs-studio"
SCRIPTS_DIR="$HOME/Documents/OBS_Scripts"

# Profile and scene collection names (must match the filenames)
PROFILE_NAME="HUMA"
SCENE_COLLECTION_NAME="HUMA"

# =============================================================================
# COMMAND LINE ARGUMENTS (Override defaults)
# =============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
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
            echo "Usage: $0 [--script-url URL] [--keylogging-url URL] [--patch-trigger-url URL]"
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
    printf "  ${DIM}OBS Studio Automated Setup for Linux${NC}\n"
    printf "\n"
    printf "  ${DIM}This installer will set up:${NC}\n"
    printf "  ${GREEN}  ●${NC} Python 3\n"
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

install_dependencies() {
    print_header "Installing Dependencies"

    if ! check_command apt-get; then
        print_info "apt-get not found. This script is optimized for Debian/Ubuntu."
        print_info "Please ensure Python 3, pip, and OBS Studio are installed manually."
        return 0
    fi

    print_info "Updating package lists..."
    sudo apt-get update -y || true

    print_info "Installing Python 3 and pip..."
    sudo apt-get install -y python3 python3-pip python3-venv x11-utils curl

    if ! check_command obs; then
        print_info "Adding OBS Studio PPA and installing..."
        sudo add-apt-repository -y ppa:obsproject/obs-studio || true
        sudo apt-get update -y || true
        sudo apt-get install -y obs-studio
    else
        print_info "OBS Studio is already installed."
    fi

    print_success "Dependencies installed successfully."
}

install_python_packages() {
    print_header "Installing Required Python Packages"

    print_info "Installing pynput..."
    
    # On newer Linux distros, pip might complain about externally managed environments.
    # We attempt to use --break-system-packages or just standard user install.
    if ! python3 -m pip install pynput --user --break-system-packages 2>/dev/null; then
        python3 -m pip install pynput --user --quiet || {
            print_error "Failed to install pynput via pip."
            print_info "Please install python3-pynput via your package manager if available, e.g.: sudo apt-get install python3-pynput"
        }
    fi

    if python3 -c "import pynput" 2>/dev/null; then
        print_success "pynput installed successfully"
    else
        print_error "pynput is not available. Keylogging may fail."
    fi
}

request_accessibility_permission() {
    print_header "Wayland/X11 Keyboard Monitoring"
    
    if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
        printf "\n"
        printf "  ${YELLOW}Warning: You are running Wayland.${NC}\n"
        printf "  pynput may not be able to globally monitor keystrokes on Wayland.\n"
        printf "  If keylogging fails, consider logging into an X11 session (e.g., 'Ubuntu on Xorg').\n"
        printf "\n"
    else
        print_info "X11 session detected. Keystroke monitoring should work."
    fi
}

download_scripts() {
    print_header "Downloading Python Scripts"

    mkdir -p "$SCRIPTS_DIR"

    print_info "Downloading keylogging_trigger.py..."
    curl -L -f --progress-bar -o "${SCRIPTS_DIR}/keylogging_trigger.py" "$KEYLOGGING_TRIGGER_URL" || {
        print_error "Failed to download keylogging_trigger.py"
        exit 1
    }
    print_success "keylogging_trigger.py downloaded"

    print_info "Downloading keylogging.py..."
    curl -L -f --progress-bar -o "${SCRIPTS_DIR}/keylogging.py" "$KEYLOGGING_URL" || {
        print_error "Failed to download keylogging.py"
        exit 1
    }
    print_success "keylogging.py downloaded"

    print_info "Downloading patch_trigger.py..."
    curl -L -f --progress-bar -o "${SCRIPTS_DIR}/patch_trigger.py" "$PATCH_TRIGGER_URL" || {
        print_error "Failed to download patch_trigger.py"
        exit 1
    }
    print_success "patch_trigger.py downloaded"
}

run_patch_trigger() {
    print_header "Running patch_trigger.py"

    PATCH_TRIGGER_PATH="${SCRIPTS_DIR}/patch_trigger.py"
    if [ -f "$PATCH_TRIGGER_PATH" ]; then
        print_info "Executing patch_trigger.py..."
        "$PYTHON_EXECUTABLE" "$PATCH_TRIGGER_PATH" || true
        print_success "patch_trigger.py executed"
    fi
}

configure_obs_python() {
    print_header "Configuring OBS Python Settings"

    GLOBAL_INI="${OBS_CONFIG_DIR}/global.ini"
    mkdir -p "$OBS_CONFIG_DIR"

    print_info "Setting Python path in OBS configuration..."

    if [ ! -f "$GLOBAL_INI" ]; then
        cat > "$GLOBAL_INI" << EOF
[General]
FirstRun=false

[Python]
Path64bit=/usr
EOF
    else
        if grep -q "\[Python\]" "$GLOBAL_INI"; then
            sed -i.bak "/\[Python\]/,/^\[/ s|^Path64bit=.*|Path64bit=/usr|" "$GLOBAL_INI"
        else
            echo "" >> "$GLOBAL_INI"
            echo "[Python]" >> "$GLOBAL_INI"
            echo "Path64bit=/usr" >> "$GLOBAL_INI"
        fi
    fi

    print_success "OBS Python path configured (/usr)"
}

deploy_obs_profile() {
    print_header "Deploying OBS Profile (basic.ini)"

    OBS_PROFILE_DIR="${OBS_CONFIG_DIR}/basic/profiles/${PROFILE_NAME}"
    mkdir -p "$OBS_PROFILE_DIR"

    PROFILE_INI="${OBS_PROFILE_DIR}/basic.ini"
    VIDEOS_PATH=$(xdg-user-dir VIDEOS 2>/dev/null || echo "$HOME/Videos")

    print_info "Writing profile to: ${PROFILE_INI}"

    printf '%s\n' \
        '[Output]' \
        'Mode=Simple' \
        '' \
        '[SimpleOutput]' \
        "FilePath=${VIDEOS_PATH}" \
        'RecFormat2=mkv' \
        'VBitrate=2500' \
        'ABitrate=160' \
        'Preset=veryfast' \
        'RecQuality=Stream' \
        'RecEncoder=x264' \
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

    print_success "Profile written to: ${PROFILE_INI}"
    print_info "Recording save path set to: ${VIDEOS_PATH}"
}

deploy_obs_scene_collection() {
    print_header "Deploying OBS Scene Collection (${SCENE_COLLECTION_NAME}.json)"

    OBS_SCENES_DIR="${OBS_CONFIG_DIR}/basic/scenes"
    mkdir -p "$OBS_SCENES_DIR"

    SCENE_JSON="${OBS_SCENES_DIR}/${SCENE_COLLECTION_NAME}.json"
    SCRIPT_PATH="${SCRIPTS_DIR}/keylogging_trigger.py"
    KEYLOGGER_PATH="${SCRIPTS_DIR}/keylogging.py"

    print_info "Writing scene collection to: ${SCENE_JSON}"

    cat > "$SCENE_JSON" << 'JSONEOF'
{"DesktopAudioDevice1":{"prev_ver":503447554,"name":"__unnamed0000","uuid":"58cc23b8-efcc-4035-84ea-89bec2c8fd18","id":"","versioned_id":"","settings":{},"mixers":63,"sync":0,"flags":0,"volume":1.0,"balance":0.5,"enabled":true,"muted":false,"push-to-mute":false,"push-to-mute-delay":0,"push-to-talk":false,"push-to-talk-delay":0,"hotkeys":{},"deinterlace_mode":0,"deinterlace_field_order":0,"monitoring_type":0,"private_settings":{}},"current_scene":"Scene","current_program_scene":"Scene","scene_order":[{"name":"Scene"}],"name":"HUMA","sources":[{"prev_ver":503447554,"name":"Scene","uuid":"e7611cc3-a513-4a5c-ba7c-1bf43add1ffe","id":"scene","versioned_id":"scene","settings":{"items":[{"name":"Linux Audio Capture","source_uuid":"97bcb000-b352-4314-8e3d-3cf4b23719d2","visible":true,"locked":false,"rot":0.0,"pos":{"x":0.0,"y":0.0},"scale":{"x":1.0,"y":1.0},"align":5,"bounds_type":0,"bounds_align":0,"bounds_crop":false,"bounds":{"x":0.0,"y":0.0},"crop_left":0,"crop_top":0,"crop_right":0,"crop_bottom":0,"id":1,"group_item_backup":false,"scale_filter":"disable","blend_method":"default","blend_type":"normal","show_transition":{"duration":0},"hide_transition":{"duration":0},"private_settings":{}},{"name":"SYNC_FLASH","source_uuid":"209c5bff-0eed-4957-b603-6b4050d857f2","visible":true,"locked":true,"rot":0.0,"pos":{"x":0.0,"y":0.0},"scale":{"x":1.0,"y":1.0},"align":5,"bounds_type":0,"bounds_align":0,"bounds_crop":false,"bounds":{"x":0.0,"y":0.0},"crop_left":0,"crop_top":0,"crop_right":0,"crop_bottom":0,"id":2,"group_item_backup":false,"scale_filter":"disable","blend_method":"default","blend_type":"normal","show_transition":{"duration":0},"hide_transition":{"duration":0},"private_settings":{}},{"name":"Linux Screen Capture","source_uuid":"6cc342d4-8b80-49d6-b520-3b23bfadead2","visible":true,"locked":false,"rot":0.0,"pos":{"x":0.0,"y":0.0},"scale":{"x":1.0,"y":1.0},"align":5,"bounds_type":2,"bounds_align":0,"bounds_crop":false,"bounds":{"x":1920.0,"y":1080.0},"crop_left":0,"crop_top":0,"crop_right":0,"crop_bottom":0,"id":3,"group_item_backup":false,"scale_filter":"disable","blend_method":"default","blend_type":"normal","show_transition":{"duration":0},"hide_transition":{"duration":0},"private_settings":{}}],"id_counter":3,"custom_size":false},"mixers":0,"sync":0,"flags":0,"volume":1.0,"balance":0.5,"enabled":true,"muted":false,"push-to-mute":false,"push-to-mute-delay":0,"push-to-talk":false,"push-to-talk-delay":0,"hotkeys":{},"deinterlace_mode":0,"deinterlace_field_order":0,"monitoring_type":0,"private_settings":{}},{"prev_ver":503447554,"name":"SYNC_FLASH","uuid":"209c5bff-0eed-4957-b603-6b4050d857f2","id":"color_source","versioned_id":"color_source_v3","settings":{"color":4294967295},"mixers":0,"sync":0,"flags":0,"volume":1.0,"balance":0.5,"enabled":true,"muted":false,"push-to-mute":false,"push-to-mute-delay":0,"push-to-talk":false,"push-to-talk-delay":0,"hotkeys":{},"deinterlace_mode":0,"deinterlace_field_order":0,"monitoring_type":0,"private_settings":{}},{"prev_ver":503447554,"name":"Linux Screen Capture","uuid":"6cc342d4-8b80-49d6-b520-3b23bfadead2","id":"xshm_input","versioned_id":"xshm_input","settings":{"screen":0},"mixers":255,"sync":0,"flags":0,"volume":1.0,"balance":0.5,"enabled":true,"muted":false,"push-to-mute":false,"push-to-mute-delay":0,"push-to-talk":false,"push-to-talk-delay":0,"hotkeys":{},"deinterlace_mode":0,"deinterlace_field_order":0,"monitoring_type":0,"private_settings":{}},{"prev_ver":503447554,"name":"Linux Audio Capture","uuid":"97bcb000-b352-4314-8e3d-3cf4b23719d2","id":"pulse_output_capture","versioned_id":"pulse_output_capture","settings":{},"mixers":255,"sync":0,"flags":0,"volume":1.0,"balance":0.5,"enabled":true,"muted":false,"push-to-mute":false,"push-to-mute-delay":0,"push-to-talk":false,"push-to-talk-delay":0,"hotkeys":{},"deinterlace_mode":0,"deinterlace_field_order":0,"monitoring_type":0,"private_settings":{}}],"groups":[],"quick_transitions":[],"transitions":[],"saved_projectors":[],"current_transition":"Fade","transition_duration":300,"preview_locked":false,"scaling_enabled":false,"scaling_level":0,"scaling_off_x":0.0,"scaling_off_y":0.0,"virtual-camera":{"type2":3},"modules":{"scripts-tool":[{"path":"SCRIPT_PATH_PLACEHOLDER","settings":{"keylogger_script":"KEYLOGGER_PATH_PLACEHOLDER","python_exe":"PYTHON_EXE_PLACEHOLDER"}}]}}
JSONEOF

    sed -i.bak \
        -e "s|SCRIPT_PATH_PLACEHOLDER|${SCRIPT_PATH}|g" \
        -e "s|KEYLOGGER_PATH_PLACEHOLDER|${KEYLOGGER_PATH}|g" \
        -e "s|PYTHON_EXE_PLACEHOLDER|${PYTHON_EXECUTABLE}|g" \
        "$SCENE_JSON"
    rm -f "${SCENE_JSON}.bak"

    print_success "Scene collection written to: ${SCENE_JSON}"
}

configure_obs_scripts() {
    print_header "Registering scripts in OBS"

    OBS_PROFILES_DIR="${OBS_CONFIG_DIR}/basic/profiles"
    SCRIPT_PATH="${SCRIPTS_DIR}/keylogging_trigger.py"

    SCRIPTS_JSON="${OBS_CONFIG_DIR}/scripts.json"
    cat > "$SCRIPTS_JSON" << EOF
[
    {
        "path": "${SCRIPT_PATH}"
    }
]
EOF

    if [ ! -d "$OBS_PROFILES_DIR" ]; then
        mkdir -p "${OBS_PROFILES_DIR}/HUMA"
    fi

    for PROFILE_DIR in "${OBS_PROFILES_DIR}"/*/; do
        if [ -d "$PROFILE_DIR" ]; then
            PROFILE_SCRIPTS_JSON="${PROFILE_DIR}scripts.json"
            cat > "$PROFILE_SCRIPTS_JSON" << EOF
[
    {
        "path": "${SCRIPT_PATH}"
    }
]
EOF
        fi
    done

    print_success "Scripts registered in OBS configuration."
}

create_readme() {
    print_header "Creating Setup Instructions"

    README_FILE="${SCRIPTS_DIR}/README_Linux.txt"

    cat > "$README_FILE" << EOF
OBS + Python Setup Completed (Linux)
====================================

Installation Summary:
- Python and dependencies installed
- Python scripts downloaded to: ${SCRIPTS_DIR}
- Profile deployed to: ${OBS_CONFIG_DIR}/basic/profiles/${PROFILE_NAME}/basic.ini
- Scene collection deployed to: ${OBS_CONFIG_DIR}/basic/scenes/${SCENE_COLLECTION_NAME}.json

Next Steps:
-----------
1. Open OBS Studio
2. Select the Profile: Profile -> "${PROFILE_NAME}"
3. Select the Scene Collection: Scene Collection -> "${SCENE_COLLECTION_NAME}"
4. Verify the script loaded: Tools -> Scripts -> Scripts tab
   - keylogging_trigger.py should be listed.
5. If using Wayland, global hotkey capture might not work. Switch to X11 if needed.

Happy Recording!
EOF

    print_success "Instructions saved to ${README_FILE}"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    print_welcome
    print_info "Starting installation process..."
    
    print_info "Checking sudo access (you may be prompted for password)..."
    sudo -v || true

    install_dependencies
    install_python_packages
    request_accessibility_permission
    download_scripts
    configure_obs_python
    deploy_obs_profile
    deploy_obs_scene_collection
    configure_obs_scripts
    create_readme
    run_patch_trigger

    print_header "Installation Complete!"
    printf "  ${GREEN}✓${NC} Setup finished successfully.\n"
    printf "  ${DIM}Full instructions: ${SCRIPTS_DIR}/README_Linux.txt${NC}\n\n"
}

main
