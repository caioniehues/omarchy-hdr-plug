# HDR Control (`caioniehues.hdr`)

Fork of [vedix95/omarchy-hdr-plug](https://github.com/vedix95/omarchy-hdr-plug) by vedix95.

Omarchy bar plugin to control HDR, color profiles and color temperature under Hyprland.

## Features

- **Bar indicator** (`󰃠` / `󰃞`) with a dynamic tooltip; right-click toggles HDR on/off.
- **Control panel** (`Panel.qml`):
  - Detects the monitor, its EDID HDR capabilities (max luminance in nits), and supports multiple monitors (`Dropdown`).
  - HDR on/off switch and hardware rescan button (`󰑐`).
  - Color temperature slider (3000–9000 K) driven by `hyprsunset`, debounced.
  - Presets tuned for OLED, derived from the EDID (SDR white = frame-average luminance rounded to 10 nits, 250 on the Odyssey G95SC):

    | Preset | HDR | SDR white | SDR boost | Saturation |
    |---|---|---|---|---|
    | `HDR Desktop` (default) | on | frame-average | 1.0 | 1.0 |
    | `HDR Bright` | on | frame-average | 1.2 | 1.0 |
    | `HDR Cinema` | on | 200 nits | 1.0 | 1.0 |
    | `SDR` | off (sRGB) | – | – | – |

    White stays at the frame-average so full-screen white doesn't trigger the panel's brightness limiter (ABL). Highlights use the EDID peak.
  - Color space selector (HDR / DCI-P3 / sRGB) and sliders for target SDR luminance, SDR brightness boost and SDR saturation.
  - SDR transfer curve: `Gamma 2.2` (default; matches how the panel shows SDR, keeps shadows dark) or `sRGB` piecewise.
  - Variable refresh rate: `Off`, `On`, or `Fullscreen only` (default; avoids OLED brightness flicker on the desktop). Presets leave it alone.
  - HDR peak override (250–1500 nits) for panels whose real peak differs from the EDID; `EDID` restores the EDID value. It feeds Hyprland's `max_luminance`.
  - **Reset** button with a confirmation dialog to restore the native display settings.
- **XDG persistence**: per-monitor state (keyed by monitor description) in `~/.local/state/caioniehues.hdr/state.json`; generated Hyprland config in `~/.config/hypr/hdr.lua`.

## Who owns which monitor settings

The plugin writes **color and VRR keys only** (`cm`, `sdrbrightness`, `sdrsaturation`, `sdr_min_luminance`, `sdr_max_luminance`, `min_luminance`, `max_luminance`, `max_avg_luminance`, `sdr_eotf`, `vrr`), always with `output = "desc:<monitor description>"`.
Hyprland merges a rule into an earlier one with the *identical* output string, so keep `mode`, `position`, `scale` and `bitdepth` in `~/.config/hypr/monitors.lua` and give that rule the same `desc:` selector. `hdr.lua` is loaded right after `monitors.lua`, so its keys win.

Remove any `cm`, `sdr_*_luminance`, `vrr` keys and a global `render.cm_sdr_eotf` from your own `monitors.lua` (keep a copy, e.g. `monitors.lua.pre-plugin`): the plugin owns them now.

Hyprland's rule comparison ignores `vrr` and `sdr_eotf`, and applies them only on the next rule change. Actions that can change them therefore send the rule twice: once with SDR white nudged by 1 nit, then the real rule.

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
  - `preset desktop|bright|cinema|sdr`
  - `sdr_brightness <val>`, `sdr_saturation <val>`, `sdr_max_lum <nits>`
  - `cm <preset>`
  - `sdr_eotf gamma22|srgb`
  - `vrr 0|1|2` (off / on / fullscreen only)
  - `peak <nits>|edid` (clamped to 250..1500)
  - `apply <brightness> <saturation> <max_luminance> <cm>`
  - `reset` (resets `hyprsunset`, deletes `hdr.lua` and `state.json`, reloads Hyprland). Afterwards no rule sets the plugin-owned keys, so Hyprland defaults apply (HDR off, global VRR) until you restore them in `monitors.lua` or use the plugin again.

## Tests

```bash
bats tests/
```
