#!/bin/bash

# Omarchy → Pi theme sync hook
# Generates ~/.pi/agent/themes/omarchy.json from omarchy colors.toml
# so that Pi's TUI always matches your current omarchy theme.

if ! command -v pi >/dev/null 2>&1; then
    skipped "Pi"
fi

INPUT_FILE="$HOME/.config/omarchy/current/theme/colors.toml"
OUTPUT_FILE="$HOME/.pi/agent/themes/omarchy.json"

# Extract a color value from colors.toml (flat key=value format, returns hex without #)
extract_color() {
    local color_name="$1"
    if [[ ! -f "$INPUT_FILE" ]]; then
        return 0
    fi
    awk -v color="$color_name" '
        $1 == color && /=/ {
            if (match($0, /#([0-9a-fA-F]{6})/)) {
                print substr($0, RSTART + 1, 6)
                exit
            }
        }
    ' "$INPUT_FILE"
}

# Lighten a hex color by a given amount (0-255)
lighten() {
    local hex="${1#\#}"
    local amount="${2:-40}"
    local r=$((16#${hex:0:2} + amount))
    local g=$((16#${hex:2:2} + amount))
    local b=$((16#${hex:4:2} + amount))
    r=$((r > 255 ? 255 : r))
    g=$((g > 255 ? 255 : g))
    b=$((b > 255 ? 255 : b))
    printf "%02x%02x%02x" $r $g $b
}

# Read omarchy colors
accent=$(extract_color "accent")
primary_foreground="${primary_foreground}"
primary_background="${primary_background}"
cursor_color="${cursor_color}"
selection_foreground="${selection_foreground}"
selection_background="${selection_background}"
normal_black="${normal_black}"
normal_red="${normal_red}"
normal_green="${normal_green}"
normal_yellow="${normal_yellow}"
normal_blue="${normal_blue}"
normal_magenta="${normal_magenta}"
normal_cyan="${normal_cyan}"
normal_white="${normal_white}"
bright_black="${bright_black}"
bright_red="${bright_red}"
bright_green="${bright_green}"
bright_yellow="${bright_yellow}"
bright_blue="${bright_blue}"
bright_magenta="${bright_magenta}"
bright_cyan="${bright_cyan}"
bright_white="${bright_white}"

# Validate: if accent is empty, fall back to cursor_color
if [[ -z "$accent" ]]; then
    accent="${cursor_color}"
fi

# Derive export (HTML) backgrounds by lightening the primary background
export_page_bg=$(lighten "${primary_background:-000000}" 12)
export_card_bg=$(lighten "${primary_background:-000000}" 20)
export_info_bg=$(lighten "${primary_background:-000000}" 60)

mkdir -p "$HOME/.pi/agent/themes"

cat > "$OUTPUT_FILE" << EOF
{
  "\$schema": "https://raw.githubusercontent.com/badlogic/pi-mono/main/packages/coding-agent/src/modes/interactive/theme/theme-schema.json",
  "name": "omarchy",
  "vars": {
    "accent": "#${accent}",
    "foreground": "#${primary_foreground}",
    "background": "#${primary_background}",
    "cursor": "#${cursor_color}",
    "selection_fg": "#${selection_foreground}",
    "selection_bg": "#${selection_background}",
    "normal_black": "#${normal_black}",
    "normal_red": "#${normal_red}",
    "normal_green": "#${normal_green}",
    "normal_yellow": "#${normal_yellow}",
    "normal_blue": "#${normal_blue}",
    "normal_magenta": "#${normal_magenta}",
    "normal_cyan": "#${normal_cyan}",
    "normal_white": "#${normal_white}",
    "bright_black": "#${bright_black}",
    "bright_red": "#${bright_red}",
    "bright_green": "#${bright_green}",
    "bright_yellow": "#${bright_yellow}",
    "bright_blue": "#${bright_blue}",
    "bright_magenta": "#${bright_magenta}",
    "bright_cyan": "#${bright_cyan}",
    "bright_white": "#${bright_white}"
  },
  "colors": {
    "accent": "accent",
    "border": "normal_blue",
    "borderAccent": "normal_cyan",
    "borderMuted": "bright_black",
    "success": "normal_green",
    "error": "normal_red",
    "warning": "normal_yellow",
    "muted": "normal_white",
    "dim": "bright_black",
    "text": "",
    "thinkingText": "bright_black",

    "selectedBg": "background",
    "userMessageBg": "background",
    "userMessageText": "",
    "customMessageBg": "background",
    "customMessageText": "",
    "customMessageLabel": "normal_magenta",
    "toolPendingBg": "normal_black",
    "toolSuccessBg": "background",
    "toolErrorBg": "background",
    "toolTitle": "",
    "toolOutput": "normal_white",

    "mdHeading": "bright_yellow",
    "mdLink": "normal_blue",
    "mdLinkUrl": "bright_black",
    "mdCode": "normal_cyan",
    "mdCodeBlock": "normal_green",
    "mdCodeBlockBorder": "bright_black",
    "mdQuote": "bright_black",
    "mdQuoteBorder": "bright_black",
    "mdHr": "bright_black",
    "mdListBullet": "normal_blue",

    "toolDiffAdded": "bright_green",
    "toolDiffRemoved": "bright_red",
    "toolDiffContext": "bright_black",

    "syntaxComment": "bright_cyan",
    "syntaxKeyword": "normal_blue",
    "syntaxFunction": "bright_yellow",
    "syntaxVariable": "bright_blue",
    "syntaxString": "bright_magenta",
    "syntaxNumber": "normal_magenta",
    "syntaxType": "normal_cyan",
    "syntaxOperator": "normal_white",
    "syntaxPunctuation": "normal_white",

    "thinkingOff": "bright_black",
    "thinkingMinimal": "bright_black",
    "thinkingLow": "normal_blue",
    "thinkingMedium": "normal_magenta",
    "thinkingHigh": "bright_magenta",
    "thinkingXhigh": "bright_red",

    "bashMode": "normal_green"
  },
  "export": {
    "pageBg": "#${export_page_bg}",
    "cardBg": "#${export_card_bg}",
    "infoBg": "#${export_info_bg}"
  }
}
EOF

success "Pi theme synced from omarchy!"
exit 0
