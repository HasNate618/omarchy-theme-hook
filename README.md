
<div align="center">

![Preview](assets/preview.png)

# Omarchy Theme Hook
   
[![Themed Apps](https://img.shields.io/badge/themed_apps-17-blue?style=for-the-badge&labelColor=0C0D11&color=A5CAB8)](https://github.com/imbypass/omarchy-theme-hook/tree/main/theme-set.d)
[![GitHub Issues](https://img.shields.io/github/issues/imbypass/omarchy-theme-hook?style=for-the-badge&labelColor=0C0D11&color=EB7A73)](https://github.com/imbypass/omarchy-theme-hook/issues)
[![GitHub Last Commit](https://img.shields.io/github/last-commit/imbypass/omarchy-theme-hook?style=for-the-badge&labelColor=0C0D11&color=8ECD84)](https://github.com/imbypass/omarchy-theme-hook/commits/main/)
[![GitHub Stars](https://img.shields.io/github/stars/imbypass/omarchy-theme-hook?style=for-the-badge&labelColor=0C0D11&color=EFBE71)](https://github.com/imbypass/omarchy-theme-hook/stargazers)

**A lightweight, clean solution to extending your Omarchy theme to other apps.**

</div>

## Overview
The Omarchy Theme Hook is a lightweight, clean solution to extending your Omarchy theme to other apps. It will check your Omarchy theme for the existence of any extended theme files and will install them automatically for you when a theme is applied. If a theme is applied that contains extended theme files, they will be copied to their proper folders. If the theme does *not* contain any extended theme files, a new set of each will be generated dynamically using the theme's Alacritty config and copied to their proper folders.

## Installing
You can install the theme hook by running the following command:
```
curl -fsSL https://imbypass.github.io/omarchy-theme-hook/install.sh | bash
```

## Updating
You can update the theme hook by running the following command, or by re-running the installation script:
```
thctl update
```

## Theme Hook Controller (`thctl`)
The Theme Hook Controller (`thctl`) is a command-line tool that allows you to manage your Theme Hook installation. It provides a simple interface for updating the hook as well as toggling hooklettes on and off.
You can access it via the terminal by running `thctl`.

## Themed Apps
- Cava
- Cursor
- Discord
- Firefox
- GTK (requires `adw-gtk-theme` from the AUR)
- Pi (TUI theme sync)
- QT6
- Spotify
- Steam
- Superfile
- Vicinae
- VS Code
- Govee (BLE smart lights)
- Waybar
- Windsurf
- Zed
- Zen Browser (experimental - requires manual enabling of legacy userchrome styling)

## Uninstalling
You can remove the theme hook by running the following command:
```
curl -fsSL https://imbypass.github.io/omarchy-theme-hook/uninstall.sh | bash
```

## FAQ

#### I installed the hook, but none of my apps are theming!
1. The theme hook will generate and install themes, but cannot apply all of them.
2. You may need to manually set the theme to "Omarchy" one time for each app that supports theming.

#### My Firefox/Zen Browser isn't theming!
-  Firefox and Zen Browser may require manual enabling of legacy userchrome styling.
-  To do this, open the browser, go to `about:config`, search for `toolkit.legacyUserProfileCustomizations.stylesheets`, and set it to `true`.
-  Zen live transparency updates (without restart) require launching Zen with Marionette system access:
   `zen-browser --marionette -remote-allow-system-access`

#### My Discord isn't theming!
1. Make sure you are using a third-party Discord client, like Vesktop or Equibop.
2. Apply your desired theme in Omarchy.
3. Enable the Omarchy theme in Discord.

#### My Spotify isn't theming!
1. Make sure that you *properly* installed Spicetify, including any permission edits that may need to be made for Linux systems.
2. See a [[note for Linux users]](https://spicetify.app/docs/advanced-usage/installation#note-for-linux-users).
3. Apply your desired theme in Omarchy.

#### My Spotify stopped theming!
A Spotify client update may have caused Spicetify to stop working. You can fix this either by running `spicetify restore backup apply` or by reinstalling Spotify and Spicetify, and running `spicetify backup apply`.

#### I get a "colors.toml not found" error!
Omarchy 3.3+ requires themes to include `colors.toml`. Update your theme to a version compatible with Omarchy 3.3+, or add a valid `colors.toml` file to the theme directory.

#### My Govee light isn't updating!
1. The hook uses BLE directly via `bleak`. Install it with `pip install bleak`.
2. Create `~/.config/govee/env` with your device info:
   ```
   GOVEE_DEVICE_MAC=AA:BB:CC:DD:EE:FF
   GOVEE_DEVICE_NAME=ihoment_H6181_xxxx
   GOVEE_BRIGHTNESS=255
   ```
   Only `GOVEE_DEVICE_MAC` or `GOVEE_DEVICE_NAME` is required; brightness defaults to max.
3. BLE on Linux can be flaky — the hook retries 5 times with backoff.

#### My Pi TUI isn't matching my omarchy theme!
- Pi uses its own theme system (`~/.pi/agent/themes/`). The hook generates `omarchy.json` from your omarchy `colors.toml` every time you switch themes.
- If Pi doesn't pick up the new theme, select it via `/settings` in Pi or set `"theme": "omarchy"` in `~/.pi/agent/settings.json`.

#### What if I encounter issues?
If you encounter any issues, please open an issue on the GitHub repository.

#### What theme is shown in the showcase?
Everpuccin.
https://github.com/imbypass/omarchy-everpuccin-theme

#### Will you share your waybar configuration?
It's on GitHub.
https://github.com/imbypass/omarchy-waybar-bepi

## Contributing
I actively encourage everyone to contribute a theme for their favorite application. If you have a theme for an application, an upgrade to an existing script, or even just feature ideas, please open a pull or a feature request on the GitHub repository. I try my best to review and merge them quickly. As a general rule of thumb, try to keep any templates submitted limited to a single script file.
