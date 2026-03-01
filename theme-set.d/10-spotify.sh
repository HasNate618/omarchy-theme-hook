#!/bin/bash

resolve_alacritty_bg() {
    local toml="$HOME/.config/omarchy/current/theme/alacritty.toml"
    if [[ ! -f "$toml" ]]; then
        toml="$HOME/.config/alacritty/alacritty.toml"
    fi
    if [[ ! -f "$toml" ]]; then
        echo ""
        return
    fi
    awk '/^\[colors\.primary\]/{in_section=1} in_section && /^background/ {
        if (match($0, /#([0-9a-fA-F]{6})/, m)) { print m[1]; exit }
    }' "$toml"
}

resolve_theme_background() {
    local candidate="${primary_background:-}"
    candidate="${candidate#\#}"
    candidate="${candidate,,}"
    if [[ "$candidate" =~ ^[0-9a-f]{6}$ ]]; then
        echo "$candidate"
        return
    fi
    candidate="$(resolve_alacritty_bg)"
    candidate="${candidate#\#}"
    candidate="${candidate,,}"
    if [[ "$candidate" =~ ^[0-9a-f]{6}$ ]]; then
        echo "$candidate"
        return
    fi
    echo ""
}

saturate_color() {
    local hex="$1"
    local delta="${2:-0.2}"
    if [[ -z "$hex" ]]; then
        echo ""
        return
    fi
    if command -v python3 >/dev/null 2>&1; then
        python3 - <<PY
import os, sys, colorsys
hexcolor = os.environ.get('HEX', '')
delta = float(os.environ.get('DELTA', '0.2'))
if len(hexcolor) != 6:
    sys.exit(1)
r = int(hexcolor[0:2], 16) / 255.0
g = int(hexcolor[2:4], 16) / 255.0
b = int(hexcolor[4:6], 16) / 255.0
h, l, s = colorsys.rgb_to_hls(r, g, b)
s = min(1.0, s + delta)
r2, g2, b2 = colorsys.hls_to_rgb(h, l, s)
print("{:02X}{:02X}{:02X}".format(int(round(r2 * 255)), int(round(g2 * 255)), int(round(b2 * 255))))
PY
    else
        echo "${hex^^}"
    fi
}

update_color_ini() {
    local theme_dir="$1"
    local color="$2"
    local ini="$theme_dir/color.ini"
    mkdir -p "$theme_dir"
    if [[ -f "$ini" ]]; then
        cp -a "$ini" "$ini.bak_$(date -u +%Y%m%d%H%M%SZ)"
    fi

    local keys=(main sidebar player card main-elevated shadow tab-active notification notification-error misc)

    if [[ -f "$ini" ]]; then
        local tmp
        tmp="$(mktemp)"
        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ "$line" =~ ^[[:space:]]*([A-Za-z0-9_.-]+)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
                local key="${BASH_REMATCH[1]}"
                local matched=false
                for k in "${keys[@]}"; do
                    if [[ "$k" == "$key" ]]; then
                        printf "%-20s = %s\n" "$key" "$color" >> "$tmp"
                        matched=true
                        break
                    fi
                done
                if [[ "$matched" == false ]]; then
                    echo "$line" >> "$tmp"
                fi
            else
                echo "$line" >> "$tmp"
            fi
        done < "$ini"
        mv "$tmp" "$ini"
    else
        cat > "$ini" <<EOF
[base]
text               = FFFFFF
subtext            = F1F1F1
main               = $color
sidebar            = $color
player             = $color
card               = $color
shadow             = $color
main-elevated      = $color
selected-row       = F1F1F1
button             = 545955
button-active      = F1F1F1
button-disabled    = 434C5E
tab-active         = $color
notification       = $color
notification-error = $color
misc               = $color
EOF
    fi
}

patch_user_css() {
    local theme_dir="$1"
    local css="$theme_dir/user.css"
    if [[ ! -f "$css" ]]; then
        return
    fi
    cp -a "$css" "$css.bak_$(date -u +%Y%m%d%H%M%SZ)"
    sed -E \
        -e 's/--background-base([[:space:]]*:[[:space:]]*)transparent([[:space:]]*!important;)/--background-base\1var(--spice-main) !important;/Ig' \
        -e 's/--background-base-min-contrast([[:space:]]*:[[:space:]]*)transparent([[:space:]]*!important;)/--background-base-min-contrast\1var(--spice-main) !important;/Ig' \
        -e 's/--background-base-70([[:space:]]*:[[:space:]]*)transparent([[:space:]]*!important;)/--background-base-70\1var(--spice-main) !important;/Ig' \
        -e 's/--color-from([[:space:]]*:[[:space:]]*)transparent([[:space:]]*!important;)/--color-from\1var(--spice-main) !important;/Ig' \
        -e 's/--color-to([[:space:]]*:[[:space:]]*)transparent([[:space:]]*!important;)/--color-to\1var(--spice-main) !important;/Ig' \
        "$css" > "$css.tmp" && mv "$css.tmp" "$css"
}

create_dynamic_theme() {
    local theme_dir="$HOME/.config/spicetify/Themes/blackout-main"
    if ! command -v spicetify >/dev/null 2>&1; then
        skipped "Spicetify"
    fi
    local bg
    bg="$(resolve_theme_background)"
    if [[ -z "$bg" ]]; then
        warning "Spotify: could not resolve background color. Skipping color.ini update."
        return
    fi
    local sat
    sat="$(saturate_color "$bg" "0.20")"
    if [[ -z "$sat" ]]; then
        sat="${bg^^}"
    fi

    update_color_ini "$theme_dir" "$sat"
    patch_user_css "$theme_dir"

    spicetify config current_theme "blackout-main" > /dev/null 2>&1 || true
    spicetify config color_scheme base > /dev/null 2>&1 || true
}

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
