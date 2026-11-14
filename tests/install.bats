#!/usr/bin/env bats

load helpers

install_sandbox() {
  # Never touch the live Omarchy shell from tests.
  local stubs="$BATS_TEST_TMPDIR/bin"
  # validate passes; enable fails so the installer exercises its shell.json fallback.
  printf '#!/usr/bin/env bash\n[[ "$1 $2" == "plugin validate" ]]\n' > "$stubs/omarchy"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$stubs/omarchy-shell"
  chmod +x "$stubs/omarchy" "$stubs/omarchy-shell"
  mkdir -p "$HOME/.config/omarchy"
  printf 'require("hypr.monitors")\n' > "$HOME/.config/hypr/hyprland.lua"
  echo '{"plugins":[],"bar":{"layout":{"right":[{"id":"omarchy.tray"}]}}}' > "$HOME/.config/omarchy/shell.json"
}

@test "install then uninstall leaves no trace of the plugin" {
  install_sandbox
  "$REPO/install.sh" >/dev/null
  [ -d "$HOME/.config/omarchy/plugins/caioniehues.hdr" ]
  grep -q 'hypr.hdr' "$HOME/.config/hypr/hyprland.lua"

  "$REPO/install.sh" --uninstall >/dev/null
  run grep -rl 'hdr' "$HOME/.config" "$XDG_STATE_HOME"
  [ "$status" -ne 0 ]
}
