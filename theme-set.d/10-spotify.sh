#!/bin/bash

# Resolve the alacritty background colour from the current omarchy theme.
# Reads directly from alacritty.toml so this works even when colors.toml is absent.
resolve_alacritty_bg() {
    local toml="$HOME/.config/omarchy/current/theme/alacritty.toml"
    if [[ ! -f "$toml" ]]; then
        toml="$HOME/.config/alacritty/alacritty.toml"
    fi
    if [[ ! -f "$toml" ]]; then
        echo ""
        return
    fi
    # Extract: background = "#RRGGBB"
    awk '/^\[colors\.primary\]/{in_section=1} in_section && /^background/{
        if (match($0, /#([0-9a-fA-F]{6})/, m)) { print m[1]; exit }
    }' "$toml"
}

create_dynamic_theme() {
    local THEME_DIR="$HOME/.config/spicetify/Themes/blackout-main"
    mkdir -p "$THEME_DIR"

    # Resolve background; fall back to primary_background exported by theme-set if set
    local bg
    bg=$(resolve_alacritty_bg)
    if [[ -z "$bg" && -n "${primary_background:-}" ]]; then
        bg="${primary_background#\#}"
    fi

    # Validate: must be 6 hex chars
    bg="${bg,,}"
    if [[ ! "$bg" =~ ^[0-9a-f]{6}$ ]]; then
        warning "Spotify: could not resolve background color. Skipping color.ini update."
        return
    fi

    # These are the original blackout-main colours. Only values that are pure black
    # (000000) or near-black (00010A) get replaced with the theme background.
    # All other colours are kept as-is.
    local BG="$bg"
    cat > "$THEME_DIR/color.ini" << EOF
[base]
text               = FFFFFF
subtext            = F1F1F1
main               = $BG
sidebar            = $BG
player             = $BG
card               = $BG
shadow             = $BG
selected-row       = F1F1F1
button             = 545955
button-active      = F1F1F1
button-disabled    = 434C5E
tab-active         = $BG
notification       = $BG
notification-error = $BG
misc               = $BG
EOF

    # Ensure spicetify uses this theme
    spicetify config current_theme "blackout-main" > /dev/null 2>&1 || true
    spicetify config color_scheme base > /dev/null 2>&1 || true
}

if ! command -v spicetify >/dev/null 2>&1; then
    skipped "Spicetify"
fi

create_dynamic_theme

spotify_was_running=false
if pgrep -x "spotify" > /dev/null 2>&1; then
    spotify_was_running=true
fi

if [ "$spotify_was_running" = true ]; then
    spicetify apply > /dev/null 2>&1 &
else
    setsid bash -c '
        spicetify apply > /dev/null 2>&1 &

        for i in {1..250}; do
            if pgrep -x "spotify" > /dev/null 2>&1; then
                sleep 0.2
                killall -9 spotify > /dev/null 2>&1
                exit 0
            fi
            sleep 0.1
        done
    ' > /dev/null 2>&1 < /dev/null &
fi

success "Spotify theme updated!"
exit 0
