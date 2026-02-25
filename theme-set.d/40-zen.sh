#!/bin/bash

output_file="$HOME/.config/omarchy/current/theme/zen.css"

if ! command -v zen-browser >/dev/null 2>&1; then
    skipped "Zen Browser"
fi

find_default_profile() {
    local ini=""
    local ini_dir=""
    if [[ -f "$HOME/.config/zen/profiles.ini" ]]; then
        ini="$HOME/.config/zen/profiles.ini"
    elif [[ -f "$HOME/.zen/profiles.ini" ]]; then
        ini="$HOME/.zen/profiles.ini"
    else
        return 1
    fi
    ini_dir="$(dirname "$ini")"
    # prefer profile with Default=1, otherwise use first Profile Path
    awk -F= -v ini_dir="$ini_dir" '
    BEGIN { profile_count=0; printed=0 }
    /^\[Profile/ { profile_count++; path[profile_count]=""; isrel[profile_count]=1 }
    /^Path=/ { path[profile_count]=$2 }
    /^IsRelative=/ { isrel[profile_count]=$2 }
    /^Default=/ { if ($2==1) { out = (isrel[profile_count]==1 ? ini_dir "/" path[profile_count] : path[profile_count]); print out; printed=1; exit } }
    END { if (printed==0 && profile_count>0) { out = (isrel[1]==1 ? ini_dir "/" path[1] : path[1]); print out } }
    ' "$ini"
}
default_profile="$(find_default_profile)"
if [[ -z "$default_profile" ]]; then
    echo "No zen profile found" >&2
    exit 1
fi

resolve_background_hex() {
    local alacritty_file="$HOME/.config/omarchy/current/theme/alacritty.toml"
    local colors_file="$HOME/.config/omarchy/current/theme/colors.toml"
    local bg=""

    if [[ -f "$alacritty_file" ]]; then
        bg="$(awk '
            /^\[colors\.primary\]/ { in_primary=1; next }
            /^\[/ { in_primary=0 }
            in_primary && match($0, /background[[:space:]]*=[[:space:]]*"#([0-9a-fA-F]{6})"/, m) { print m[1]; exit }
        ' "$alacritty_file")"
    fi

    if [[ -z "$bg" && -f "$colors_file" ]]; then
        bg="$(awk '
            match($0, /^background[[:space:]]*=[[:space:]]*"#([0-9a-fA-F]{6})"/, m) { print m[1]; exit }
        ' "$colors_file")"
    fi

    if [[ -z "$bg" ]]; then
        bg="${primary_background#\#}"
    fi

    if [[ "$bg" =~ ^[0-9a-fA-F]{6}$ ]]; then
        echo "$bg"
        return 0
    fi
    return 1
}

background_hex="$(resolve_background_hex)"
if [[ -z "$background_hex" ]]; then
    echo "Unable to resolve valid background color for Zen transparency" >&2
    exit 1
fi
transparency_value="#${background_hex}99"

# Update only mod.sameerasw.zen_transparency_color to match background with 60% opacity
set_zen_transparency() {
    local pref_name='mod.sameerasw.zen_transparency_color'
    local pref_file=""
    for pref_file in "$default_profile/user.js" "$default_profile/prefs.js"; do
        mkdir -p "$(dirname "$pref_file")"
        if [[ -f "$pref_file" ]]; then
            if grep -q "user_pref(\"$pref_name\"" "$pref_file"; then
                sed -i.bak "s|user_pref(\\\"$pref_name\\\".*);|user_pref(\\\"$pref_name\\\", \\\"$transparency_value\\\");|g" "$pref_file"
            else
                echo "user_pref(\"$pref_name\", \"$transparency_value\");" >> "$pref_file"
            fi
        else
            echo "user_pref(\"$pref_name\", \"$transparency_value\");" > "$pref_file"
        fi
    done
}

# Update zen-themes chrome.css variable to match theme background with 60% opacity
update_zen_chrome_css() {
    local themes_dir="$default_profile/chrome/zen-themes"
    if [[ -d "$themes_dir" ]]; then
        for css in "$themes_dir"/*/chrome.css; do
            [[ -f "$css" ]] || continue
            cp -n "$css" "$css.bak_$(date -u +%Y%m%dT%H%M%SZ)" || true
            if grep -q -- '--mod-sameerasw-zen_transparency_color' "$css"; then
                sed -E -i "s|(--mod-sameerasw-zen_transparency_color:[[:space:]]*)[^;]+;|\\1$transparency_value;|g" "$css"
            else
                awk -v val="$transparency_value" 'BEGIN{ins=0} /:root[[:space:]]*{/ && ins==0 {print; print "  --mod-sameerasw-zen_transparency_color: " val ";"; ins=1; next} {print}' "$css" > "$css.tmp" && mv "$css.tmp" "$css"
            fi
        done
    fi
}

find_marionette_port() {
    local port="${ZEN_MARIONETTE_PORT:-}"
    local pref_file=""
    if [[ "$port" =~ ^[0-9]+$ ]]; then
        echo "$port"
        return 0
    fi
    for pref_file in "$default_profile/user.js" "$default_profile/prefs.js"; do
        [[ -f "$pref_file" ]] || continue
        port="$(sed -nE 's/.*user_pref\\(\"marionette\\.port\",[[:space:]]*([0-9]+)\\);/\\1/p' "$pref_file" | tail -n1)"
        if [[ "$port" =~ ^[0-9]+$ ]]; then
            echo "$port"
            return 0
        fi
    done
    echo "2828"
}

zen_running() {
    pgrep -x "zen-browser" > /dev/null || pgrep -x "zen" > /dev/null
}

find_python_bin() {
    command -v python3 >/dev/null 2>&1 && { echo "python3"; return 0; }
    command -v python >/dev/null 2>&1 && { echo "python"; return 0; }
    return 1
}

apply_live_marionette() {
    local port
    local py
    port="$(find_marionette_port)"
    py="$(find_python_bin)" || return 1
    "$py" - "$port" "$transparency_value" <<'PY'
import json
import socket
import sys

port = int(sys.argv[1])
value = sys.argv[2]

def recv_message(sock):
    buffer = b""
    while b":" not in buffer:
        chunk = sock.recv(1)
        if not chunk:
            raise RuntimeError("Marionette closed before handshake")
        buffer += chunk
    length_part, remainder = buffer.split(b":", 1)
    length = int(length_part)
    payload = remainder
    while len(payload) < length:
        chunk = sock.recv(length - len(payload))
        if not chunk:
            raise RuntimeError("Marionette closed before full message")
        payload += chunk
    return json.loads(payload.decode("utf-8"))

def send_command(sock, msg_id, command, params):
    body = json.dumps([0, msg_id, command, params], separators=(",", ":"))
    sock.sendall(f"{len(body)}:{body}".encode("utf-8"))
    response = recv_message(sock)
    if not isinstance(response, list) or len(response) < 4:
        raise RuntimeError(f"Unexpected response for {command}: {response!r}")
    if response[1] != msg_id:
        raise RuntimeError(f"Unexpected response id for {command}: {response[1]!r}")
    if response[2] is not None:
        message = response[2].get("message", response[2])
        raise RuntimeError(f"{command} failed: {message}")
    return response[3]

try:
    sock = socket.create_connection(("127.0.0.1", port), timeout=2)
    sock.settimeout(5)
    recv_message(sock)
    send_command(sock, 1, "WebDriver:NewSession", {"capabilities": {"alwaysMatch": {}, "firstMatch": [{}]}})
    send_command(sock, 2, "Marionette:SetContext", {"value": "chrome"})
    result = send_command(
        sock,
        3,
        "WebDriver:ExecuteScript",
        {
            "script": "const value = arguments[0]; Services.prefs.setStringPref(\"mod.sameerasw.zen_transparency_color\", value); const windows = []; const e = Services.wm.getEnumerator(\"navigator:browser\"); while (e.hasMoreElements()) { const win = e.getNext(); const root = win.document.documentElement; root.style.setProperty(\"--mod-sameerasw-zen_transparency_color\", value, \"important\"); root.style.setProperty(\"--zen-main-browser-background\", value, \"important\"); windows.push(root.style.getPropertyValue(\"--mod-sameerasw-zen_transparency_color\")); } return { pref: Services.prefs.getStringPref(\"mod.sameerasw.zen_transparency_color\", \"\"), windows };",
            "args": [value],
        },
    )
    written = None
    if isinstance(result, dict):
        written = result.get("pref") or result.get("value")
    if written != value:
        raise RuntimeError(f"Marionette wrote unexpected value: {written!r}")
    if isinstance(result, dict):
        for window_value in result.get("windows", []):
            if window_value and window_value.strip() != value:
                raise RuntimeError(f"Marionette window value mismatch: {window_value!r}")
    try:
        send_command(sock, 4, "WebDriver:DeleteSession", {})
    except Exception:
        pass
    sock.close()
except Exception as exc:
    print(str(exc), file=sys.stderr)
    sys.exit(1)
PY
}

set_zen_transparency
update_zen_chrome_css

if zen_running; then
    if apply_live_marionette; then
        success "Zen Browser transparency updated live via Marionette!"
        exit 0
    fi
    require_restart "zen-browser"
    warning "Zen is running but Marionette live update failed. Start Zen with --marionette -remote-allow-system-access to update without restart."
fi

success "Zen Browser transparency updated!"
exit 0

enable_userchrome() {
    local prefs_file="$default_profile/prefs.js"
    local pref_name="toolkit.legacyUserProfileCustomizations.stylesheets"
    if grep -q "user_pref(\"$pref_name\"" "$prefs_file"; then
        if grep -q "user_pref(\"$pref_name\", false)" "$prefs_file"; then
            sed -i.bak "s/user_pref(\"$pref_name\", false);/user_pref(\"$pref_name\", true);/" "$prefs_file"
        fi
    else
        echo "user_pref(\"$pref_name\", true);" >> "$prefs_file"
    fi
}
enable_userchrome

mkdir -p "$default_profile/chrome"

cat > "$output_file" << EOF
:root {
--color00: #${primary_background};
--color01: #${primary_background};
--color02: #${primary_background};
--zen-transparency-color: #${primary_background}99;
--color03: #${normal_white};
--color04: #${bright_white};
--color05: #${primary_foreground};
--color06: #${bright_white};
--color07: #${bright_white};
--color08: #${normal_red};
--color09: #${normal_yellow};
--color0A: #${bright_yellow};
--color0B: #${normal_green};
--color0C: #${normal_cyan};
--color0D: #${normal_blue};
--color0E: #${normal_magenta};
--color0F: #${bright_red};
}
EOF
cp "$output_file" "$default_profile/chrome/colors.css"

if [[ ! -f "$default_profile/chrome/userChrome.css" ]]; then
cat > "$default_profile/chrome/userChrome.css" << EOF
@import url("./colors.css");

:root {
    --base00: var(--color00);
    --base01: color-mix(in srgb, var(--color00) 98%, white);
    --base02: color-mix(in srgb, var(--color00) 94%, white);
    --base03: var(--color03);
    --base04: var(--color04);
    --base05: var(--color05);
    --base06: var(--color06);
    --base07: var(--color07);
    --base08: var(--color08);
    --base09: var(--color09);
    --base0A: var(--color0A);
    --base0B: var(--color0B);
    --base0C: var(--color0C);
    --base0D: var(--color0D);
    --base0E: var(--color0E);
    --base0F: var(--color0F);
}

:root {
    --panel-separator-zap-gradient: linear-gradient(
        90deg,
        var(--base0E) 0%,
        var(--base0F) 52.08%,
        var(--base0A) 100%
    ) !important;
    --toolbarbutton-border-radius: 6px !important;
    --toolbarbutton-icon-fill: var(--base04) !important;
    --urlbarView-separator-color: var(--base01) !important;
    --urlbar-box-bgcolor: var(--base01) !important;
}

/* Tabs colors  */
#tabbrowser-tabs:not([movingtab])
    > #tabbrowser-arrowscrollbox
    > .tabbrowser-tab
    > .tab-stack
    > .tab-background[multiselected="true"],
#tabbrowser-tabs:not([movingtab])
    > #tabbrowser-arrowscrollbox
    > .tabbrowser-tab
    > .tab-stack
    > .tab-background[selected="true"] {
    background-image: none !important;
    background-color: var(--toolbar-bgcolor) !important;
}

/* Inactive tabs color */
#navigator-toolbox {
    background-color: var(--base00) !important;
}

/* Window colors  */
:root {
    --toolbar-bgcolor: var(--base01) !important;
    --tabs-border-color: var(--base01) !important;
    --lwt-sidebar-background-color: var(--base00) !important;
    --lwt-toolbar-field-focus: var(--base01) !important;
}

/* Sidebar color  */
#sidebar-box,
.sidebar-placesTree {
    background-color: var(--base00) !important;
}

.tab-background {
    border-radius: 6px !important;
    border: 0px solid rgba(0, 0, 0, 0) !important;
}
.tab-background[selected] {
    background-color: var(--base02) !important;
}

#tabbrowser-tabs {
    margin-left: 1px;
    margin-top: 3px;
    margin-bottom: 3px;
}

.tabbrowser-tab[last-visible-tab="true"] {
    border: 0px solid rgba(0, 0, 0, 0) !important;
}

toolbarbutton {
    border-radius: 6px !important;
}

/* Url Bar  */
#urlbar-input {
    accent-color: var(--base0D) !important;
}
#urlbar-input-container {
    background-color: var(--base01) !important;
    border: 0px solid rgba(0, 0, 0, 0) !important;
}

#urlbar[focused="true"] > #urlbar-background {
    box-shadow: none !important;
}

#urlbar-background {
    border-radius: 6px !important;
}

#navigator-toolbox {
    border: none !important;
}

.urlbarView-url {
    color: var(--base05) !important;
}

#star-button {
    --toolbarbutton-icon-fill-attention: var(--base0D) !important;
}

#vertical-tabs.customization-target {
    background-color: var(--base00) !important;
}
splitter#sidebar-tools-and-extensions-splitter {
    display: none !important;
}
.tools-and-extensions[aria-orientation="vertical"] {
    background-color: var(--base00) !important;
}
.tools-and-extensions.actions-list {
    background-color: var(--base00) !important;
}
#identity-box,
#trust-icon-container,
#tracking-protection-icon-container {
    fill: var(--base04) !important;
}

.logo-and-wordmark {
    display: none !important;
}
.search-inner-wrapper {
    margin-top: 10% !important;
}

.urlbar-input::placeholder,
.searchbar-textbox::placeholder {
    opacity: 1;
    color: var(--base03) !important;
}

.urlbar-input {
    color: var(--base05) !important;
}

:root {
    --arrowpanel-background: var(--base01) !important;
    --arrowpanel-border-color: var(--base00) !important;
    --color-accent-primary-active: var(--base0D) !important;
    --color-accent-primary-hover: var(--base0D) !important;
    --color-accent-primary: var(--base0D) !important;
    --focus-outline-color: var(--base00) !important;
    --icon-color-critical: var(--base08) !important;
    --icon-color-information: var(--base0D) !important;
    --icon-color-success: var(--base0B) !important;
    --icon-color-warning: var(--base0A) !important;
    --outline-color-error: var(--base08) !important;
    --tab-block-margin: 0 !important;
    --tab-border-radius: 0 !important;
    --text-color-error: var(--base08) !important;
    --toolbar-field-border-color: var(--base00) !important;
    --toolbar-field-focus-background-color: var(--base02) !important;
    --toolbar-field-focus-border-color: var(--base00) !important;
    --toolbarbutton-border-radius: 6px !important;
    --in-content-page-background: var(--base01) !important;
    --input-text-background-color: var(--base02) !important;
    --zen-main-browser-background: var(--base00) !important;
}
EOF
fi

if [[ ! -f "$default_profile/chrome/userContent.css" ]]; then
cat > "$default_profile/chrome/userContent.css" <<EOF
@import url("./colors.css");

:root {
    --base00: var(--color00);
    --base01: color-mix(in srgb, var(--color00) 98%, white);
    --base02: color-mix(in srgb, var(--color00) 94%, white);
    --base03: var(--color03);
    --base04: var(--color04);
    --base05: var(--color05);
    --base06: var(--color06);
    --base07: var(--color07);
    --base08: var(--color08);
    --base09: var(--color09);
    --base0A: var(--color0A);
    --base0B: var(--color0B);
    --base0C: var(--color0C);
    --base0D: var(--color0D);
    --base0E: var(--color0E);
    --base0F: var(--color0F);
}

:root {
    --color-accent-primary-active: var(--base0D) !important;
    --color-accent-primary-hover: var(--base0D) !important;
    --color-accent-primary: var(--base0D) !important;
    --focus-outline-color: var(--base00) !important;
    --icon-color-critical: var(--base08) !important;
    --icon-color-information: var(--base0D) !important;
    --icon-color-success: var(--base0B) !important;
    --icon-color-warning: var(--base0A) !important;
    --in-content-page-background: var(--base00) !important;
    --input-text-background-color: var(--base02) !important;
    --newtab-background-color-secondary: var(--base02) !important;
    --newtab-background-color: var(--base01) !important;
    --newtab-text-primary-color: var(--base05) !important;
    --newtab-text-secondary-text: var(--base04) !important;
    --newtab-wallpaper-color: var(--base01) !important;
    --outline-color-error: var(--base08) !important;
    --tab-block-margin: 0 !important;
    --tab-border-radius: 0 !important;
    --text-color-error: var(--base08) !important;
    --toolbar-field-border-color: var(--base00) !important;
    --toolbar-field-border-color: var(--base01) !important;
    --toolbar-field-focus-background-color: var(--base02) !important;
    --toolbar-field-focus-border-color: var(--base01) !important;
    --toolbarbutton-border-radius: 6px !important;
    --zen-main-browser-background: var(--base00) !important;
}

body {
    border: none;
}

.logo-and-wordmark {
    display: none !important;
}
.search-inner-wrapper {
    margin-top: 10% !important;
}
EOF
fi

if pgrep -x "zen-browser" > /dev/null; then
    pkill -x "zen-browser" > /dev/null
    sleep 2
    if pgrep -x "zen-browser" > /dev/null; then
        pkill -9 -x "zen-browser" > /dev/null
        sleep 1
    fi
    zen-browser > /dev/null &
fi

require_restart "zen-browser"
success "Zen Browser theme updated!"
exit 0
