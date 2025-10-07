# =============================
#  PowerShell Profile (pwsh 7)
#  Professioneller Theme-Manager mit Preview im neuen Fenster
#  Features: Add/Remove (1/2), p/a/Enter/c/q, pN/aN-Kürzel, adaptive Farben
#  Nutzt: oh-my-posh init pwsh --config <URL> --eval | Invoke-Expression
# =============================

# -----------------------------
# Persistenz: Pfade & Dateien
# -----------------------------
# Merkt sich die zuletzt geladene Theme-URL (wird beim Start wiederhergestellt).
$LastThemeFile    = "$env:USERPROFILE\.omp_last_theme.txt"
# JSON-Datei für eigene Themes (Array aus Objekten mit { Name, Url }).
$CustomThemesFile = "$env:USERPROFILE\.omp_custom_themes.json"

# Falls die Custom-Themes-Datei fehlt, leeres Array anlegen.
if (-not (Test-Path $CustomThemesFile)) {
    @() | ConvertTo-Json | Set-Content -Path $CustomThemesFile -Encoding utf8
}

# -----------------------------
# UI / Farben (adaptiv + manuell)
# -----------------------------
# Steuert die Farben der Ausgaben. Nutzt den Konsolen-Hintergrund, um Kontrast zu wählen.
# Hinweis: In Windows Terminal ist $Host.UI.RawUI.BackgroundColor nicht transparent-aware.
# Deshalb gibt es den HighContrast-Schalter für harte Kontraste.
$ThemeUI = [ordered]@{
    HighContrast    = $false   # Bei Bedarf $true setzen → starke Kontraste erzwingen
    BgColor         = $Host.UI.RawUI.BackgroundColor
    ColorHeader     = 'Cyan'
    ColorHeaderLine = 'DarkCyan'
    ColorSection    = 'Gray'
    ColorBuiltIn    = 'Cyan'
    ColorCustom     = 'Yellow'
    ColorAction     = 'Gray'
    ColorOK         = 'Green'
    ColorWarn       = 'Yellow'
    ColorInfo       = 'Gray'       # <- heller gemacht (vorher DarkGray)
    ColorErr        = 'Red'
}

# -----------------------------
# UI / Farben initialisieren
# -----------------------------
function Initialize-ThemeManagerColors {
    # Ermittelt (grob), ob dunkler/heller Hintergrund vorliegt und setzt passende Farben.
    # Bei HighContrast werden helle Akzente erzwungen (unabhängig vom Hintergrund).
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
        # Dunkler Hintergrund → helle, kräftige Akzente
        $ThemeUI.ColorHeader     = 'Cyan'
        $ThemeUI.ColorHeaderLine = 'DarkCyan'
        $ThemeUI.ColorSection    = 'Gray'
        $ThemeUI.ColorBuiltIn    = 'Cyan'
        $ThemeUI.ColorCustom     = 'Yellow'
        $ThemeUI.ColorAction     = 'Gray'
        $ThemeUI.ColorOK         = 'Green'
        $ThemeUI.ColorWarn       = 'Yellow'
        $ThemeUI.ColorInfo       = 'Gray'     # <- hell genug auf dunklem Hintergrund
        $ThemeUI.ColorErr        = 'Red'
    } else {
        # Heller Hintergrund → dunklere Akzente
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
# UI / Ausgabetools (Header, Status)
# -----------------------------
function Show-Header {
    # Zeichnet einen formatierten Header mit Rahmen und Titel.
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
# High-Contrast Toggle (Schnellumschalter)
# -----------------------------
function Toggle-ThemeContrast {
    # Wechselt HighContrast an/aus, initialisiert Farben neu und zeigt Status.
    $ThemeUI.HighContrast = -not $ThemeUI.HighContrast
    Initialize-ThemeManagerColors
    Show-Info ("HighContrast ist jetzt: {0}" -f ($ThemeUI.HighContrast ? 'On' : 'Off'))
}

# -----------------------------
# URL-Helfer (z. B. Gist → Raw)
# -----------------------------
function Fix-ThemeUrl {
    # Normalisiert eingegebene URLs:
    # - trimmt Leerzeichen
    # - wandelt "https://gist.github.com/<user>/<id>" in "https://gist.githubusercontent.com/<user>/<id>/raw" um
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
# URL-Validierung (Erreichbarkeit & JSON)
# -----------------------------
function Test-ThemeUrl {
    # Prüft, ob die URL erreichbar ist und JSON liefert.
    # Liefert $true bei Erfolg, sonst $false und zeigt einen Hinweis.
    param([Parameter(Mandatory)][string]$Url)
    try {
        $resp = Invoke-WebRequest -Uri $Url -ErrorAction Stop
        if (-not $resp.Content) { throw "Leere Antwort" }
        try { $null = $resp.Content | ConvertFrom-Json } catch { throw "Kein valides JSON" }
        return $true
    } catch {
        Show-Warn "Ungültige Theme-URL: $($_.Exception.Message)"
        return $false
    }
}

# -----------------------------
# Theme laden (Apply)
# -----------------------------
function Load-Theme {
    # Lädt ein Oh-My-Posh-Theme zuverlässig für die aktuelle Session:
    # offizielle Initialisierung mit --eval + Invoke-Expression.
    # Persistiert die URL in $LastThemeFile.
    param([Parameter(Mandatory)][string]$ThemeUrl)

    $ThemeUrl = Fix-ThemeUrl $ThemeUrl
    if (-not (Test-ThemeUrl $ThemeUrl)) { throw "Theme nicht erreichbar oder kein gültiges JSON." }

    oh-my-posh init pwsh --config $ThemeUrl --eval | Invoke-Expression

    $ThemeUrl | Out-File -FilePath $LastThemeFile -Encoding utf8
    Show-Ok "Theme geladen: $ThemeUrl"
}

# -----------------------------
# Preview im neuen Fenster (-NoProfile)
# -----------------------------
function Preview-Theme {
    # Öffnet ein neues pwsh-Fenster (ohne Profil), lädt dort das Theme,
    # zeigt einen gut lesbaren Hinweis (adaptive Farbe) und lässt das Fenster offen.
    # Nach dem Schließen entscheidet der Benutzer im Hauptfenster, ob angewendet wird.
    param([Parameter(Mandatory)][string]$ThemeUrl)

    $ThemeUrl = Fix-ThemeUrl $ThemeUrl
    if (-not (Test-ThemeUrl $ThemeUrl)) { Show-Warn "Preview abgebrochen (URL ungültig)."; return }

    # URL sicher für eingebettetes Kommando quoten
    $escUrl = $ThemeUrl.Replace('`','``').Replace('"','`"')

    # Kinderfenster ohne Profil: verhindert Startmeldungen/Alttheme
    # Adaptive Lesefarbe (hell/dunkel) für die Statuszeile im Preview-Fenster
    $cmd =
        "oh-my-posh init pwsh --config `"$escUrl`" --eval | Invoke-Expression; " +
        "`$fg='Yellow'; " +
        "try { " +
        "  `$bg=`$Host.UI.RawUI.BackgroundColor; " +
        "  if (@([ConsoleColor]::Black,[ConsoleColor]::DarkBlue,[ConsoleColor]::DarkGreen,[ConsoleColor]::DarkCyan,[ConsoleColor]::DarkRed,[ConsoleColor]::DarkMagenta,[ConsoleColor]::DarkYellow,[ConsoleColor]::DarkGray) -contains `$bg) { `$fg='Yellow' } else { `$fg='DarkBlue' } " +
        "} catch {}; " +
        "Write-Host '🔍 Preview aktiv. Fenster schließen (X/exit), um zurückzukehren.' -ForegroundColor `$fg"

    try {
        Start-Process -FilePath "pwsh" -ArgumentList @("-NoProfile","-NoExit","-NoLogo","-Command",$cmd) | Out-Null
        Show-Info "Preview-Fenster geöffnet. Nach dem Schließen entscheidest du hier."
    } catch {
        Show-Err "Konnte Preview-Fenster nicht starten: $_"
    }
}

# -----------------------------
# Custom-Themes laden (JSON lesen)
# -----------------------------
function Load-CustomThemes {
    # Liest die JSON-Datei und gibt ein Array von Objekten { Name, Url } zurück.
    # Bei Fehlern wird ein leeres Array geliefert und eine Fehlermeldung ausgegeben.
    if (Test-Path $CustomThemesFile) {
        try { return Get-Content $CustomThemesFile -Raw | ConvertFrom-Json }
        catch { Show-Err "Konnte Custom-Themes nicht lesen (defektes JSON)."; return @() }
    } else { return @() }
}

# -----------------------------
# Custom-Themes speichern (JSON schreiben)
# -----------------------------
function Save-CustomThemes {
    # Speichert die Liste (nach Name sortiert) wieder in die JSON-Datei.
    param([Parameter(Mandatory)][array]$CustomThemes)
    ($CustomThemes | Sort-Object Name) | ConvertTo-Json | Set-Content -Path $CustomThemesFile -Encoding utf8
}

# -----------------------------
# Custom-Theme hinzufügen (interaktiv)
# -----------------------------
function Add-CustomTheme {
    # Fragt URL & Name ab, validiert die URL, speichert den Eintrag.
    # Rückgabe: Hashtable { Name, Url } oder $null.
    param([string]$Url)

    if (-not $Url) { $Url = Read-Host "Theme-URL (JSON) eingeben" }
    $Url = Fix-ThemeUrl $Url
    if (-not (Test-ThemeUrl $Url)) { return $null }

    $name = Read-Host "Name für das Theme"
    if ([string]::IsNullOrWhiteSpace($name)) { Show-Warn "Kein Name eingegeben."; return $null }

    $list = @(Load-CustomThemes)
    $list += [PSCustomObject]@{ Name = $name; Url = $Url }
    Save-CustomThemes $list
    Show-Ok "Theme '$name' hinzugefügt."
    return @{ Name = $name; Url = $Url }
}

# -----------------------------
# Custom-Theme entfernen (interaktiv)
# -----------------------------
function Remove-CustomTheme {
    # Zeigt nummerierte Liste der Einträge und löscht die gewählte Nummer.
    $list = @(Load-CustomThemes)
    if (-not $list -or $list.Count -eq 0) { Show-Warn "Keine Custom-Themes vorhanden."; return }

    Show-Header "Custom-Theme löschen"
    $i = 0
    $list | ForEach-Object { $script:i++; Write-Host ("  {0,2}) {1}" -f $i, $_.Name) -ForegroundColor DarkYellow }
    $pick = Read-Host "Nummer (oder Enter zum Abbrechen)"
    if ($pick -as [int] -and $pick -ge 1 -and $pick -le $list.Count) {
        $name = $list[$pick-1].Name
        $list = $list | Where-Object { $_.Name -ne $name }
        Save-CustomThemes $list
        Show-Warn "'$name' gelöscht."
    }
}

# -----------------------------
# Menü: mythemes (interaktiv)
# -----------------------------
function mythemes {
    # Interaktiver Manager mit:
    # - 1 = Add, 2 = Remove
    # - Danach eingebaute Themes (Cyan) und eigene Themes (Gelb)
    # - Zahl → dann p/a/Enter/c/q
    # - Direktkürzel: pN (Preview von N), aN (Apply von N)
    # Nach Apply (Enter/a) wird das Menü beendet.

    # Eingebaute Themes (deine Vorauswahl):
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
        Show-Header "Theme-Manager"

        # Optionen exakt in Anzeige-Reihenfolge aufbauen
        $options = New-Object System.Collections.Generic.List[Hashtable]

        # 1 & 2: Aktionen
        Write-Host ("  {0,2}) {1}" -f 1, "➕ Custom-Theme hinzufügen") -ForegroundColor $ThemeUI.ColorAction
        Write-Host ("  {0,2}) {1}" -f 2, "🗑️  Custom-Theme entfernen") -ForegroundColor $ThemeUI.ColorAction
        $options.Add(@{ Kind='Action'; Name='Add';    Url=$null })
        $options.Add(@{ Kind='Action'; Name='Remove'; Url=$null })

        # Eingebaute Themes
        Show-Section "Eingebaute Themes"
        $n = $options.Count
        foreach ($t in $builtIn) {
            $n++
            $options.Add(@{ Kind='BuiltIn'; Name=$t.Name; Url=$t.Url })
            Write-Host ("  {0,2}) {1}" -f $n, $t.Name) -ForegroundColor $ThemeUI.ColorBuiltIn
        }

        # Eigene Themes
        $custom = @(Load-CustomThemes)
        if ($custom.Count -gt 0) {
            Show-Section "Eigene Themes"
            foreach ($t in $custom) {
                $n++
                $options.Add(@{ Kind='Custom'; Name=$t.Name; Url=$t.Url })
                Write-Host ("  {0,2}) {1}" -f $n, $t.Name) -ForegroundColor $ThemeUI.ColorCustom
            }
        }

        Write-Host ""
        $choice = Read-Host "Zahl / p<Zahl> (Preview) / a<Zahl> (Apply) / q (Quit)"
        if ($choice -match '^\s*q\s*$') { break }

        # Direktkürzel pN / aN
        if ($choice -match '^\s*p(\d+)\s*$') {
            $idx = [int]$matches[1]
            if ($idx -ge 1 -and $idx -le $options.Count -and $options[$idx-1].Kind -ne 'Action') {
                $sel = $options[$idx-1]
                Preview-Theme $sel.Url
                $after = Read-Host "Preview fertig. Übernehmen (a/Enter) oder Abbrechen (c)?"
                if ([string]::IsNullOrWhiteSpace($after) -or $after -match '^\s*a\s*$') { try { Load-Theme $sel.Url } catch { Show-Err $_ }; break }
                else { continue }
            } else { Show-Warn "Ungültiger Index." ; Start-Sleep -Milliseconds 600; continue }
        }
        if ($choice -match '^\s*a(\d+)\s*$') {
            $idx = [int]$matches[1]
            if ($idx -ge 1 -and $idx -le $options.Count -and $options[$idx-1].Kind -ne 'Action') {
                $sel = $options[$idx-1]
                try { Load-Theme $sel.Url } catch { Show-Err $_ }
                break
            } else { Show-Warn "Ungültiger Index." ; Start-Sleep -Milliseconds 600; continue }
        }

        # Normale Zahl
        if (-not ($choice -as [int])) { Show-Warn "Bitte eine gültige Zahl eingeben."; Start-Sleep -Milliseconds 600; continue }
        $pick = [int]$choice
        if ($pick -lt 1 -or $pick -gt $options.Count) { Show-Warn "Nummer außerhalb der Liste."; Start-Sleep -Milliseconds 600; continue }

        $sel = $options[$pick-1]

        # Aktionen 1/2 direkt
        if ($sel.Kind -eq 'Action') {
            if     ($pick -eq 1) { Add-CustomTheme | Out-Null }
            elseif ($pick -eq 2) { Remove-CustomTheme }
            Read-Host "Weiter mit Enter"
            continue
        }

        # Schritt 2: p/a/Enter/c/q für gewähltes Theme
        Show-Section ("Ausgewählt: {0}" -f $sel.Name)
        $action = Read-Host "Aktion: Preview (p) im neuen Fenster, Apply (a/Enter), Cancel (c), Quit (q)"

        if     ($action -match '^\s*q\s*$') { break }             # Beenden
        elseif ($action -match '^\s*c\s*$') { continue }          # Zurück zur Liste
        elseif ($action -match '^\s*p\s*$') {
            Preview-Theme $sel.Url                                  # Preview-Fenster
            $after = Read-Host "Preview fertig. Übernehmen (a/Enter) oder Abbrechen (c)?"
            if ([string]::IsNullOrWhiteSpace($after) -or $after -match '^\s*a\s*$') { try { Load-Theme $sel.Url } catch { Show-Err $_ }; break }
            else { continue }
        }
        else {
            # Default = Apply (Enter) oder 'a'
            try { Load-Theme $sel.Url } catch { Show-Err $_ }
            break
        }
    }
}

# -----------------------------
# Startverhalten (Default/Last)
# -----------------------------
# Beim Start: Versuche letztes Theme zu laden; sonst nutze sinnvolles Default.
$DefaultTheme = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/M365Princess.omp.json"

if (Test-Path $LastThemeFile) {
    $last = Get-Content $LastThemeFile -Raw
    try {
        Load-Theme $last
        Show-Info "Zuletzt geladenes Theme: $last"
    } catch {
        Show-Warn "Konnte letztes Theme nicht laden. Nutze Default."
        try { Load-Theme $DefaultTheme } catch {}
    }
} else {
    try { Load-Theme $DefaultTheme } catch {}
}

Show-Info "Tipp: 'mythemes' → Zahl / p<Zahl> / a<Zahl> → (a/Enter) anwenden, (c) abbrechen, (q) beenden."
Show-Info "Eigene Themes verwalten: Add-CustomTheme / Remove-CustomTheme"
