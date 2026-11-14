# HDR Control (`caioniehues.hdr`)

Fork of [vedix95/omarchy-hdr-plug](https://github.com/vedix95/omarchy-hdr-plug) by vedix95.

Omarchy bar plugin to control HDR, color profiles and color temperature under Hyprland.

## Features

- **Bar indicator** (`󰃠` / `󰃞`) with a dynamic tooltip; right-click toggles HDR on/off.
- **Control panel** (`Panel.qml`):
  - Detects the monitor, its EDID HDR capabilities (max luminance in nits), and supports multiple monitors (`Dropdown`).
  - HDR on/off switch and hardware rescan button (`󰑐`).
  - Color temperature slider (3000–9000 K) driven by `hyprsunset`, debounced.
  - HDR modes: `Vivid HDR`, `Cinema HDR`, `Outdoor`, `Optimal EDID`.
  - SDR modes: `Cinema (P3)`, `Design (sRGB)`.
  - Color space selector (HDR / DCI-P3 / sRGB) and sliders for target SDR luminance, SDR brightness boost and SDR saturation.
  - **Reset** button with a confirmation dialog to restore the native display settings.
- **XDG persistence**: per-monitor state (keyed by monitor description) in `~/.local/state/caioniehues.hdr/state.json`; generated Hyprland config in `~/.config/hypr/hdr.lua`.

## Who owns which monitor settings

The plugin writes **color keys only** (`cm`, `sdrbrightness`, `sdrsaturation`, `sdr_min_luminance`, `sdr_max_luminance`, `min_luminance`, `max_luminance`, `max_avg_luminance`), always with `output = "desc:<monitor description>"`.
Hyprland merges a rule into an earlier one with the *identical* output string, so keep `mode`, `position`, `scale`, `vrr` and `bitdepth` in `~/.config/hypr/monitors.lua` and give that rule the same `desc:` selector. `hdr.lua` is loaded right after `monitors.lua`, so its color keys win.

Remove any `cm`, `sdr_*_luminance` keys from your own `monitors.lua` rule: the plugin owns them now.

The panel UI is English by default; `i18n/fr.json` provides a French locale.

## Dependencies

- `hyprctl` / Hyprland
- `jq`
- `edid-decode` (reads EDID capabilities)
- `hyprsunset` (color temperature)
- `notify-send` (optional notifications)

## Install & uninstall

```bash
./install.sh
```

To remove the plugin completely and restore the system as if it had never been installed:

```bash
./install.sh --uninstall
```

## CLI

- `bin/omarchy-hdr-status [connector|description]`: prints the full JSON state (monitors, EDID, current settings).
- `bin/omarchy-hdr-set [--monitor <connector|description>] <action> [param...]`:
  - `toggle`, `on`, `off`
  - `temperature <3000..9000>`
  - `preset vivid|cinema_hdr|cinema|outdoor|eco|optimal`
  - `sdr_brightness <val>`, `sdr_saturation <val>`, `sdr_max_lum <nits>`
  - `cm <preset>`
  - `apply <brightness> <saturation> <max_luminance> <cm>`
  - `reset` (resets `hyprsunset`, deletes `hdr.lua` and `state.json`, reloads Hyprland)

## Tests

```bash
bats tests/
```
