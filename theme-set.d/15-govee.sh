#!/bin/bash

python3 -c "import bleak" 2>/dev/null || { skipped "Govee BLE"; exit 0; }

govee_env="$HOME/.config/govee/env"
[ -f "$govee_env" ] && source "$govee_env"

if [ -z "$GOVEE_DEVICE_MAC" ] && [ -z "$GOVEE_DEVICE_NAME" ]; then
    skipped "Govee BLE"
    exit 0
fi

python3 << PYEOF
import asyncio, os, sys, re
from bleak import BleakScanner, BleakClient

CHAR_UUID = "00010203-0405-0607-0809-0a0b0c0d2b11"
COLOR_NAMES = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]
ACCENT_WEIGHTS = {"green": 1.5, "cyan": 1.4, "magenta": 1.3, "red": 1.2, "blue": 1.1, "yellow": 1.0, "black": 0, "white": 0.5}

def make_packet(data):
    frame = bytearray(data)
    frame.extend([0] * (19 - len(frame)))
    checksum = 0
    for b in frame:
        checksum ^= b
    frame.append(checksum)
    return bytes(frame)

def hex2rgb(h):
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)

def chroma(r, g, b):
    return max(r, g, b) - min(r, g, b)

def read_ansi_colors(theme_dir):
    colors = {}
    ct = os.path.join(theme_dir, "colors.toml")
    if os.path.exists(ct):
        with open(ct) as f:
            for line in f:
                m = re.match(r'^\s*color(\d)\s*=\s*"#([0-9a-fA-F]{6})"', line)
                if m:
                    idx = int(m.group(1))
                    if 0 <= idx < 8:
                        colors[COLOR_NAMES[idx]] = hex2rgb(m.group(2))
    if colors:
        return colors
    al = os.path.join(theme_dir, "alacritty.toml")
    if os.path.exists(al):
        with open(al) as f:
            text = f.read()
        m = re.search(r'\[colors\.normal\](.*?)(?=\[|\Z)', text, re.DOTALL)
        if m:
            for name in COLOR_NAMES:
                m2 = re.search(r'\b' + re.escape(name) + r'\s*=\s*"#([0-9a-fA-F]{6})"', m.group(1))
                if m2:
                    colors[name] = hex2rgb(m2.group(1))
    return colors

def find_best_accent():
    theme_dir = os.path.expanduser("~/.config/omarchy/current/theme")
    ct = os.path.join(theme_dir, "colors.toml")
    if os.path.exists(ct):
        with open(ct) as f:
            for line in f:
                m = re.search(r'^\s*accent\s*=\s*"#([0-9a-fA-F]{6})"', line)
                if m:
                    r, g, b = hex2rgb(m.group(1))
                    if chroma(r, g, b) >= 30:
                        return (r, g, b)
    wy = os.path.join(theme_dir, "warp.yaml")
    if os.path.exists(wy):
        with open(wy) as f:
            for line in f:
                m = re.search(r'accent:\s*"#([0-9a-fA-F]{6})"', line)
                if m:
                    r, g, b = hex2rgb(m.group(1))
                    if chroma(r, g, b) >= 30:
                        return (r, g, b)
    ansi = read_ansi_colors(theme_dir)
    if ansi:
        best = max(
            ((r, g, b) for name, (r, g, b) in ansi.items()
             if chroma(r, g, b) >= 30),
            key=lambda rgb: chroma(*rgb) * ACCENT_WEIGHTS.get(
                next(n for n, c in ansi.items() if c == rgb), 1.0),
            default=None
        )
        if best:
            return best
    return 168, 130, 255

async def main():
    mac = os.environ.get("GOVEE_DEVICE_MAC", "")
    name = os.environ.get("GOVEE_DEVICE_NAME", "")
    r, g, b = find_best_accent()
    brightness = int(os.environ.get("GOVEE_BRIGHTNESS", 255))

    for attempt in range(5):
        try:
            device = None
            if mac:
                device = await BleakScanner.find_device_by_address(mac, timeout=8)
            if not device and name:
                device = await BleakScanner.find_device_by_name(name, timeout=8)
            if not device:
                await asyncio.sleep(1)
                continue

            async with BleakClient(device, timeout=15) as client:
                await client.write_gatt_char(CHAR_UUID, make_packet([0x33, 0x01, 0x01]))
                await asyncio.sleep(0.1)
                await client.write_gatt_char(CHAR_UUID, make_packet([0x33, 0x05, 0x02, r, g, b]))
                await asyncio.sleep(0.1)
                await client.write_gatt_char(CHAR_UUID, make_packet([0x33, 0x04, brightness]))
        except Exception:
            if attempt < 4:
                await asyncio.sleep(1.5 * (attempt + 1))
            continue

        sys.exit(0)

    sys.exit(1)

asyncio.run(main())
PYEOF

if [ $? -eq 0 ]; then
    success "Govee light updated!"
else
    warning "Govee light update failed (device offline?)"
fi
exit 0
