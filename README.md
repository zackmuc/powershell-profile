# 🖥️ PowerShell-Profil & Theme Manager (DE)
> Persönliches PowerShell-Profil (pwsh 7) mit **oh-my-posh**, interaktivem **Theme-Manager**, Datei-/Ordner-**Icons** (Terminal-Icons) und **Preview** in neuem Fenster/Tab. Zweisprachige Doku – unten folgt die EN-Version.

<p align="left">
  <img alt="PowerShell" src="https://img.shields.io/badge/PowerShell-7.x-5391FE?logo=powershell&logoColor=white">
  <img alt="Oh My Posh" src="https://img.shields.io/badge/oh--my--posh-enabled-success">
  <img alt="Nerd Font" src="https://img.shields.io/badge/Nerd%20Font-required-informational">
  <img alt="License" src="https://img.shields.io/badge/License-MIT-blue">
</p>

## ✨ Features
- **Letztes Theme** wird beim Start geladen, sonst Fallback auf ein **Default**.
- Interaktives Menü **`mythemes`**: Zahl → anwenden, **`pN`** → Preview, **`aN`** → Apply, **`c`/`q`** → abbrechen/beenden.
- **Eigene Themes** komfortabel **hinzufügen/entfernen** (JSON-basiert).
- **Icons** in `ls`/`Get-ChildItem` über **Terminal-Icons** (Auto-Import).
- **Preview** in neuem Fenster/Tab (ohne Profil), lädt Theme **und** Terminal-Icons.
- Adaptive Farben, **High-Contrast-Toggle**, robuste Fehlerbehandlung.

## 📸 Screenshot
![PowerShell Theme Screenshot](Images/screenshot1.png)

## 🧩 Voraussetzungen
- **PowerShell 7**
- **oh-my-posh**
- **Nerd Font** in Windows Terminal (z. B. *FiraCode Nerd Font Mono*)
- **Terminal-Icons** (einmalig installieren, Auto-Import im Profil):
```powershell
Install-Module Terminal-Icons -Scope CurrentUser
```

> Stelle im **Windows Terminal → Profil PowerShell → Darstellung → Schriftart** den **Nerd Font** ein (z. B. *FiraCode Nerd Font Mono*), sonst fehlen die Icons.

## ⚙️ Installation / Update
```powershell
# 1) Repo klonen
git clone https://github.com/<USER>/<REPO>.git
cd <REPO>

# 2) altes Profil sichern
Copy-Item $PROFILE "$PROFILE.bak" -ErrorAction SilentlyContinue

# 3) neues Profil kopieren
Copy-Item .\Microsoft.PowerShell_profile.ps1 $PROFILE -Force

# 4) Profil neu laden
. $PROFILE
```

## 🧑‍💻 Nutzung
```powershell
mythemes      # Menü öffnen
3             # Theme #3 anwenden
p3            # Preview von #3 in neuem Fenster/Tab
a3            # Apply von #3 direkt
q             # Beenden
```
**Custom Themes**  
- Datei: `%USERPROFILE%\.omp_custom_themes.json` (automatisch)  
- Felder: `Name`, `Url`  
- Alternativ: `Add-CustomTheme` / `Remove-CustomTheme`

## 🧰 Troubleshooting
- **Icons fehlen?** Nerd Font aktiv? `Terminal-Icons` installiert/geladen?
- **Preview ohne Icons?** Das Skript lädt Terminal-Icons dort explizit; prüfe, dass auch das Preview-Fenster den Nerd Font nutzt (Windows Terminal als Standard-Host empfohlen).
- **Schlechter Kontrast?** `Toggle-ThemeContrast` ausführen.

## 🏷️ Versionierung & Releases
- Tags: `v1.0`, `v1.1`, …  
- Releases: GitHub → **Releases**

**Neuen Release (z. B. v1.1) anlegen**
```powershell
git tag v1.1
git push origin v1.1

# GitHub-CLI (empfohlen)
gh release create v1.1 `
  --title "Version 1.1" `
  --notes "DE: Icons automatisch (normal + Preview), zweisprachige Doku.
EN: Icons auto (normal + preview), bilingual docs."
# Optional Datei anhängen:
# gh release create v1.1 Microsoft.PowerShell_profile.ps1 --title "Version 1.1" --notes "..."
```

---

# 🖥️ PowerShell Profile & Theme Manager (EN)
> Personal PowerShell profile (pwsh 7) with **oh-my-posh**, interactive **theme manager**, file/folder **icons** (Terminal-Icons), and **preview** in a new window/tab. Bilingual docs — German section above.

<p align="left">
  <img alt="PowerShell" src="https://img.shields.io/badge/PowerShell-7.x-5391FE?logo=powershell&logoColor=white">
  <img alt="Oh My Posh" src="https://img.shields.io/badge/oh--my--posh-enabled-success">
  <img alt="Nerd Font" src="https://img.shields.io/badge/Nerd%20Font-required-informational">
  <img alt="License" src="https://img.shields.io/badge/License-MIT-blue">
</p>

## ✨ Features
- **Load last theme** at startup, fallback to a **default** if none.
- Interactive menu **`mythemes`**: number → apply, **`pN`** → preview, **`aN`** → apply, **`c`/`q`** → cancel/quit.
- **Custom themes**: **add/remove** easily (JSON-based).
- **Icons** in `ls`/`Get-ChildItem` via **Terminal-Icons** (auto-import).
- **Preview** in a new window/tab (no profile), loads theme **and** Terminal-Icons.
- Adaptive colors, **high-contrast toggle**, robust error handling.

## 📸 Screenshot
![PowerShell Theme Screenshot](Images/screenshot1.png)

## 🧩 Requirements
- **PowerShell 7**
- **oh-my-posh**
- **Nerd Font** in Windows Terminal (e.g., *FiraCode Nerd Font Mono*)
- **Terminal-Icons** (install once; auto-imported in the profile):
```powershell
Install-Module Terminal-Icons -Scope CurrentUser
```

> In **Windows Terminal → PowerShell profile → Appearance → Font**, select your **Nerd Font** (e.g., *FiraCode Nerd Font Mono*), otherwise icons won’t show.

## ⚙️ Install / Update
```powershell
# 1) clone
git clone https://github.com/<USER>/<REPO>.git
cd <REPO>

# 2) backup
Copy-Item $PROFILE "$PROFILE.bak" -ErrorAction SilentlyContinue

# 3) deploy
Copy-Item .\Microsoft.PowerShell_profile.ps1 $PROFILE -Force

# 4) reload
. $PROFILE
```

## 🧑‍💻 Usage
```powershell
mythemes      # open menu
3             # apply theme #3
p3            # preview theme #3 in new window/tab
a3            # apply theme #3 directly
q             # quit
```
**Custom Themes**  
- File: `%USERPROFILE%\.omp_custom_themes.json` (auto)  
- Fields: `Name`, `Url`  
- Alternatively: `Add-CustomTheme` / `Remove-CustomTheme`

## 🧰 Troubleshooting
- **Missing icons?** Nerd Font active? `Terminal-Icons` installed/loaded?
- **Preview without icons?** Script imports Terminal-Icons there explicitly; ensure the preview window also uses the Nerd Font (Windows Terminal as default host recommended).
- **Low contrast?** Run `Toggle-ThemeContrast`.

## 🏷️ Versioning & Releases
- Tags: `v1.0`, `v1.1`, …  
- Releases: GitHub → **Releases**

**Create a new release (e.g., v1.1)**
```powershell
git tag v1.1
git push origin v1.1

# GitHub CLI (recommended)
gh release create v1.1 `
  --title "Version 1.1" `
  --notes "DE: Icons automatisch (normal + Preview), zweisprachige Doku.
EN: Icons auto (normal + preview), bilingual docs."
# Optionally attach a file:
# gh release create v1.1 Microsoft.PowerShell_profile.ps1 --title "Version 1.1" --notes "..."
```

---

© 2025 Peter Auerbacher — MIT License
