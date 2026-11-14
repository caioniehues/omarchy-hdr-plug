# HDR Control (`caioniehues.hdr`)

Fork of [vedix95/omarchy-hdr-plug](https://github.com/vedix95/omarchy-hdr-plug) by vedix95.

Plugin Omarchy pour piloter l'affichage HDR, les profils colorimétriques et la température de couleur sous Hyprland depuis la barre Omarchy.

## Fonctionnalités

- **Indicateur barre** (`󰃠` / `󰃞`) avec infobulle dynamique et bascule rapide HDR ON/OFF au clic droit.
- **Panneau de contrôle** (`Panel.qml`) :
  - Détection automatique du moniteur, des capacités HDR EDID (luminance max en nits) et support multi-écrans (`Dropdown`).
  - Interrupteur HDR ON/OFF et bouton de rescan matériel (`󰑐`).
  - Curseur de température de couleur (3000–9000 K) piloté via `hyprsunset` avec debounce.
  - Modes HDR : `Vivid HDR`, `Cinéma HDR`, `Plein Jour`.
  - Modes SDR : `Cinéma (P3)`, `Design (sRGB)`.
  - Bouton **Réinitialiser** (`reset`) avec dialogue de confirmation pour restaurer l'affichage natif d'origine.
- **Persistance XDG** : état sauvegardé par moniteur dans `~/.local/state/caioniehues.hdr/state.json` et configuration Hyprland générée dans `~/.config/hypr/hdr.lua`.

## Dépendances

- `hyprctl` / Hyprland
- `jq`
- `edid-decode` (lecture des capacités EDID)
- `hyprsunset` (contrôle de la température de couleur)
- `notify-send` (notifications optionnelles)

## Installation & Désinstallation

```bash
chmod +x install.sh
./install.sh
```

Pour supprimer complètement le plugin et restaurer le système comme s'il n'avait jamais existé :

```bash
./install.sh --uninstall
```

## Utilisation CLI

- `bin/omarchy-hdr-status [monitor]` : retourne l'état JSON complet (moniteurs, EDID, état courant).
- `bin/omarchy-hdr-set [--monitor <name>] <action> [param...]` :
  - `toggle`, `on`, `off`
  - `temperature <3000..9000>`
  - `preset vivid|cinema_hdr|cinema|outdoor|eco|optimal`
  - `sdr_brightness <val>`, `sdr_saturation <val>`, `sdr_max_lum <nits>`
  - `cm <preset>`, `backlight_sync <true|false>`
  - `apply <brightness> <saturation> <max_luminance> <cm> [backlight_sync]`
  - `reset` (réinitialise `hyprsunset`, supprime `hdr.lua` et `state.json`, recharge Hyprland)
