#!/usr/bin/env bats

load helpers

@test "state persists under the caioniehues.hdr XDG state dir" {
  hdr_set on
  [ -f "$(state_file)" ]
}

@test "enabling HDR sends a color-only rule keyed by monitor description" {
  hdr_set on
  run last_eval
  [[ "$output" == *"output = \"desc:$G9_DESC\""* ]]
  [[ "$output" == *'cm = "hdr"'* ]]
  for key in mode position scale transform bitdepth; do
    [[ "$output" != *"$key ="* ]]
  done
}

@test "disabling HDR switches the same rule to neutral sRGB" {
  hdr_set off
  run last_eval
  [[ "$output" == *"output = \"desc:$G9_DESC\""* ]]
  [[ "$output" == *'cm = "srgb", sdrbrightness = 1, sdrsaturation = 1,'* ]]
}

@test "hdr.lua persists the desc-keyed color rule and nothing laptop-specific" {
  hdr_set apply 1.0 1.0 250 hdr
  run cat "$(hdr_lua)"
  [[ "$output" == *"output = \"desc:$G9_DESC\""* ]]
  [[ "$output" == *"sdr_max_luminance = 250"* ]]
  [[ "$output" == *"max_luminance = 400"* ]]
  [[ "$output" != *"mode ="* && "$output" != *backlight* ]]
}

@test "connector and description address the same saved monitor" {
  hdr_set --monitor DP-2 sdr_max_lum 220
  hdr_set --monitor "$G9_DESC" sdr_saturation 1.05
  run jq -c --arg d "$G9_DESC" '[(.monitors | keys), .monitors[$d].sdrMaxLuminance, .monitors[$d].sdrSaturation]' "$(state_file)"
  [ "$output" = "[[\"$G9_DESC\"],220,1.05]" ]
}

@test "a panel without HDR metadata falls back to SDR-only capabilities" {
  printf 'Block 0, Base EDID:\n  Bits per primary color channel: 8\n' > "$BATS_TEST_TMPDIR/sdr.txt"
  EDID_FIXTURE="$BATS_TEST_TMPDIR/sdr.txt" run hdr_status
  [ "$(jq -c '[.hdrCapable, .edidMaxLuminance, .edidAvgLuminance, .cm]' <<<"$output")" = '[false,300,250,"srgb"]' ]
}

@test "EDID luminance comes from the panel's HDR static metadata" {
  run hdr_status
  [ "$(jq -c '[.hdrCapable, .edidMaxLuminance, .edidAvgLuminance, .edidMinLuminance]' <<<"$output")" = '[true,400,248,0]' ]
}


@test "non-numeric slider input is rejected without touching state" {
  hdr_set on
  before=$(cat "$(state_file)")
  run hdr_set sdr_brightness '1); os.execute("x"'
  [ "$status" -ne 0 ]
  [ "$(cat "$(state_file)")" = "$before" ]
}

@test "JSON strings in numeric slots cannot reach the Lua rule" {
  hdr_set on
  : > "$HYPRCTL_LOG"
  run hdr_set sdr_brightness '"1 }) os.execute(\"x\") --"'
  [ "$status" -ne 0 ]
  [ -z "$(last_eval)" ]
  ! grep -q os.execute "$(hdr_lua)"
}

@test "an unknown color space is rejected" {
  run hdr_set cm bogus
  [ "$status" -ne 0 ]
  [ -z "$(last_eval)" ]
}

@test "an unknown monitor is an error, not the focused monitor" {
  run hdr_set --monitor HDMI-A-9 on
  [ "$status" -ne 0 ]
  [ ! -e "$(state_file)" ]
}

# [enabled, boost, saturation, SDR white nits, cm, preset] for the G95SC (EDID frame-avg 248 nits).
saved_preset() {
  jq -c --arg d "$G9_DESC" '.monitors[$d] | [.enabled, .sdrBrightness, .sdrSaturation, .sdrMaxLuminance, .cm, .preset]' "$(state_file)"
}

@test "OLED presets derive SDR white from the EDID frame-average" {
  hdr_set preset desktop; [ "$(saved_preset)" = '[true,1,1,250,"hdr","desktop"]' ]
  hdr_set preset bright;  [ "$(saved_preset)" = '[true,1.2,1,250,"hdr","bright"]' ]
  [[ "$(last_eval)" == *'cm = "hdr", sdrbrightness = 1.2,'* ]]
  hdr_set preset cinema;  [ "$(saved_preset)" = '[true,1,1,200,"hdr","cinema"]' ]
  hdr_set preset sdr;     [ "$(saved_preset)" = '[false,1,1,250,"hdr","sdr"]' ]
  [[ "$(last_eval)" == *'cm = "srgb"'* ]]
}

@test "turning HDR back on after the SDR preset restores HDR Desktop" {
  hdr_set preset sdr
  hdr_set on
  [ "$(saved_preset)" = '[true,1,1,250,"hdr","desktop"]' ]
  [[ "$(last_eval)" == *'cm = "hdr"'* ]]
}

@test "preset desktop sends SDR white 250 with EDID peak 400" {
  hdr_set preset desktop
  run last_eval
  [[ "$output" == *"sdr_max_luminance = 250, min_luminance = 0, max_luminance = 400"* ]]
}

@test "an unconfigured HDR monitor starts on the desktop preset" {
  run hdr_status
  [ "$(jq -c '[.preset, .sdrBrightness, .sdrSaturation, .sdrMaxLuminance, .cm]' <<<"$output")" = '["desktop",1,1,250,"hdr"]' ]
}

@test "SDR EOTF defaults to gamma 2.2 and can switch to sRGB" {
  hdr_set on
  [[ "$(last_eval)" == *'sdr_eotf = "gamma22"'* ]]
  hdr_set sdr_eotf srgb
  [[ "$(last_eval)" == *'sdr_eotf = "srgb"'* ]]
  grep -q 'sdr_eotf = "srgb"' "$(hdr_lua)"
  run hdr_status
  [ "$(jq -r .sdrEotf <<<"$output")" = srgb ]
}

@test "an unknown SDR EOTF is rejected" {
  run hdr_set sdr_eotf pq
  [ "$status" -ne 0 ]
  [ -z "$(last_eval)" ]
}

@test "EOTF changes are applied with a one-nit nudge so Hyprland re-evaluates the rule" {
  # Hyprland's rule compare ignores sdr_eotf; a soft change forces re-application.
  hdr_set sdr_eotf srgb
  run grep '^eval ' "$HYPRCTL_LOG"
  [ "${#lines[@]}" -eq 2 ]
  [[ "${lines[0]}" == *"sdr_max_luminance = 251,"* ]]
  [[ "${lines[1]}" == *"sdr_max_luminance = 250,"* ]]
}

@test "slider changes send a single rule without a nudge" {
  hdr_set sdr_max_lum 240
  run grep -c '^eval ' "$HYPRCTL_LOG"
  [ "$output" = 1 ]
}

@test "other saved monitors without an EOTF still get gamma 2.2 in hdr.lua" {
  mkdir -p "$(dirname "$(state_file)")"
  echo '{"monitors":{"Old Panel":{"enabled":true,"sdrBrightness":1,"sdrSaturation":1,"sdrMaxLuminance":200,"cm":"hdr","edidMinLuminance":0,"edidMaxLuminance":400,"edidAvgLuminance":250}}}' > "$(state_file)"
  hdr_set on
  run grep 'desc:Old Panel' "$(hdr_lua)"
  [[ "$output" == *'sdr_eotf = "gamma22"'* ]]
  [[ "$output" == *'vrr = 2'* ]]
}

@test "VRR defaults to fullscreen-only and round-trips through state and hdr.lua" {
  hdr_set on
  [[ "$(last_eval)" == *"vrr = 2"* ]]
  hdr_set vrr 1
  [[ "$(last_eval)" == *"vrr = 1"* ]]
  grep -q "vrr = 1" "$(hdr_lua)"
  run hdr_status
  [ "$(jq -r .vrr <<<"$output")" = 1 ]
}

@test "presets leave the VRR setting alone" {
  hdr_set vrr 0
  hdr_set preset sdr
  hdr_set preset desktop
  [[ "$(last_eval)" == *"vrr = 0"* ]]
}

@test "VRR only accepts off, on or fullscreen-only" {
  run hdr_set vrr 3
  [ "$status" -ne 0 ]
  [ -z "$(last_eval)" ]
}

@test "VRR changes are applied with the one-nit nudge" {
  hdr_set vrr 0
  run grep '^eval ' "$HYPRCTL_LOG"
  [ "${#lines[@]}" -eq 2 ]
  [[ "${lines[0]}" == *"sdr_max_luminance = 251,"*"vrr = 0"* ]]
  [[ "${lines[1]}" == *"sdr_max_luminance = 250,"*"vrr = 0"* ]]
}

@test "a peak override replaces the EDID peak in the rule and edid restores it" {
  hdr_set peak 600
  [[ "$(last_eval)" == *"max_luminance = 600,"* ]]
  grep -q "max_luminance = 600," "$(hdr_lua)"
  run hdr_status
  [ "$(jq -c '[.peakLuminance, .edidMaxLuminance]' <<<"$output")" = '[600,400]' ]
  hdr_set peak edid
  [[ "$(last_eval)" == *"max_luminance = 400,"* ]]
}

@test "peak overrides clamp to 250..1500 nits" {
  hdr_set peak 100
  [[ "$(last_eval)" == *"max_luminance = 250,"* ]]
  hdr_set peak 5000
  [[ "$(last_eval)" == *"max_luminance = 1500,"* ]]
}

@test "a non-numeric peak is rejected" {
  run hdr_set peak lots
  [ "$status" -ne 0 ]
  [ -z "$(last_eval)" ]
}
