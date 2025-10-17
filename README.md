# 🖥️ PowerShell-Profil & Theme Manager (DE/EN)
> Persönliches PowerShell-Profil (pwsh 7) mit **oh-my-posh**, interaktivem **Theme-Manager**, Datei-/Ordner-**Icons** (Terminal-Icons), **automatischer GitHub-Blob→Raw-Korrektur**, sowie **Selbsttest** beim Start. Zweisprachige Doku – EN folgt unten.

<p align="left">
  <img alt="PowerShell" src="https://img.shields.io/badge/PowerShell-7.x-5391FE?logo=powershell&logoColor=white">
  <img alt="Oh My Posh" src="https://img.shields.io/badge/oh--my--posh-enabled-success">
  <img alt="Nerd Font" src="https://img.shields.io/badge/Nerd%20Font-required-informational">
  <img alt="License" src="https://img.shields.io/badge/License-MIT-blue">
</p>

## ✨ Features
- **Lädt automatisch das zuletzt verwendete Theme**, Fallback auf Default, falls keins vorhanden ist.
- **Interaktives Menü `mythemes`**: Zahl → anwenden, `pN` → Vorschau, `aN` → Anwenden, `c`/`q` → Abbrechen/Beenden.
- **Eigene Themes** (JSON) einfach hinzufügen/entfernen.
- **Datei-/Ordner-Icons** durch `Terminal-Icons` (automatischer Import).
- **Preview-Funktion**: Öffnet neues Fenster ohne Profil, lädt Theme + Icons.
- **Automatische GitHub-Link-Korrektur**: wandelt `.../blob/...` oder `.../refs/heads/...` in `raw.githubusercontent.com/...` um (fix für oh-my-posh Theme-URLs).
- **Selbsttest beim Start**: zeigt „✅ Blob-Fix aktiv (Profil geladen)“, falls aktiv; sonst Warnung.
- **PowerShell 7.6 kompatibel**: ersetzt veraltetes `.Clone()` und behebt `Uri`-Alias-Konflikt.
- Adaptive Farbkontraste, High-Contrast-Toggle, strukturierte Fehlermeldungen.

## 📸 Screenshots
![Screenshot](Images/screenshot1.png)

## 🧩 Voraussetzungen
- **PowerShell 7** (getestet mit 7.6 Preview)
- **oh-my-posh**
- **Nerd Font** im Windows Terminal (z. B. *FiraCode Nerd Font Mono*)
- **Terminal-Icons** (einmalig installieren, wird automatisch geladen)
```powershell
Install-Module Terminal-Icons -Scope CurrentUser
```
> Stelle im Windows Terminal → PowerShell → Darstellung → Schriftart deinen Nerd Font ein, sonst fehlen Icons.

## ⚙️ Installation / Update
```powershell
git clone https://github.com/zackmuc/powershell-profile.git
cd powershell-profile

Copy-Item $PROFILE "$PROFILE.bak" -ErrorAction SilentlyContinue
Copy-Item .\Microsoft.PowerShell_profile.ps1 $PROFILE -Force
. $PROFILE
```

## 🧑‍💻 Nutzung
```powershell
mythemes      # Menü öffnen
3             # Theme 3 anwenden
p3            # Vorschau von Theme 3
a3            # Anwenden von Theme 3
q             # Beenden
```
### Custom Themes
- Datei: `%USERPROFILE%\.omp_custom_themes.json` (automatisch erstellt)
- Felder: `Name`, `Url` (unterstützt GitHub-Blob-Links – werden automatisch korrigiert)
- Alternativ: `Add-CustomTheme` / `Remove-CustomTheme`

## 🧰 Troubleshooting
- **Fehler „Kein valides JSON“ bei GitHub-Link?**
  - Der Blob-Fix korrigiert Links automatisch.
  - Prüfe:
    1) Kein Start mit `pwsh -NoProfile`?
    2) Richtiges Profil (PowerShell 7, nicht 5.1)?
    3) Kein Modul überschreibt `Invoke-WebRequest`?
    4) Tools mit `HttpClient` umgehen den Fix.
- **PowerShell 7.6 Preview:**
  - `.Clone()` entfernt → ersetzt durch manuelle Parameterkopie.
  - `Uri`-Alias entfernt (nur `U` bleibt).
- **Icons fehlen?** Nerd Font aktiv + Terminal-Icons installiert?
- **Preview ohne Icons?** Preview lädt Icons manuell.
- **Kontrast zu niedrig?** `Toggle-ThemeContrast` ausführen.

## 🏷️ Versionierung & Releases
```powershell
git tag v1.3
git push origin main
git push origin v1.3
```
Neuen Release (mit GitHub CLI):
```powershell
gh release create v1.3 `
  --title "Version 1.3" `
  --notes "Blob-Fix, Selbsttest, README aktualisiert."
```

---

# 🖥️ PowerShell Profile & Theme Manager (EN)
> Personal PowerShell profile (pwsh 7) with **oh-my-posh**, interactive **theme manager**, **file/folder icons**, automatic **GitHub blob→raw correction**, and a **startup self-test**.

## ✨ Features
- Automatically loads the last used theme; falls back to default if none is set.
- Interactive menu `mythemes`: number → apply, `pN` → preview, `aN` → apply, `c`/`q` → quit.
- Add/remove custom themes (JSON-based).
- File/folder icons via Terminal-Icons (auto-import).
- Preview mode: opens a new window without profile, loads theme + icons.
- Automatic GitHub link correction: converts `.../blob/...` and `.../refs/heads/...` to `raw.githubusercontent.com/...`.
- Startup self-test: prints “✅ Blob-Fix active (profile loaded)” if hooked.
- PowerShell 7.6 compatible (manual param copy instead of `.Clone()`).
- Adaptive colors, error handling, and contrast toggle.

## 📸 Screenshots
![Screenshot](Images/screenshot1.png)

## 🧩 Requirements
- PowerShell 7 (tested with 7.6 Preview)
- oh-my-posh
- Nerd Font (e.g., FiraCode Nerd Font Mono)
- Terminal-Icons:
```powershell
Install-Module Terminal-Icons -Scope CurrentUser
```
> Make sure your PowerShell font in Windows Terminal is a Nerd Font.

## ⚙️ Installation / Update
```powershell
git clone https://github.com/zackmuc/powershell-profile.git
cd powershell-profile
Copy-Item $PROFILE "$PROFILE.bak" -ErrorAction SilentlyContinue
Copy-Item .\Microsoft.PowerShell_profile.ps1 $PROFILE -Force
. $PROFILE
```

## 🧑‍💻 Usage
```powershell
mythemes
3
p3
a3
q
```
### Custom Themes
- File: `%USERPROFILE%\.omp_custom_themes.json`
- Fields: `Name`, `Url` (supports blob links → auto-corrected)
- Cmdlets: `Add-CustomTheme`, `Remove-CustomTheme`

## 🧰 Troubleshooting
- “Not valid JSON” on GitHub URL?
  - Blob-Fix corrects it automatically.
  - Check: NoProfile, PowerShell 7, no module override, no direct HttpClient.
- PowerShell 7.6: fixed `Clone()` + alias conflicts.
- Missing icons? Nerd Font + Terminal-Icons.
- Preview without icons? Font in preview host.
- Low contrast? Run `Toggle-ThemeContrast`.

## 🏷️ Versioning & Releases
```powershell
git tag v1.3
git push origin main
git push origin v1.3
gh release create v1.3 --title "Version 1.3" --notes "Blob fix, self-test, README updated."
```

---

© 2025 Peter Auerbacher — MIT License
