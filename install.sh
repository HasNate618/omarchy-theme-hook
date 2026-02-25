#! /bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" >/dev/null 2>&1 && pwd)"
LOCAL_HOOK_PATH="${LOCAL_THEME_HOOK_PATH:-}"
if [[ -z "$LOCAL_HOOK_PATH" && -d "$SCRIPT_DIR/.git" ]]; then
    LOCAL_HOOK_PATH="$SCRIPT_DIR"
fi
TEMP_DIR="/tmp/theme-hook"
REMOTE_REPO="https://github.com/imbypass/omarchy-theme-hook.git"
HOOK_SOURCE=""
CLONED_REMOTE=false

if [[ -n "$LOCAL_HOOK_PATH" ]]; then
    if [[ ! -d "$LOCAL_HOOK_PATH" ]]; then
        echo "Local hook path \"$LOCAL_HOOK_PATH\" not found." >&2
        exit 1
    fi
    HOOK_SOURCE="$(cd "$LOCAL_HOOK_PATH" && pwd)"
else
    rm -rf "$TEMP_DIR"
    echo -e "Downloading theme hook.."
    git clone "$REMOTE_REPO" "$TEMP_DIR" > /dev/null 2>&1
    CLONED_REMOTE=true
    HOOK_SOURCE="$TEMP_DIR"
fi

# Install prerequisites
if ! pacman -Qi "adw-gtk-theme" &>/dev/null; then
    gum style --border normal --border-foreground 6 --padding "1 2" \
    "\"adw-gtk-theme\" is required to theme GTK applications."

    if gum confirm "Would you like to install \"adw-gtk-theme\"?"; then
        sudo pacman -S adw-gtk-theme
    fi
fi

# Remove any old update alias
rm -rf $HOME/.local/share/omarchy/bin/theme-hook-update > /dev/null 2>&1

# Create a theme control alias
cp -f "$HOOK_SOURCE/thctl" "$HOME/.local/share/omarchy/bin/thctl"
chmod +x $HOME/.local/share/omarchy/bin/thctl

# Copy theme-set hook to Omarchy hooks directory
cp -f "$HOOK_SOURCE/theme-set" "$HOME/.config/omarchy/hooks/"

# Create theme hook directory and copy scripts
mkdir -p $HOME/.config/omarchy/hooks/theme-set.d/
cp -a "$HOOK_SOURCE/theme-set.d/." "$HOME/.config/omarchy/hooks/theme-set.d/"

# Remove any new temp files
if [[ "$CLONED_REMOTE" == true ]]; then
    rm -rf "$TEMP_DIR"
fi

# Update permissions (excluding Spotify and Cava)
chmod +x $HOME/.config/omarchy/hooks/theme-set
chmod +x $HOME/.config/omarchy/hooks/theme-set.d/*
chmod -x $HOME/.config/omarchy/hooks/theme-set.d/10-spotify.sh
chmod -x $HOME/.config/omarchy/hooks/theme-set.d/40-cava.sh

# Update Omarchy theme
echo "Running theme hook.."
omarchy-hook theme-set

omarchy-show-done
