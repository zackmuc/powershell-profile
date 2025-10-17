# 🖥️ PowerShell-Profil & Theme Manager (DE/EN)
> Persönliches PowerShell-Profil (pwsh 7) mit **oh-my-posh**, interaktivem **Theme-Manager**, Datei-/Ordner-**Icons** (Terminal-Icons), **automatischer GitHub-Blob→Raw-Korrektur**, sowie **Selbsttest** beim Start. Zweisprachige Doku – EN folgt unten.

<p align="left">
  <img alt="PowerShell" src="https://img.shields.io/badge/PowerShell-7.x-5391FE?logo=powershell&logoColor=white">
  <img alt="Oh My Posh" src="https://img.shields.io/badge/oh--my--posh-enabled-success">
  <img alt="Nerd Font" src="https://img.shields.io/badge/Nerd%20Font-required-informational">
  <img alt="License" src="https://img.shields.io/badge/License-MIT-blue">
</p>

## ✨ Features
- **Letztes Theme** wird beim Start geladen; Fallback auf **Default**, falls keins vorhanden ist.
- Interaktives Menü **`mythemes`**: Zahl → anwenden, **`pN`** → Preview, **`aN`** → Apply, **`c`/`q`** → abbrechen/beenden.
- **Eigene Themes** komfortabel **hinzufügen/entfernen** (JSON-basiert).
- **Icons** in `ls`/`Get-ChildItem` via **Terminal-Icons** (Auto-Import).
- **Preview** in neuem Fenster/Tab (ohne Profil), lädt Theme **und** Terminal-Icons.
- **Automatische GitHub-URL-Korrektur**: `github.com/.../blob/...` bzw. `.../refs/heads/...` wird bei HTTP-Requests zu `raw.githubusercontent.com/...` normalisiert (wir patchen **Invoke-WebRequest/Invoke-RestMethod**).
- **Selbsttest beim Start**: zeigt **„✅ Blob-Fix aktiv (Profil geladen)“**, wenn der Fix greift; sonst Warnung.
- Robuste Fehlerbehandlung, adaptive Farben, **High-Contrast-Toggle**.

## 📸 Screenshots
- Prompt & Menü: `Images/screenshot1.png`
- Optional (wenn genutzt): Bundesliga-Segment in einem Theme mit Live-/Next-Match für den **FC Bayern**.

## 🧩 Voraussetzungen
- **PowerShell 7** (getestet mit 7.6 Preview – Besonderheiten siehe Troubleshooting)
- **oh-my-posh**
- **Nerd Font** im Windows Terminal (z. B. *FiraCode Nerd Font Mono*)
- **Terminal-Icons** (einmalig installieren, Auto-Import im Profil):
```powershell
Install-Module Terminal-Icons -Scope CurrentUser
```

> Stelle im **Windows Terminal → PowerShell → Darstellung → Schriftart** deinen **Nerd Font** ein (z. B. *FiraCode Nerd Font Mono*), sonst fehlen die Icons.

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
### Custom Themes
- Datei: `%USERPROFILE%\.omp_custom_themes.json` (automatisch)  
- Felder: `Name`, `Url` (Akzeptiert **Raw-URLs** und **GitHub-Blob-Links** – letztere werden beim Abruf automatisch korrigiert)  
- Alternativ: `Add-CustomTheme` / `Remove-CustomTheme`

## 🧰 Troubleshooting
- **„Kein valides JSON“ bei GitHub-Link?**  
  Nutze **Raw**: `https://raw.githubusercontent.com/<user>/<repo>/<branch>/<path>.omp.json`  
  *Hinweis*: Durch den **Blob-Fix** werden `.../blob/...`-Links jetzt **automatisch** beim HTTP-Abruf korrigiert. Wenn das dennoch erscheint, prüfe:
  1) Startest du mit `pwsh -NoProfile`? (Dann wird das Profil nicht geladen.)  
  2) Lädst du **Windows PowerShell 5.1** statt **PowerShell 7**? (Anderes Profil.)  
  3) Überschreibt ein Modul nachträglich `Invoke-WebRequest`/`Invoke-RestMethod`?  
  4) Nutzt ein Tool direkten **HttpClient** statt PowerShell-Cmdlets? (Dann hilft ein Pre-Fetch über das Profil, z. B. in eine ENV-Variable.)
- **PowerShell 7.6 Preview:**
  - `PSBoundParameters.Clone()` ist dort nicht verfügbar → im Profil durch **manuelle Kopie** ersetzt.
  - Alias-Konflikt `Uri` behoben (Alias nur noch `U`).  
- **Icons fehlen?** Nerd Font aktiv? `Terminal-Icons` installiert/geladen?
- **Preview ohne Icons?** Preview lädt Terminal-Icons explizit; achte auf Nerd-Font im Preview-Host.
- **Niedriger Kontrast?** `Toggle-ThemeContrast` ausführen.

## 🏷️ Versionierung & Releases
- Tags: `v1.0`, `v1.1`, …  
- Releases: GitHub → **Releases**

**Neuen Release (z. B. v1.2) anlegen**
```powershell
git tag v1.2
git push origin v1.2

# GitHub-CLI (empfohlen)
gh release create v1.2 `
  --title "Version 1.2" `
  --notes "DE: Blob-Fix (GitHub-Blob→Raw), Selbsttest, Doku aktualisiert.
EN: Blob fix (GitHub blob→raw), self-test, updated docs."
# Optional Datei anhängen:
# gh release create v1.2 Microsoft.PowerShell_profile.ps1 --title "Version 1.2" --notes "..."
```

---

# 🖥️ PowerShell Profile & Theme Manager (EN)
> Personal PowerShell profile (pwsh 7) with **oh-my-posh**, interactive **theme manager**, file/folder **icons** (Terminal-Icons), an **automatic GitHub blob→raw correction**, and a **startup self-test**.

<p align="left">
  <img alt="PowerShell" src="https://img.shields.io/badge/PowerShell-7.x-5391FE?logo=powershell&logoColor=white">
  <img alt="Oh My Posh" src="https://img.shields.io/badge/oh--my--posh-enabled-success">
  <img alt="Nerd Font" src="https://img.shields.io/badge/Nerd%20Font-required-informational">
  <img alt="License" src="https://img.shields.io/badge/License-MIT-blue">
</p>

## ✨ Features
- **Load last theme** at startup; fallback to **default** otherwise.
- Interactive menu **`mythemes`**: number → apply, **`pN`** → preview, **`aN`** → apply, **`c`/`q`** → cancel/quit.
- **Custom themes**: easily **add/remove** (JSON-based).
- **Icons** in `ls`/`Get-ChildItem` via **Terminal-Icons** (auto-import).
- **Preview** in a new window/tab (no profile), loads theme **and** Terminal-Icons.
- **Automatic GitHub URL correction**: `github.com/.../blob/...` and `.../refs/heads/...` are normalized to `raw.githubusercontent.com/...` when performing HTTP requests (we hook **Invoke-WebRequest/Invoke-RestMethod**).
- **Startup self-test**: prints **“✅ Blob-Fix aktiv (Profil geladen)”** / “Blob-Fix active (profile loaded)” if hooked; otherwise a warning.
- Robust error handling, adaptive colors, **high contrast toggle**.

## 📸 Screenshots
- Prompt & menu: `Images/screenshot1.png`
- Optional: Bundesliga segment in a theme (FC Bayern live/next match via OpenLigaDB).

## 🧩 Requirements
- **PowerShell 7** (tested with 7.6 Preview — see Troubleshooting)
- **oh-my-posh**
- **Nerd Font** in Windows Terminal (e.g., *FiraCode Nerd Font Mono*)
- **Terminal-Icons** (install once; auto-imported):
```powershell
Install-Module Terminal-Icons -Scope CurrentUser
```

> In **Windows Terminal → PowerShell → Appearance → Font**, choose your **Nerd Font** (e.g., *FiraCode Nerd Font Mono*), otherwise icons won’t render.

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
mythemes
3
p3
a3
q
```
### Custom themes
- File: `%USERPROFILE%\.omp_custom_themes.json` (auto)  
- Fields: `Name`, `Url` (accepts **raw** and **blob** GitHub links — blob gets **auto-corrected** on fetch)  
- Alternatively: `Add-CustomTheme` / `Remove-CustomTheme`

## 🧰 Troubleshooting
- **“Not valid JSON” with GitHub URL?**  
  Prefer **Raw**: `https://raw.githubusercontent.com/<user>/<repo>/<branch>/<path>.omp.json`  
  *Note*: With the **blob fix**, `.../blob/...` now gets **auto-corrected** during HTTP fetch. If it still fails, verify:
  1) Are you running with `pwsh -NoProfile`? (Fix isn’t loaded.)  
  2) Are you in **Windows PowerShell 5.1** instead of **PowerShell 7**? (Different profile.)  
  3) A module overrides `Invoke-WebRequest`/`Invoke-RestMethod` later?  
  4) A tool uses **HttpClient** directly (bypassing PowerShell cmdlets)?
- **PowerShell 7.6 Preview:**
  - Replaced `PSBoundParameters.Clone()` with a manual parameter copy.
  - Removed `Uri` alias conflict (only `'U'` alias kept).  
- **Missing icons?** Nerd Font enabled and Terminal-Icons installed/loaded?
- **Preview without icons?** Preview explicitly imports Terminal-Icons; ensure preview host uses Nerd Font.
- **Low contrast?** Run `Toggle-ThemeContrast`.

## 🏷️ Versioning & Releases
- Tags: `v1.0`, `v1.1`, …  
- Releases: GitHub → **Releases**

**Create a new release (e.g., v1.2)**
```powershell
git tag v1.2
git push origin v1.2

# GitHub-CLI (recommended)
gh release create v1.2 `
  --title "Version 1.2" `
  --notes "DE: Blob fix, self-test, docs updated.
EN: Blob fix, self-test, docs updated."
# Optionally attach a file:
# gh release create v1.2 Microsoft.PowerShell_profile.ps1 --title "Version 1.2" --notes "..."
```

---

© 2025 Peter Auerbacher — MIT License
