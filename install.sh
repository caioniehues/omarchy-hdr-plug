#!/usr/bin/env bash
# ==============================================================================
# Installer / Uninstaller for Omarchy HDR Control Plugin (caioniehues.hdr)
# ==============================================================================
set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ID="caioniehues.hdr"
TARGET_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/$PLUGIN_ID"
HYPR_CONF="$HOME/.config/hypr/hyprland.lua"
HDR_CONF="$HOME/.config/hypr/hdr.lua"
SHELL_CONF="$HOME/.config/omarchy/shell.json"

uninstall_plugin() {
  echo -e "${BLUE}${BOLD}=== Uninstalling Omarchy HDR Control ===${NC}\n"

  # 1. Reset display, hyprsunset, hdr.lua, and state
  if [[ -x "$TARGET_DIR/bin/omarchy-hdr-set" ]]; then
    "$TARGET_DIR/bin/omarchy-hdr-set" reset >/dev/null 2>&1 || true
  elif [[ -x "$SCRIPT_DIR/bin/omarchy-hdr-set" ]]; then
    "$SCRIPT_DIR/bin/omarchy-hdr-set" reset >/dev/null 2>&1 || true
  fi
  rm -rf "$STATE_DIR" "$HDR_CONF"

  # 2. Remove from Hyprland config
  if [[ -f "$HYPR_CONF" ]]; then
    sed -i '/require.*"hypr\.hdr"/d' "$HYPR_CONF"
    echo -e "${GREEN}✓ Removed hypr.hdr from $HYPR_CONF.${NC}"
  fi

  # 3. Unregister from Omarchy plugins & shell.json
  if command -v omarchy >/dev/null 2>&1; then
    omarchy plugin remove "$PLUGIN_ID" --yes >/dev/null 2>&1 || true
  fi

  if [[ -f "$SHELL_CONF" ]] && command -v jq >/dev/null 2>&1; then
    local tmp_json
    tmp_json=$(mktemp)
    jq --arg id "$PLUGIN_ID" '
      .plugins = ((.plugins // []) | map(select(.id != $id))) |
      .bar.layout.right = ((.bar.layout.right // []) | map(select(.id != $id))) |
      .bar.layout.left = ((.bar.layout.left // []) | map(select(.id != $id))) |
      .bar.layout.center = ((.bar.layout.center // []) | map(select(.id != $id)))
    ' "$SHELL_CONF" > "$tmp_json" && mv "$tmp_json" "$SHELL_CONF"
    echo -e "${GREEN}✓ Removed $PLUGIN_ID from $SHELL_CONF.${NC}"
  fi

  # 4. Remove plugin directory
  rm -rf "$TARGET_DIR"
  echo -e "${GREEN}✓ Deleted $TARGET_DIR.${NC}"

  # 5. Reload Hyprland and Omarchy Shell
  command -v hyprctl >/dev/null 2>&1 && hyprctl reload >/dev/null 2>&1 || true
  if command -v omarchy >/dev/null 2>&1; then
    omarchy restart shell >/dev/null 2>&1 || omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  fi

  echo -e "\n${GREEN}${BOLD}✓ Uninstall complete: nothing left behind.${NC}"
  exit 0
}

if [[ "${1:-}" == "--uninstall" || "${1:-}" == "uninstall" ]]; then
  uninstall_plugin
fi

echo -e "${BLUE}${BOLD}=== Installing Omarchy HDR Control ===${NC}\n"

# 1. Check dependencies (edid-decode, jq, hyprsunset)
echo -e "${BLUE}1. Checking system dependencies...${NC}"
MISSING_PKGS=()
command -v edid-decode >/dev/null 2>&1 || MISSING_PKGS+=("edid-decode")
command -v jq >/dev/null 2>&1 || MISSING_PKGS+=("jq")
command -v hyprsunset >/dev/null 2>&1 || MISSING_PKGS+=("hyprsunset")

if [[ ${#MISSING_PKGS[@]} -gt 0 ]]; then
  echo -e "${YELLOW}Installing required packages (${MISSING_PKGS[*]})...${NC}"
  if command -v omarchy >/dev/null 2>&1; then
    omarchy pkg add "${MISSING_PKGS[@]}"
  elif command -v sudo >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm "${MISSING_PKGS[@]}"
  else
    echo -e "${RED}Error: please install manually: ${MISSING_PKGS[*]}${NC}"
    exit 1
  fi
else
  echo -e "${GREEN}✓ Dependencies satisfied (edid-decode, jq, hyprsunset).${NC}"
fi

# 2. Copy the plugin into ~/.config/omarchy/plugins/caioniehues.hdr
echo -e "\n${BLUE}2. Installing plugin files...${NC}"
mkdir -p "$TARGET_DIR/bin" "$TARGET_DIR/i18n"

if [[ "$SCRIPT_DIR" != "$TARGET_DIR" ]]; then
  cp -f "$SCRIPT_DIR/manifest.json" "$TARGET_DIR/"
  cp -f "$SCRIPT_DIR/Panel.qml" "$TARGET_DIR/"
  cp -f "$SCRIPT_DIR/bin/omarchy-hdr-status" "$TARGET_DIR/bin/"
  cp -f "$SCRIPT_DIR/bin/omarchy-hdr-set" "$TARGET_DIR/bin/"
  cp -f "$SCRIPT_DIR/i18n/"*.json "$TARGET_DIR/i18n/"
fi

chmod +x "$TARGET_DIR/bin/omarchy-hdr-status" "$TARGET_DIR/bin/omarchy-hdr-set"
echo -e "${GREEN}✓ Files installed in $TARGET_DIR.${NC}"

# Validate the Omarchy manifest
if command -v omarchy >/dev/null 2>&1; then
  omarchy plugin validate "$TARGET_DIR"
  echo -e "${GREEN}✓ Manifest validated by omarchy plugin validate.${NC}"
fi

# 3. Load hdr.lua from Hyprland (~/.config/hypr/hyprland.lua), tolerating its absence
echo -e "\n${BLUE}3. Configuring Hyprland...${NC}"
if [[ -f "$HYPR_CONF" ]]; then
  if grep -q '^require("hypr\.hdr")' "$HYPR_CONF"; then
    sed -i 's/^require("hypr\.hdr")/pcall(require, "hypr.hdr")/' "$HYPR_CONF"
    echo -e "${GREEN}✓ Migrated to pcall(require, \"hypr.hdr\").${NC}"
  elif ! grep -q 'hypr\.hdr' "$HYPR_CONF"; then
    echo -e "${YELLOW}Adding pcall(require, \"hypr.hdr\") to $HYPR_CONF...${NC}"
    if grep -q 'require("hypr.monitors")' "$HYPR_CONF"; then
      sed -i '/require("hypr.monitors")/a pcall(require, "hypr.hdr")' "$HYPR_CONF"
    else
      echo 'pcall(require, "hypr.hdr")' >> "$HYPR_CONF"
    fi
    echo -e "${GREEN}✓ Hyprland now loads hypr.hdr.${NC}"
  else
    echo -e "${GREEN}✓ hypr.hdr is already loaded by hyprland.lua.${NC}"
  fi
fi

# 4. Generate the initial HDR config (~/.config/hypr/hdr.lua)
echo -e "\n${BLUE}4. Initializing the display profile...${NC}"
"$TARGET_DIR/bin/omarchy-hdr-set" on >/dev/null 2>&1 || true
echo -e "${GREEN}✓ Generated ~/.config/hypr/hdr.lua.${NC}"

# 5. Register with Omarchy plugins
echo -e "\n${BLUE}5. Registering with Omarchy plugins...${NC}"
if command -v omarchy >/dev/null 2>&1 && omarchy plugin enable "$PLUGIN_ID" right >/dev/null 2>&1; then
  echo -e "${GREEN}✓ Plugin enabled via omarchy plugin enable.${NC}"
elif [[ -f "$SHELL_CONF" ]]; then
  TMP_JSON=$(mktemp)
  jq --arg id "$PLUGIN_ID" '
    .plugins = ([{"id": $id}] + (.plugins // [] | map(select(.id != $id)))) |
    if (.bar.layout.right | map(.id) | index($id)) == null then
      .bar.layout.right = (
        .bar.layout.right as $r |
        ($r | map(.id) | index("omarchy.tray")) as $tray_idx |
        if $tray_idx != null then
          $r[0:$tray_idx+1] + [{"id": $id}] + $r[$tray_idx+1:]
        else
          [{"id": $id}] + $r
        end
      )
    else
      .
    end
  ' "$SHELL_CONF" > "$TMP_JSON" && mv "$TMP_JSON" "$SHELL_CONF"
  echo -e "${GREEN}✓ Plugin registered in shell.json.${NC}"
fi

# 6. Reload the shell
echo -e "\n${BLUE}6. Reloading the Omarchy shell...${NC}"
if command -v omarchy >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  omarchy restart shell >/dev/null 2>&1 || true
fi

echo -e "\n${GREEN}${BOLD}======================================================${NC}"
echo -e "${GREEN}${BOLD} Installation complete!${NC}"
echo -e "${GREEN}${BOLD} $PLUGIN_ID is active in Omarchy and the bar.${NC}"
echo -e "${GREEN}${BOLD}======================================================${NC}"
