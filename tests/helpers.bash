# Shared bats setup: isolated HOME/XDG state, stub system tools on PATH, G95SC fixtures.

REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
FIXTURES="$BATS_TEST_DIRNAME/fixtures"
G9_DESC="Samsung Electric Company Odyssey G95SC H1AK500000"

setup() {
  export HOME="$BATS_TEST_TMPDIR/home"
  export XDG_STATE_HOME="$HOME/.local/state"
  export HYPRCTL_LOG="$BATS_TEST_TMPDIR/hyprctl.log"
  export MONITORS_FIXTURE="$FIXTURES/monitors-g95sc.json"
  export EDID_FIXTURE="$FIXTURES/g95sc.edid-decode.txt"
  export HDR_SYSFS_DRM="$BATS_TEST_TMPDIR/drm"
  mkdir -p "$HOME/.config/hypr" "$HDR_SYSFS_DRM/card1-DP-2" "$BATS_TEST_TMPDIR/bin"
  echo edid > "$HDR_SYSFS_DRM/card1-DP-2/edid"
  : > "$HYPRCTL_LOG"

  local stubs="$BATS_TEST_TMPDIR/bin"
  cat > "$stubs/hyprctl" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$HYPRCTL_LOG"
[[ "$1 $2" == "monitors -j" ]] && cat "$MONITORS_FIXTURE"
exit 0
EOF
  cat > "$stubs/edid-decode" <<'EOF'
#!/usr/bin/env bash
cat "$EDID_FIXTURE"
EOF
  printf '#!/usr/bin/env bash\nexit 1\n' > "$stubs/pgrep"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$stubs/notify-send"
  chmod +x "$stubs"/*
  export PATH="$stubs:$PATH"
}

hdr_set() { "$REPO/bin/omarchy-hdr-set" "$@"; }
hdr_status() { "$REPO/bin/omarchy-hdr-status" "$@"; }
state_file() { echo "$XDG_STATE_HOME/caioniehues.hdr/state.json"; }
hdr_lua() { echo "$HOME/.config/hypr/hdr.lua"; }
# Last `hyprctl eval` payload sent to Hyprland.
last_eval() { grep '^eval ' "$HYPRCTL_LOG" | tail -1; }
