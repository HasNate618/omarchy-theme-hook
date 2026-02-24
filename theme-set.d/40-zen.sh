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
    BEGIN { profile_count=0 }
    /^\[Profile/ { profile_count++; path[profile_count]=""; isrel[profile_count]=1 }
    /^Path=/ { path[profile_count]=$2 }
    /^IsRelative=/ { isrel[profile_count]=$2 }
    /^Default=/ { if ($2==1) { print (isrel[profile_count]==1 ? ini_dir "/" path[profile_count] : path[profile_count]); exit } }
    END { if (profile_count>0) { print (isrel[1]==1 ? ini_dir "/" path[1] : path[1]) } }
    ' "$ini"
}
default_profile="$(find_default_profile)"
if [[ -z "$default_profile" ]]; then
    echo "No zen profile found" >&2
    exit 1
fi

echo $default_profile

# Update only mod.sameerasw.zen_transparency_color to match background with 60% opacity
set_zen_transparency() {
    local prefs_file="$default_profile/prefs.js"
    local pref_name='mod.sameerasw.zen_transparency_color'
    local bg="${primary_background#\#}"
    local alpha_hex="99"  # 60% opacity
    local value="#${bg}${alpha_hex}"
    mkdir -p "$(dirname "$prefs_file")"
    if [[ -f "$prefs_file" ]]; then
        if grep -q "user_pref(\"$pref_name\"" "$prefs_file"; then
            # replace any existing user_pref line for this pref with the new value
            sed -i.bak "s|user_pref(\\\"$pref_name\\\".*);|user_pref(\\\"$pref_name\\\", \\\"$value\\\");|g" "$prefs_file"
        else
            echo "user_pref(\"$pref_name\", \"$value\");" >> "$prefs_file"
        fi
    else
        echo "user_pref(\"$pref_name\", \"$value\");" > "$prefs_file"
    fi
}
set_zen_transparency

# Update zen-themes chrome.css variable to match theme background with 60% opacity
update_zen_chrome_css() {
    local themes_dir="$default_profile/chrome/zen-themes"
    local bg="${primary_background#\#}"
    local alpha_hex="99"
    local value="#${bg}${alpha_hex}"
    if [[ -d "$themes_dir" ]]; then
        for css in "$themes_dir"/*/chrome.css; do
            [[ -f "$css" ]] || continue
            cp -n "$css" "$css.bak_$(date -u +%Y%m%dT%H%M%SZ)" || true
            if grep -q -- '--mod.sameerasw-zen_transparency_color' "$css"; then
                sed -E -i "s|(--mod.sameerasw-zen_transparency_color:[[:space:]]*)[^;]+;|\\1$value;|g" "$css"
            else
                awk -v val="$value" 'BEGIN{ins=0} /:root[[:space:]]*{/ && ins==0 {print; print "  --mod-sameerasw-zen_transparency_color: " val ";"; ins=1; next} {print}' "$css" > "$css.tmp" && mv "$css.tmp" "$css"
            fi
        done
    fi
}

update_zen_chrome_css

# Restart zen-browser to apply change and exit
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
