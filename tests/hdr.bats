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

@test "a crafted color-space value cannot inject Lua into the rule" {
  hdr_set cm 'hdr" }) os.execute("x'
  run last_eval
  [[ "$output" == *'cm = "hdr\" }) os.execute(\"x"'* ]]
}

@test "non-numeric slider input is rejected without touching state" {
  hdr_set on
  before=$(cat "$(state_file)")
  run hdr_set sdr_brightness '1); os.execute("x"'
  [ "$status" -ne 0 ]
  [ "$(cat "$(state_file)")" = "$before" ]
}
