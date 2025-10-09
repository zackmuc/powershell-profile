# =============================
#  PowerShell Profile (pwsh 7) — Oh My Posh Theme Manager
#  DE: Professioneller Theme-Manager mit Vorschau im neuen Fenster
#  EN: Professional theme manager with preview in a new window
#  Features: Add/Remove (1/2), p/a/Enter/c/q, pN/aN shortcuts, adaptive colors
#  Uses: oh-my-posh init pwsh --config <URL> --eval | Invoke-Expression
#  Version: 1.1.0  (Icons enabled in normal + preview windows)
# =============================

# -----------------------------
# Persistenz: Pfade & Dateien
# Persistence: paths & files
# -----------------------------
$LastThemeFile    = "$env:USERPROFILE\.omp_last_theme.txt"     # DE: Zuletzt verwendete Theme-URL / EN: Last used theme URL
$CustomThemesFile = "$env:USERPROFILE\.omp_custom_themes.json" # DE: Eigene Themes als JSON / EN: Custom themes as JSON

if (-not (Test-Path $CustomThemesFile)) {
    @() | ConvertTo-Json | Set-Content -Path $CustomThemesFile -Encoding utf8
}

# -----------------------------
# UI / Farben (adaptiv + manuell)
# UI / Colors (adaptive + manual)
# -----------------------------
$ThemeUI = [ordered]@{
    HighContrast    = $false
    BgColor         = $Host.UI.RawUI.BackgroundColor
    ColorHeader     = 'Cyan'
    ColorHeaderLine = 'DarkCyan'
    ColorSection    = 'Gray'
    ColorBuiltIn    = 'Cyan'
    ColorCustom     = 'Yellow'
    ColorAction     = 'Gray'
    ColorOK         = 'Green'
    ColorWarn       = 'Yellow'
    ColorInfo       = 'Gray'
    ColorErr        = 'Red'
}

# -----------------------------
# UI-Farben initialisieren
# Initialize UI colors
# -----------------------------
function Initialize-ThemeManagerColors {
    <#
      DE: Ermittelt grob dunkel/hell anhand Konsolenhintergrund und setzt Kontrastfarben.
      EN: Detects dark/light background and sets contrast colors accordingly.
    #>
    $darkSet = [System.Collections.Generic.HashSet[ConsoleColor]]::new()
    @('Black','DarkBlue','DarkGreen','DarkCyan','DarkRed','DarkMagenta','DarkYellow','DarkGray') |
        ForEach-Object { [void]$darkSet.Add([ConsoleColor]::Parse([ConsoleColor], $_)) }

    $isDark = $true
    try { $isDark = $darkSet.Contains($ThemeUI.BgColor) } catch {}

    if ($ThemeUI.HighContrast) {
        $ThemeUI.ColorHeader     = 'White'
        $ThemeUI.ColorHeaderLine = 'DarkGray'
        $ThemeUI.ColorSection    = 'White'
        $ThemeUI.ColorBuiltIn    = 'White'
        $ThemeUI.ColorCustom     = 'White'
        $ThemeUI.ColorAction     = 'White'
        $ThemeUI.ColorOK         = 'Green'
        $ThemeUI.ColorWarn       = 'Yellow'
        $ThemeUI.ColorInfo       = 'White'
        $ThemeUI.ColorErr        = 'Red'
        return
    }

    if ($isDark) {
        $ThemeUI.ColorHeader     = 'Cyan'
        $ThemeUI.ColorHeaderLine = 'DarkCyan'
        $ThemeUI.ColorSection    = 'Gray'
        $ThemeUI.ColorBuiltIn    = 'Cyan'
        $ThemeUI.ColorCustom     = 'Yellow'
        $ThemeUI.ColorAction     = 'Gray'
        $ThemeUI.ColorOK         = 'Green'
        $ThemeUI.ColorWarn       = 'Yellow'
        $ThemeUI.ColorInfo       = 'Gray'
        $ThemeUI.ColorErr        = 'Red'
    } else {
        $ThemeUI.ColorHeader     = 'DarkBlue'
        $ThemeUI.ColorHeaderLine = 'Blue'
        $ThemeUI.ColorSection    = 'DarkGray'
        $ThemeUI.ColorBuiltIn    = 'DarkBlue'
        $ThemeUI.ColorCustom     = 'DarkYellow'
        $ThemeUI.ColorAction     = 'DarkGray'
        $ThemeUI.ColorOK         = 'DarkGreen'
        $ThemeUI.ColorWarn       = 'DarkYellow'
        $ThemeUI.ColorInfo       = 'DarkGray'
        $ThemeUI.ColorErr        = 'DarkRed'
    }
}
Initialize-ThemeManagerColors

# -----------------------------
# UI / Ausgabetools
# UI / Output helpers
# -----------------------------
function Show-Header {
    param([string]$Title)
    $line = "────────────────────────────────────────────────────────"
    Write-Host ""
    Write-Host "┌$line┐" -ForegroundColor $ThemeUI.ColorHeaderLine
    Write-Host ("│ {0,-54} │" -f $Title) -ForegroundColor $ThemeUI.ColorHeader
    Write-Host "└$line┘" -ForegroundColor $ThemeUI.ColorHeaderLine
}
function Show-Section { param([string]$Text) Write-Host ("[{0}]" -f $Text) -ForegroundColor $ThemeUI.ColorSection }
function Show-Ok     { param([string]$t)   Write-Host "✅ $t" -ForegroundColor $ThemeUI.ColorOK }
function Show-Warn   { param([string]$t)   Write-Host "⚠️  $t" -ForegroundColor $ThemeUI.ColorWarn }
function Show-Info   { param([string]$t)   Write-Host "ℹ️  $t" -ForegroundColor $ThemeUI.ColorInfo }
function Show-Err    { param([string]$t)   Write-Host "❌ $t" -ForegroundColor $ThemeUI.ColorErr }

# -----------------------------
# Kontrast-Umschalter
# Contrast toggle
# -----------------------------
function Toggle-ThemeContrast {
    <#
      DE: Schaltet HighContrast an/aus und initialisiert Farben neu.
      EN: Toggles HighContrast and re-initializes colors.
    #>
    $ThemeUI.HighContrast = -not $ThemeUI.HighContrast
    Initialize-ThemeManagerColors
    Show-Info ("HighContrast ist jetzt: {0}" -f ($ThemeUI.HighContrast ? 'On' : 'Off'))
}

# -----------------------------
# Terminal-Icons Auto-Import
# Terminal-Icons auto import (file/folder glyphs)
# -----------------------------
function Ensure-TerminalIcons {
    <#
      DE: Importiert das Modul 'Terminal-Icons', falls vorhanden. Gibt Hinweis zur Installation.
      EN: Imports 'Terminal-Icons' module if available. Prints installation hint otherwise.
    #>
    if (Get-Module -ListAvailable -Name 'Terminal-Icons') {
        try { Import-Module 'Terminal-Icons' -ErrorAction Stop } catch {}
    } else {
        Write-Host "ℹ️  Hinweis/Note: Modul 'Terminal-Icons' nicht installiert. Install via:" -ForegroundColor Yellow
        Write-Host "    Install-Module Terminal-Icons -Scope CurrentUser" -ForegroundColor Yellow
    }
}

# -----------------------------
# URL-Helfer (Gist → Raw)
# URL helper (Gist → Raw)
# -----------------------------
function Fix-ThemeUrl {
    param([string]$Url)
    if ([string]::IsNullOrWhiteSpace($Url)) { return $Url }
    $u = $Url.Trim()
    if ($u -match '^https://gist\.github\.com/([^/]+)/([0-9a-fA-F]+)') {
        $user = $matches[1]; $id = $matches[2]
        return "https://gist.githubusercontent.com/$user/$id/raw"
    }
    return $u
}

# -----------------------------
# URL-Validierung
# URL validation
# -----------------------------
function Test-ThemeUrl {
    param([Parameter(Mandatory)][string]$Url)
    try {
        $resp = Invoke-WebRequest -Uri $Url -ErrorAction Stop
        if (-not $resp.Content) { throw "Leere Antwort / Empty response" }
        try { $null = $resp.Content | ConvertFrom-Json } catch { throw "Kein valides JSON / Not valid JSON" }
        return $true
    } catch {
        Show-Warn "Ungültige Theme-URL: $($_.Exception.Message)"
        return $false
    }
}

# -----------------------------
# Theme laden (Apply) + Icons
# Load theme (apply) + icons
# -----------------------------
function Load-Theme {
    <#
      DE: Lädt ein Oh-My-Posh-Theme für die aktuelle Session, importiert Icons
          und speichert die URL als 'zuletzt verwendet'.
      EN: Loads an Oh My Posh theme for the current session, imports icons,
          and stores the URL as 'last used'.
    #>
    param([Parameter(Mandatory)][string]$ThemeUrl)

    $ThemeUrl = Fix-ThemeUrl $ThemeUrl
    if (-not (Test-ThemeUrl $ThemeUrl)) { throw "Theme nicht erreichbar oder kein gültiges JSON." }

    # Prompt setzen / Set prompt
    oh-my-posh init pwsh --config $ThemeUrl --eval | Invoke-Expression

    # Icons aktivieren / Enable icons
    Ensure-TerminalIcons

    # Zuletzt genutztes Theme sichern / Persist last used theme
    $ThemeUrl | Out-File -FilePath $LastThemeFile -Encoding utf8
    Show-Ok "Theme geladen / applied: $ThemeUrl"
}

# -----------------------------
# Preview im neuen Fenster (+ Icons)
# Preview in new window (+ icons)
# -----------------------------
function Preview-Theme {
    <#
      DE: Startet neues pwsh-Fenster ohne Profil, lädt Theme + Terminal-Icons
          und zeigt eine Statuszeile mit gutem Kontrast.
      EN: Starts a new pwsh window without profile, loads theme + Terminal-Icons,
          and prints a high-contrast status line.
    #>
    param([Parameter(Mandatory)][string]$ThemeUrl)

    $ThemeUrl = Fix-ThemeUrl $ThemeUrl
    if (-not (Test-ThemeUrl $ThemeUrl)) { Show-Warn "Preview abgebrochen (URL ungültig)."; return }

    # URL sicher quoten / safely escape URL
    $escUrl = $ThemeUrl.Replace('`','``').Replace('"','`"')

    # Kinderkommando / child command
    $cmd =
        "oh-my-posh init pwsh --config `"$escUrl`" --eval | Invoke-Expression; " +
        "if (Get-Module -ListAvailable -Name 'Terminal-Icons') { Import-Module 'Terminal-Icons' }; " +
        "`$fg='Yellow'; " +
        "try { `$bg=`$Host.UI.RawUI.BackgroundColor; " +
        "  if (@([ConsoleColor]::Black,[ConsoleColor]::DarkBlue,[ConsoleColor]::DarkGreen,[ConsoleColor]::DarkCyan,[ConsoleColor]::DarkRed,[ConsoleColor]::DarkMagenta,[ConsoleColor]::DarkYellow,[ConsoleColor]::DarkGray) -contains `$bg) { `$fg='Yellow' } else { `$fg='DarkBlue' } } catch {}; " +
        "Write-Host '🔍 Preview aktiv. Fenster schließen (X/exit) … / Close this window to return.' -ForegroundColor `$fg"

    try {
        # Hinweis: Mit Windows Terminal als Standard öffnet sich ein neuer Tab.
        # Note: If Windows Terminal is default, this opens a new tab.
        Start-Process -FilePath "pwsh" -ArgumentList @("-NoProfile","-NoExit","-NoLogo","-Command",$cmd) | Out-Null
        Show-Info "Preview-Fenster geöffnet / Preview window opened. Nach dem Schließen hier entscheiden."
    } catch {
        Show-Err "Konnte Preview-Fenster nicht starten / Failed to start preview: $_"
    }
}

# -----------------------------
# Custom-Themes laden
# Load custom themes
# -----------------------------
function Load-CustomThemes {
    <#
      DE: Liest JSON-Datei und liefert Objekte { Name, Url }.
      EN: Reads JSON file and returns objects { Name, Url }.
    #>
    if (Test-Path $CustomThemesFile) {
        try { return Get-Content $CustomThemesFile -Raw | ConvertFrom-Json }
        catch { Show-Err "Konnte Custom-Themes nicht lesen / Failed to read custom themes (JSON)."; return @() }
    } else { return @() }
}

# -----------------------------
# Custom-Themes speichern
# Save custom themes
# -----------------------------
function Save-CustomThemes {
    <#
      DE: Speichert Liste (nach Name sortiert) zurück nach JSON.
      EN: Saves list (sorted by Name) back to JSON.
    #>
    param([Parameter(Mandatory)][array]$CustomThemes)
    ($CustomThemes | Sort-Object Name) | ConvertTo-Json | Set-Content -Path $CustomThemesFile -Encoding utf8
}

# -----------------------------
# Custom-Theme hinzufügen
# Add custom theme
# -----------------------------
function Add-CustomTheme {
    <#
      DE: Erfragt Name & URL, validiert und speichert.
      EN: Prompts for name & URL, validates and saves.
    #>
    param([string]$Url)

    if (-not $Url) { $Url = Read-Host "Theme-URL (JSON) eingeben / enter URL" }
    $Url = Fix-ThemeUrl $Url
    if (-not (Test-ThemeUrl $Url)) { return $null }

    $name = Read-Host "Name für das Theme / name for the theme"
    if ([string]::IsNullOrWhiteSpace($name)) { Show-Warn "Kein Name / No name."; return $null }

    $list = @(Load-CustomThemes)
    $list += [PSCustomObject]@{ Name = $name; Url = $Url }
    Save-CustomThemes $list
    Show-Ok "Theme hinzugefügt / added: '$name'"
    return @{ Name = $name; Url = $Url }
}

# -----------------------------
# Custom-Theme entfernen
# Remove custom theme
# -----------------------------
function Remove-CustomTheme {
    <#
      DE: Zeigt nummerierte Liste & löscht Auswahl.
      EN: Shows numbered list & deletes the chosen one.
    #>
    $list = @(Load-CustomThemes)
    if (-not $list -or $list.Count -eq 0) { Show-Warn "Keine Custom-Themes vorhanden / No custom themes."; return }

    Show-Header "Custom-Theme löschen / delete custom theme"
    $i = 0
    $list | ForEach-Object { $script:i++; Write-Host ("  {0,2}) {1}" -f $i, $_.Name) -ForegroundColor DarkYellow }
    $pick = Read-Host "Nummer (oder Enter=Abbruch) / number (Enter=cancel)"
    if ($pick -as [int] -and $pick -ge 1 -and $pick -le $list.Count) {
        $name = $list[$pick-1].Name
        $list = $list | Where-Object { $_.Name -ne $name }
        Save-CustomThemes $list
        Show-Warn "'$name' gelöscht / deleted."
    }
}

# -----------------------------
# Menü: mythemes (interaktiv)
# Menu: mythemes (interactive)
# -----------------------------
function mythemes {
    <#
      DE:
        - 1 = Hinzufügen, 2 = Entfernen
        - Zahl → dann p/a/Enter/c/q
        - Kürzel: pN (Preview von N), aN (Apply von N)
        - Nach Apply (Enter/a) wird das Menü beendet
      EN:
        - 1 = add, 2 = remove
        - number → then p/a/Enter/c/q
        - shortcuts: pN (preview N), aN (apply N)
        - after apply (Enter/a) the menu exits
    #>
    $builtIn = @(
        @{ Name='A-Retro-Fade';         Url='https://gist.githubusercontent.com/zackmuc/321d436943f6be6e15ccc21f3d5a96df/raw/901b6ba5bb212d3115b1fb388d0508c7c3a753ea/a-retro-fade.omp.json' }
        @{ Name='M365Princess';         Url='https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/M365Princess.omp.json' }
        @{ Name='Amro';                 Url='https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/amro.omp.json' }
        @{ Name='Jandedobbeleer';       Url='https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/jandedobbeleer.omp.json' }
        @{ Name='Powerlevel10kRainbow'; Url='https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/powerlevel10k_rainbow.omp.json' }
        @{ Name='Paradox';              Url='https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/paradox.omp.json' }
    )

    while ($true) {
        Clear-Host
        Show-Header "Theme-Manager / theme manager"

        $options = New-Object System.Collections.Generic.List[Hashtable]

        # Aktionen / actions
        Write-Host ("  {0,2}) {1}" -f 1, "➕ Custom-Theme hinzufügen / add custom theme") -ForegroundColor $ThemeUI.ColorAction
        Write-Host ("  {0,2}) {1}" -f 2, "🗑️  Custom-Theme entfernen / remove custom theme") -ForegroundColor $ThemeUI.ColorAction
        $options.Add(@{ Kind='Action'; Name='Add';    Url=$null })
        $options.Add(@{ Kind='Action'; Name='Remove'; Url=$null })

        # Eingebaute Themes / built-ins
        Show-Section "Eingebaute Themes / built-in themes"
        $n = $options.Count
        foreach ($t in $builtIn) {
            $n++
            $options.Add(@{ Kind='BuiltIn'; Name=$t.Name; Url=$t.Url })
            Write-Host ("  {0,2}) {1}" -f $n, $t.Name) -ForegroundColor $ThemeUI.ColorBuiltIn
        }

        # Eigene Themes / custom
        $custom = @(Load-CustomThemes)
        if ($custom.Count -gt 0) {
            Show-Section "Eigene Themes / custom themes"
            foreach ($t in $custom) {
                $n++
                $options.Add(@{ Kind='Custom'; Name=$t.Name; Url=$t.Url })
                Write-Host ("  {0,2}) {1}" -f $n, $t.Name) -ForegroundColor $ThemeUI.ColorCustom
            }
        }

        Write-Host ""
        $choice = Read-Host "Zahl / p<Zahl> (Preview) / a<Zahl> (Apply) / q (Quit)"
        if ($choice -match '^\s*q\s*$') { break }

        # Direkt pN / aN
        if ($choice -match '^\s*p(\d+)\s*$') {
            $idx = [int]$matches[1]
            if ($idx -ge 1 -and $idx -le $options.Count -and $options[$idx-1].Kind -ne 'Action') {
                $sel = $options[$idx-1]
                Preview-Theme $sel.Url
                $after = Read-Host "Preview fertig. Übernehmen (a/Enter) oder Abbrechen (c)? / After preview: apply (a/Enter) or cancel (c)?"
                if ([string]::IsNullOrWhiteSpace($after) -or $after -match '^\s*a\s*$') { try { Load-Theme $sel.Url } catch { Show-Err $_ }; break }
                else { continue }
            } else { Show-Warn "Ungültiger Index / invalid index." ; Start-Sleep -Milliseconds 600; continue }
        }
        if ($choice -match '^\s*a(\d+)\s*$') {
            $idx = [int]$matches[1]
            if ($idx -ge 1 -and $idx -le $options.Count -and $options[$idx-1].Kind -ne 'Action') {
                $sel = $options[$idx-1]
                try { Load-Theme $sel.Url } catch { Show-Err $_ }
                break
            } else { Show-Warn "Ungültiger Index / invalid index." ; Start-Sleep -Milliseconds 600; continue }
        }

        # Normale Zahl
        if (-not ($choice -as [int])) { Show-Warn "Bitte Zahl eingeben / please enter a number."; Start-Sleep -Milliseconds 600; continue }
        $pick = [int]$choice
        if ($pick -lt 1 -or $pick -gt $options.Count) { Show-Warn "Nummer außerhalb der Liste / out of range."; Start-Sleep -Milliseconds 600; continue }

        $sel = $options[$pick-1]

        # Aktionen 1/2
        if ($sel.Kind -eq 'Action') {
            if     ($pick -eq 1) { Add-CustomTheme | Out-Null }
            elseif ($pick -eq 2) { Remove-CustomTheme }
            Read-Host "Weiter mit Enter / press Enter to continue"
            continue
        }

        # Schritt 2
        Show-Section ("Ausgewählt / selected: {0}" -f $sel.Name)
        $action = Read-Host "Aktion: Preview (p), Apply (a/Enter), Cancel (c), Quit (q)"
        if     ($action -match '^\s*q\s*$') { break }
        elseif ($action -match '^\s*c\s*$') { continue }
        elseif ($action -match '^\s*p\s*$') {
            Preview-Theme $sel.Url
            $after = Read-Host "Preview fertig. Übernehmen (a/Enter) oder Abbrechen (c)? / After preview: apply (a/Enter) or cancel (c)?"
            if ([string]::IsNullOrWhiteSpace($after) -or $after -match '^\s*a\s*$') { try { Load-Theme $sel.Url } catch { Show-Err $_ }; break }
            else { continue }
        }
        else {
            try { Load-Theme $sel.Url } catch { Show-Err $_ }
            break
        }
    }
}

# -----------------------------
# Startverhalten (Default/Last)
# Startup behavior (default/last)
# -----------------------------
$DefaultTheme = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/M365Princess.omp.json"

if (Test-Path $LastThemeFile) {
    $last = Get-Content $LastThemeFile -Raw
    try {
        Load-Theme $last
        Show-Info "Zuletzt geladenes Theme / last loaded theme: $last"
    } catch {
        Show-Warn "Konnte letztes Theme nicht laden. Nutze Default. / Failed to load last theme, using default."
        try { Load-Theme $DefaultTheme } catch {}
    }
} else {
    try { Load-Theme $DefaultTheme } catch {}
}

Show-Info "Tipp/Tip: 'mythemes' → Zahl / p<Zahl> / a<Zahl> → (a/Enter) anwenden, (c) abbrechen, (q) beenden."
Show-Info "Eigene Themes / custom: Add-CustomTheme / Remove-CustomTheme"
