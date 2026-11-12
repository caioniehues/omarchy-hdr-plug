#!/usr/bin/env bash
# ==============================================================================
# Installer for Omarchy HDR Control Plugin (vedix.hdr)
# ==============================================================================
set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}${BOLD}=== Installation du plugin Omarchy HDR Control ===${NC}\n"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/.config/omarchy/plugins/vedix.hdr"
HYPR_CONF="$HOME/.config/hypr/hyprland.lua"
SHELL_CONF="$HOME/.config/omarchy/shell.json"

# 1. Vérification des dépendances (edid-decode, jq)
echo -e "${BLUE}1. Vérification des dépendances système...${NC}"
MISSING_PKGS=()
if ! command -v edid-decode >/dev/null 2>&1; then
  MISSING_PKGS+=("edid-decode")
fi
if ! command -v jq >/dev/null 2>&1; then
  MISSING_PKGS+=("jq")
fi

if [[ ${#MISSING_PKGS[@]} -gt 0 ]]; then
  echo -e "${YELLOW}Installation des paquets requis (${MISSING_PKGS[*]})...${NC}"
  if command -v omarchy >/dev/null 2>&1; then
    omarchy pkg add "${MISSING_PKGS[@]}"
  elif command -v sudo >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm "${MISSING_PKGS[@]}"
  else
    echo -e "${RED}Erreur : veuillez installer manuellement : ${MISSING_PKGS[*]}${NC}"
    exit 1
  fi
else
  echo -e "${GREEN}✓ Dépendances satisfaites (edid-decode, jq).${NC}"
fi

# 2. Copie du plugin dans ~/.config/omarchy/plugins/vedix.hdr
echo -e "\n${BLUE}2. Installation des fichiers du plugin...${NC}"
mkdir -p "$TARGET_DIR/bin" "$TARGET_DIR/i18n"

if [[ "$SCRIPT_DIR" != "$TARGET_DIR" ]]; then
  cp -rf "$SCRIPT_DIR/manifest.json" "$TARGET_DIR/"
  cp -rf "$SCRIPT_DIR/Panel.qml" "$TARGET_DIR/"
  cp -rf "$SCRIPT_DIR/bin/"* "$TARGET_DIR/bin/"
  cp -rf "$SCRIPT_DIR/i18n/"* "$TARGET_DIR/i18n/"
  [[ -f "$SCRIPT_DIR/state.json" ]] && cp -f "$SCRIPT_DIR/state.json" "$TARGET_DIR/"
fi

chmod +x "$TARGET_DIR/bin/omarchy-hdr-status"
chmod +x "$TARGET_DIR/bin/omarchy-hdr-set"
echo -e "${GREEN}✓ Fichiers installés dans $TARGET_DIR.${NC}"

# 3. Activation dans Hyprland (~/.config/hypr/hyprland.lua)
echo -e "\n${BLUE}3. Configuration de Hyprland...${NC}"
if [[ -f "$HYPR_CONF" ]]; then
  if ! grep -q 'require("hypr.hdr")' "$HYPR_CONF"; then
    echo -e "${YELLOW}Ajout de require(\"hypr.hdr\") dans $HYPR_CONF...${NC}"
    # Insérer après require("hypr.monitors") ou à la fin
    if grep -q 'require("hypr.monitors")' "$HYPR_CONF"; then
      sed -i '/require("hypr.monitors")/a require("hypr.hdr")' "$HYPR_CONF"
    else
      echo 'require("hypr.hdr")' >> "$HYPR_CONF"
    fi
    echo -e "${GREEN}✓ Hyprland configuré pour charger hypr.hdr.${NC}"
  else
    echo -e "${GREEN}✓ require(\"hypr.hdr\") est déjà présent dans hyprland.lua.${NC}"
  fi
fi

# 4. Initialisation de la configuration HDR (~/.config/hypr/hdr.lua)
echo -e "\n${BLUE}4. Initialisation du profil matériel...${NC}"
"$TARGET_DIR/bin/omarchy-hdr-set" on >/dev/null 2>&1 || true
echo -e "${GREEN}✓ Configuration initiale générée dans ~/.config/hypr/hdr.lua.${NC}"

# 5. Enregistrement dans Omarchy Shell (~/.config/omarchy/shell.json)
echo -e "\n${BLUE}5. Intégration dans la barre Omarchy...${NC}"
if [[ -f "$SHELL_CONF" ]]; then
  # Ajouter dans plugins[] et dans bar.layout.right
  TMP_JSON=$(mktemp)
  jq '
    .plugins = ([{"id": "vedix.hdr"}] + (.plugins // [] | map(select(.id != "vedix.hdr")))) |
    if (.bar.layout.right | map(.id) | index("vedix.hdr")) == null then
      .bar.layout.right = (
        .bar.layout.right as $r |
        ($r | map(.id) | index("omarchy.tray")) as $tray_idx |
        if $tray_idx != null then
          $r[0:$tray_idx+1] + [{"id": "vedix.hdr"}] + $r[$tray_idx+1:]
        else
          [{"id": "vedix.hdr"}] + $r
        end
      )
    else
      .
    end
  ' "$SHELL_CONF" > "$TMP_JSON" && mv "$TMP_JSON" "$SHELL_CONF"
  echo -e "${GREEN}✓ Plugin enregistré de manière permanente dans shell.json.${NC}"
fi

# 6. Rechargement du shell
echo -e "\n${BLUE}6. Rechargement du Shell Omarchy...${NC}"
if command -v omarchy >/dev/null 2>&1; then
  omarchy restart shell >/dev/null 2>&1 || omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
fi

echo -e "\n${GREEN}${BOLD}======================================================${NC}"
echo -e "${GREEN}${BOLD} Installation terminée avec succès !${NC}"
echo -e "${GREEN}${BOLD} L'icône HDR est désormais active sur votre barre.${NC}"
echo -e "${GREEN}${BOLD}======================================================${NC}"
