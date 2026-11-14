# Session handoff

Last updated 2026-11-14. Read this first when resuming work on this fork.

## Where things stand

- Spec: issue #1. Tickets #2–#9 are implemented, reviewed, committed and closed (one feature commit + one review-fix commit each, all naming the ticket).
- Open: **#10 External monitor brightness via ddcutil** (`ready-for-human`) and spec **#1** (stays open until #10 is done).
- Tests: `bats tests/` (36 tests, all green). bats-core is installed via pacman.
- The plugin is **installed and live** on the workstation (`~/.config/omarchy/plugins/caioniehues.hdr`, registered in `~/.config/omarchy/shell.json`, loaded by `pcall(require, "hypr.hdr")` right after `require("hypr.monitors")` in `~/.config/hypr/hyprland.lua`).
- Current live settings: preset `desktop` (HDR, SDR white 250, boost 1, saturation 1, gamma 2.2), VRR fullscreen-only, peak from EDID (400), 5120x1440@239.999 Hz.

## Hardware

Samsung Odyssey G95SC (QD-OLED), `desc:Samsung Electric Company Odyssey G95SC H1AK500000`, DP-2, 10-bit, on an AMD RX 7800 XT (amdgpu), Hyprland 0.56.2 (Lua config), hyprsunset 0.4.0. EDID: max 400 / frame-average 248 / min 0 nits. DDC/CI works on `/dev/i2c-9` (VCP 0x10 brightness accepted writes in HDR mode; whether the screen visibly dims is unverified).

## How the plugin works (decisions to keep)

- **Rule ownership.** The plugin emits one `hl.monitor` per saved monitor with `output = "desc:<description>"` and only these keys: `cm`, `sdrbrightness`, `sdrsaturation`, `sdr_min_luminance`, `sdr_max_luminance`, `min_luminance`, `max_luminance`, `max_avg_luminance`, `sdr_eotf`, `vrr`. Hyprland merges a rule into an earlier one with the **identical** output string (`DP-2` and `desc:…` do not merge), so `mode`/`position`/`scale`/`bitdepth` stay in `monitors.lua`. Never send `mode = "preferred"`: the EDID's preferred mode is 119.98 Hz.
- **One rule builder.** `RULE_JQ` in `bin/omarchy-hdr-set` builds both the live `hyprctl eval` and `~/.config/hypr/hdr.lua`. Defaults for fields missing in older state live there too (`sdr_eotf // "gamma22"`, `vrr // 2`, `peakOverride // edidMax`).
- **One-nit nudge.** Hyprland's rule compare ignores `vrr`/`sdr_eotf` and applies them only on the *next* rule change (verified live with vrr). Actions `sdr_eotf|vrr|peak|preset` first eval the rule with SDR white +1 nit, then the real rule. Sliders send one eval.
- **State** lives in `~/.local/state/caioniehues.hdr/state.json`, keyed by monitor description. `bin/omarchy-hdr-status [connector|description]` is the single reader (defaults, `presetSdrWhite`, `anyHdrEnabled`, `peakLuminance`); an unknown monitor is an error.
- **Input validation** before anything reaches Lua: numbers match a regex, `cm` is in Hyprland's preset list, `sdr_eotf` ∈ gamma22|srgb, `vrr` ∈ 0|1|2, peak clamped 250..1500; strings go through `tojson`.
- **Presets** (`desktop` default, `bright`, `cinema`, `sdr`): SDR white = EDID frame-average rounded to 10 nits; all use cm=hdr, gamma 2.2, 6500 K; `sdr` keeps cm=hdr in state and sends srgb only because HDR is off, so switching HDR back on lands on `desktop`. Presets never touch VRR or the peak override.
- **Color temperature** is SDR-only: hyprsunset's CTM is applied after PQ encoding and tints HDR (hyprwm/Hyprland discussion #15747). The plugin only talks to the hyprsunset Omarchy runs (`hyprctl hyprsunset temperature|identity`), never starts/kills it, refuses `temperature` while any monitor is in HDR, and resets hyprsunset to identity on every HDR-on action.

## Your config changes outside the repo

- `~/.config/hypr/monitors.lua`: removed `cm`, `sdr_*_luminance`, `vrr` and the global `render.cm_sdr_eotf`; the G9 rule keeps mode/position/scale/bitdepth. Original: `~/.config/hypr/monitors.lua.pre-plugin`.
- `./install.sh --uninstall` or the panel's Reset deletes `hdr.lua` and the state; afterwards nothing sets the plugin-owned keys (HDR off) until `monitors.lua.pre-plugin` is restored or the plugin is used again.

## Next steps

1. **#10 DDC brightness** (needs the user watching the screen): run `ddcutil --bus 9 setvcp 10 60` in HDR and ask whether it dims; then implement per the ticket (slider; disabled under HDR if it doesn't dim).
2. **Visual checks the user still owes** (no read-back exists): gamma 2.2 vs sRGB shadows; whether a peak override changes highlights; whether the two-step nudge flickers (if yes: replace the nudge with an "applies on next fullscreen" label, per #6/#7); no tint under HDR after identity.
3. Optional cleanups noted in reviews, not done: pre-existing `ReferenceError: resetConfirm is not defined` in `Panel.qml` `onOpenChanged` (upstream code); old connector-keyed / old-preset state is not migrated; `showAdvanced` is declared but unused; no shellcheck/qmllint coverage (shellcheck not installed, qmllint can't resolve Omarchy modules).

## Workflow conventions used

- Per ticket: red bats test → implement → live check on the G9 → commit naming `#<n>` → two-axis review (Standards + Spec sub-agents, base = the ticket's parent commit) → fix findings in a second commit → push → closing comment on the issue.
- Live verification: `hyprctl monitors -j | jq '.[] | [.refreshRate,.vrr,.colorManagementPreset,.sdrBrightness,.sdrMaxLuminance]'`; panel screenshot via `qs ipc -p /usr/share/omarchy/shell call caioniehues.hdr open`, then `grim -g "<x>,<y> 1000x1000"`, then `… close`.
- Reinstall after code changes: `./install.sh` (restarts the Omarchy shell; it also runs `omarchy-hdr-set on`).

## Gotchas

- **Never run `install.sh` in a fake `$HOME` without stubbing `omarchy` and `omarchy-shell`** (they live in `/usr/bin`): it restarted the real Omarchy shell under the fake HOME and killed the bar. `tests/install.bats` shows the stubs.
- `hyprctl keyword` is rejected under the Lua config; use `hyprctl eval`. Dispatchers are Lua too: `hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "fullscreen" })'`.
- `hyprctl eval` answers `ok` even for invalid values (e.g. `sdr_eotf = "bogus"`), and `max_luminance`, `sdr_eotf`, the configured vrr mode and the CTM have no read-back.
- `hyprctl hyprsunset identity` *sets* identity (it is not a query); `hyprctl hyprsunset temperature` returns the last temperature set, even while identity is active.
- The `edit` tool once misapplied a multi-line deletion in `~/.config/hypr/monitors.lua`; re-read that file after editing it, or rewrite it whole.
