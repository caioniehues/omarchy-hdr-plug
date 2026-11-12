# Plugin Omarchy HDR Control (`vedix.hdr`)

Plugin de barre et panneau de contrôle dynamique pour la gestion du mode **HDR (High Dynamic Range)**, des couleurs 10-bit et de la luminance sous Omarchy / Hyprland.

---

## 🌟 Fonctionnalités

- **Détection Matérielle Universelle (EDID)** : Extrait automatiquement la luminance maximale (nits), moyenne et le plancher des noirs réels de votre dalle via `edid-decode` et `/sys/class/drm/`. S'adapte à n'importe quel écran (PC portable OLED, écran externe 1000 nits, écran standard).
- **Zéro Saccade & Zéro Clignotement** : Curseurs natifs Omarchy `PanelSlider` avec un timer de debounce (150ms) et application directe en mémoire (`hyprctl eval`) sans rechargement lourd d'Hyprland.
- **Suivi Dynamique du Rétroéclairage** : Maintient le niveau de luminosité cible sans le corrompre lorsque l'ordinateur réduit la luminosité sur batterie. Possibilité de basculer en mode fixe.
- **Espaces Colorimétriques 10-bit** : `HDR (PQ)`, `DCI-P3` (OLED éclatant) et `sRGB` (standard).
- **Profils Rapides en 1 Clic** :
  - *Vivid OLED* : Boost 1.8x, saturation 1.15x, luminance maximale.
  - *Cinéma* : Rendu neutre 1.0x, saturation 1.0x, DCI-P3.
  - *Plein Jour* : Boost 2.0x, saturation 1.20x.
  - *Éco Batterie* : SDR calibré et économe.
  - *Optimal EDID* : Restaure les paramètres recommandés d'usine.
- **Bascule Instantanée au Clic Droit** : Active/désactive le HDR en un clic sur l'icône de la barre avec notification de bureau discrète.
- **Multilingue (i18n)** : Français et Anglais inclus.

---

## 🚀 Réinstallation sur un Autre Ordinateur

Vous disposez de **deux méthodes simples** pour installer ce plugin sur une autre machine Omarchy.

### Méthode 1 : Via le script d'installation automatique (Recommandé)

1. Copiez ce dossier `omarchy-hdr-plugin` sur votre nouvelle machine (via clé USB, réseau ou archive `.tar.gz`).
2. Ouvrez un terminal dans le dossier et lancez :
   ```bash
   ./install.sh
   ```
Le script s'occupe de tout automatiquement :
- Installation des dépendances (`edid-decode`, `jq`).
- Copie des fichiers dans `~/.config/omarchy/plugins/vedix.hdr/`.
- Déclaration automatique de `require("hypr.hdr")` dans `~/.config/hypr/hyprland.lua`.
- Génération du profil `~/.config/hypr/hdr.lua`.
- Enregistrement permanent dans `~/.config/omarchy/shell.json`.
- Rechargement du shell Omarchy.

---

### Méthode 2 : Via Git et le gestionnaire de plugins Omarchy

Si vous publiez ce dossier sur GitHub/GitLab :
```bash
git init
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/votre-compte/omarchy-hdr-plugin.git
git push -u origin main
```

Sur n'importe quelle machine Omarchy, il vous suffira alors de taper :
```bash
omarchy plugin add https://github.com/votre-compte/omarchy-hdr-plugin.git --enable
```
Puis d'ajouter `require("hypr.hdr")` dans votre `~/.config/hypr/hyprland.lua`.

---

## 📁 Structure du Plugin

```
omarchy-hdr-plugin/
├── manifest.json            # Manifeste officiel Omarchy Plugin Schema
├── Panel.qml                # Interface graphique QML (BarIconButton & KeyboardPanel)
├── bin/
│   ├── omarchy-hdr-status   # Script de détection matérielle (EDID, sysfs, état JSON)
│   └── omarchy-hdr-set      # Script d'application dynamique et persistance Hyprland
├── i18n/
│   ├── fr.json              # Traductions Françaises
│   └── en.json              # Traductions Anglaises
├── state.json               # Fichier d'état persistant
├── install.sh               # Script d'installation clé-en-main
└── README.md                # Documentation
```
