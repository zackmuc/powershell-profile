# ============================================================================
# Microsoft.PowerShell_profile.ps1 — Oh-My-Posh Theme Manager (WPF)
#
# Ziele / Features:
# - Built-in + Custom Theme Store (JSON)
# - URLs automatisch in RAW-URLs konvertieren (GitHub/Gist)
# - Preview-Cache als PNG + Meta (TTL/Hash/mtime), nur bei Änderung neu rendern
# - Preview in separater pwsh-Session (damit die aktuelle Shell "sauber" bleibt)
# - Apply Theme in aktueller Session (inkl. Cache-Wipe)
# - WPF Theme-Manager UI: Windows Theme/Accent aware (Dark/Light), Win11 Backdrop,
#   Icons, responsive Toolbar (WrapPanel), responsive Spaltenbreiten, Acrylic Effect
# - Auto-Repair der Stores + Auto-Apply letztes Theme beim Start
# - StartupCard in der Konsole (PSStyle falls VT vorhanden)
# - WIN11: Acrylic Blur, Fluent Design, mica backdrop, corner radius
#
# WICHTIG:
# - Für WPF müssen Brushes/Colors aus System.Windows.Media kommen (nicht Windows.Media).
#   Sonst: "Unable to cast ... to System.Windows.Media.Brush"
# ============================================================================

Set-StrictMode -Version Latest
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ============================================================================
# STORAGE / PFADE
# ============================================================================
$PreferredRoot  = 'C:\_posh'
$RootCandidates = @(
  $PreferredRoot,
  (Join-Path $HOME '_posh'),
  (Join-Path $env:LOCALAPPDATA 'oh-my-posh')
)

function Get-RootDir {
  if (Test-Path $PreferredRoot) { return $PreferredRoot }
  foreach ($r in $RootCandidates) {
    if (Test-Path (Join-Path $r '.omp_custom_themes.json')) { return $r }
  }
  foreach ($r in $RootCandidates) {
    if (Test-Path $r) { return $r }
  }
  try { New-Item -ItemType Directory -Path $PreferredRoot -Force | Out-Null } catch {}
  return $PreferredRoot
}

$script:RootDir          = Get-RootDir
$script:CustomThemesFile = Join-Path $script:RootDir '.omp_custom_themes.json'
$script:PreviewDir       = Join-Path $script:RootDir '.previews'

foreach ($d in @($script:RootDir, $script:PreviewDir)) {
  if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

$script:PreviewMaxAgeHours = 24

# ============================================================================
# BUILT-IN THEMES
# ============================================================================
$BuiltInThemes = @(
  @{ Name='A-Retro-Fade';         Url='https://gist.githubusercontent.com/zackmuc/321d436943f6be6e15ccc21f3d5a96df/raw/901b6ba5bb212d3115b1fb388d0508c7c3a753ea/a-retro-fade.omp.json' }
  @{ Name='M365Princess';         Url='https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/M365Princess.omp.json' }
  @{ Name='Amro';                 Url='https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/amro.omp.json' }
  @{ Name='Jandedobbeleer';       Url='https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/jandedobbeleer.omp.json' }
  @{ Name='Powerlevel10kRainbow'; Url='https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/powerlevel10k_rainbow.omp.json' }
  @{ Name='Paradox';              Url='https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/paradox.omp.json' }
) | ForEach-Object { [pscustomobject]$_ }

# ============================================================================
# HELPER: JSON & URL
# ============================================================================
function Sanitize-Json([string]$Text){
  if ([string]::IsNullOrWhiteSpace($Text)) { return $Text }
  $t = $Text
  $t = [Regex]::Replace($t,'/\*.*?\*/','',[System.Text.RegularExpressions.RegexOptions]::Singleline)
  $t = [Regex]::Replace($t,'(^|[\s])//.*?$','$1',[System.Text.RegularExpressions.RegexOptions]::Multiline)
  $t = [Regex]::Replace($t,',(\s*[}\]])','$1')
  return $t
}

function Normalize-ThemeUrl([string]$Text){
  if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
  $t = $Text.Trim().Trim('"').Trim("'")
  if (Test-Path $t) { return (Resolve-Path $t).Path }
  try { return ([Uri]$t).AbsoluteUri } catch { return $t }
}

function Resolve-ThemeUrlToRaw([string]$u) {
  if ([string]::IsNullOrWhiteSpace($u)) { return '' }
  $t = $u.Trim().Trim('"').Trim("'")
  if (Test-Path $t) { return (Resolve-Path $t).Path }

  try { $uri = [Uri]$t } catch { return $t }
  $uriHost = $uri.Host.ToLowerInvariant()

  if ($uriHost -eq 'raw.githubusercontent.com') {
    return $uri.GetLeftPart([System.UriPartial]::Path)
  }

  $abs = $uri.AbsoluteUri

  $abs2 = $abs -ireplace '^https?://(?:www\.)?github\.com/([^/]+)/([^/]+)/(?:blob|tree|raw)/([^/]+)/(.+?)(?:\?.*)?(?:#.*)?$',
                      'https://raw.githubusercontent.com/$1/$2/$3/$4'

  $abs2 = $abs2 -ireplace '^https?://(?:www\.)?gist\.github\.com/([^/]+)/([0-9a-f]+)/?.*$',
                        'https://gist.githubusercontent.com/$1/$2/raw'

  if ($abs2 -ne $abs) { return $abs2 }
  return $uri.GetLeftPart([System.UriPartial]::Path)
}

# ============================================================================
# HELPER: DOWNLOAD + CONTENT
# ============================================================================
function Invoke-DownloadText([string]$Url){
  $headers=@{ 'User-Agent'='curl/8.0'; 'Accept'='application/json,text/plain;q=0.9,*/*;q=0.8' }
  try {
    return (Invoke-WebRequest -Uri $Url -Headers $headers -MaximumRedirection 10 -TimeoutSec 45 -ErrorAction Stop).Content
  } catch {
    $raw = Invoke-RestMethod -Uri $Url -Headers $headers -MaximumRedirection 10 -TimeoutSec 45 -ErrorAction Stop
    if ($raw -is [string]) { return $raw } else { return ($raw | ConvertTo-Json -Depth 12) }
  }
}

function Get-ThemeContent([string]$Url){
  try{
    if (Test-Path $Url) {
      return @{ Ok=$true; Text=(Get-Content $Url -Raw); FromUrl=$null; Error=$null }
    }

    $raw = Resolve-ThemeUrlToRaw $Url
    $candidates = @($raw, ($raw + '?plain=1'), ($Url + '?raw=1'), $Url) |
      Where-Object { $_ } | Select-Object -Unique

    foreach ($u in $candidates){
      try{
        $txt = Invoke-DownloadText $u
        if ([string]::IsNullOrWhiteSpace($txt)) { continue }
        $head = $txt.TrimStart()
        if ($head.StartsWith('<')) { continue }
        $clean = Sanitize-Json $txt
        try { $null = $clean | ConvertFrom-Json } catch { continue }
        return @{ Ok=$true; Text=$txt; FromUrl=$u; Error=$null }
      } catch {}
    }

    return @{ Ok=$false; Text=$null; FromUrl=$null; Error='Download ergab HTML/Seite oder scheiterte. Bitte Raw-URL verwenden.' }
  } catch {
    return @{ Ok=$false; Text=$null; FromUrl=$null; Error=$_.Exception.Message }
  }
}

# ============================================================================
# CUSTOM STORE: LOAD/SAVE/REPAIR
# ============================================================================
function Load-CustomThemes{
  if (-not (Test-Path $script:CustomThemesFile)) { return @() }
  try {
    $obj = Get-Content $script:CustomThemesFile -Raw | ConvertFrom-Json
    if ($obj -is [array]) { return @($obj) }
    if ($obj) { return @($obj) }
    return @()
  } catch { return @() }
}

function Save-CustomThemes([object[]]$list){
  @($list) | ConvertTo-Json -Depth 6 | Set-Content -Path $script:CustomThemesFile -Encoding UTF8 -Force
}

function Repair-StoreUrls([string]$Path) {
  if (-not (Test-Path $Path)) { return 0 }
  try {
    $rawText = Get-Content $Path -Raw
    if ([string]::IsNullOrWhiteSpace($rawText)) { return 0 }

    $obj = $rawText | ConvertFrom-Json
    if (-not $obj) { return 0 }

    $list = @()
    if ($obj -is [array]) { $list = @($obj) } else { $list = @($obj) }

    $changed = 0
    $fixed = foreach ($t in $list) {
      if (-not $t) { continue }
      $name = [string]$t.Name
      $url  = [string]$t.Url
      $newUrl = Resolve-ThemeUrlToRaw (Normalize-ThemeUrl $url)
      if ($newUrl -and $url -and ($newUrl -ne $url)) { $changed++ }
      [pscustomobject]@{ Name=$name; Url=$newUrl }
    }

    if ($changed -gt 0) {
      @($fixed) | ConvertTo-Json -Depth 6 | Set-Content -Path $Path -Encoding UTF8 -Force
    }
    return $changed
  } catch {
    return 0
  }
}

# ============================================================================
# CACHE-KILLER: INIT.*.PS1 (AUCH MSIX PACKAGES)
# ============================================================================
function Clear-OMPInitCaches {
  $removed = 0
  $targets = @()

  $targets += (Join-Path $env:LOCALAPPDATA 'oh-my-posh')

  $packagesRoot = Join-Path $env:LOCALAPPDATA 'Packages'
  if (Test-Path $packagesRoot) {
    Get-ChildItem $packagesRoot -Directory -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -like 'ohmyposh.cli_*' } |
      ForEach-Object {
        $targets += (Join-Path $_.FullName 'LocalCache\Local\oh-my-posh')
      }
  }

  foreach ($t in $targets) {
    if (Test-Path $t) {
      Get-ChildItem -Path $t -Filter 'init.*.ps1' -ErrorAction SilentlyContinue |
        ForEach-Object {
          try { Remove-Item $_.FullName -Force -ErrorAction Stop; $removed++ } catch {}
        }
    }
  }

  return $removed
}

function Get-OhMyPoshPath {
  $p = (Get-Command oh-my-posh -ErrorAction SilentlyContinue)?.Source
  if (-not $p) { return 'oh-my-posh' }
  return $p
}

# ============================================================================
# ADD/REMOVE/PREVIEW/APPLY
# ============================================================================
function Add-CustomTheme{
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$Url,
    [switch]$AutoRename
  )

  $uRaw = Resolve-ThemeUrlToRaw (Normalize-ThemeUrl $Url)

  $g = Get-ThemeContent $uRaw
  if (-not $g.Ok) { throw "Download/URL-Problem: $($g.Error)" }

  $clean = Sanitize-Json $g.Text
  try { $null = $clean | ConvertFrom-Json } catch { throw "Theme-JSON ungültig: $($_.Exception.Message)" }

  $list = @() + (Load-CustomThemes)

  if ($list | Where-Object { $_.Url -ieq $uRaw }) { throw "URL existiert bereits (RAW): $uRaw" }

  if ($list | Where-Object { $_.Name -ieq $Name }) {
    if ($AutoRename) {
      $base=$Name; $i=1
      while ($list | Where-Object { $_.Name -ieq $Name }) { $Name="$base-$i"; $i++ }
    } else {
      throw "Name existiert bereits: $Name"
    }
  }

  $newList = $list + ([pscustomobject]@{ Name=$Name; Url=$uRaw })
  Save-CustomThemes $newList
  [pscustomobject]@{ ok=$true; name=$Name; url=$uRaw; path=$script:CustomThemesFile }
}

function Remove-CustomTheme{
  param([Parameter(Mandatory)][string[]]$Name)
  $list = @() + (Load-CustomThemes)
  $new  = $list | Where-Object { $_.Name -notin $Name }
  Save-CustomThemes $new
}

# --- Preview Meta Helpers ---
function Get-PreviewMetaPath([string]$PngPath) { return ($PngPath + '.meta.json') }

function Load-PreviewMeta([string]$MetaPath) {
  if (-not (Test-Path $MetaPath)) { return $null }
  try { return (Get-Content $MetaPath -Raw | ConvertFrom-Json -AsHashtable) } catch { return $null }
}

function Save-PreviewMeta([string]$MetaPath, [hashtable]$Meta) {
  $Meta | ConvertTo-Json -Depth 6 | Set-Content -Path $MetaPath -Encoding UTF8 -Force
}

function Get-StringSha256([string]$Text) {
  $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
  $hash  = [Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
  return (($hash | ForEach-Object { $_.ToString('x2') }) -join '')
}

function Export-ThemePreviewImage {
  param(
    [Parameter(Mandatory)][string]$Url,
    [Parameter(Mandatory)][string]$Name,
    [switch]$Force,
    [int]$MaxAgeHours = $script:PreviewMaxAgeHours
  )

  $safe = ($Name -replace '[^\w.-]','_')
  $png  = Join-Path $script:PreviewDir ($safe + '.png')
  $metaPath = Get-PreviewMetaPath $png
  $nowUtc = (Get-Date).ToUniversalTime()

  if ((Test-Path $png) -and (-not $Force)) {
    $meta = Load-PreviewMeta $metaPath

    if (-not $meta) {
      Save-PreviewMeta $metaPath @{
        Version        = 1
        Name           = $Name
        Url            = $Url
        LastCheckedUtc = $nowUtc.ToString('o')
        RenderedUtc    = $null
        Hash           = $null
        SourceKind     = 'unknown'
        SourcePath     = $null
        SourceLastWriteTimeUtc = $null
      }
      return $png
    }

    if ($meta.LastCheckedUtc) {
      try {
        $last = [datetime]::Parse($meta.LastCheckedUtc).ToUniversalTime()
        if ((($nowUtc - $last).TotalHours) -lt $MaxAgeHours) { return $png }
      } catch {}
    }
  }

  $omp = Get-OhMyPoshPath
  if (-not $omp) { throw "oh-my-posh nicht gefunden (PATH)." }

  $metaExisting = Load-PreviewMeta $metaPath

  if (Test-Path $Url) {
    $srcPath = (Resolve-Path $Url).Path
    $mtimeUtc = (Get-Item $srcPath).LastWriteTimeUtc.ToString('o')

    if ((Test-Path $png) -and (-not $Force) -and $metaExisting -and ($metaExisting.SourceLastWriteTimeUtc -eq $mtimeUtc)) {
      Save-PreviewMeta $metaPath @{
        Version        = 1
        Name           = $Name
        Url            = $Url
        LastCheckedUtc = $nowUtc.ToString('o')
        RenderedUtc    = $metaExisting.RenderedUtc
        Hash           = $metaExisting.Hash
        SourceKind     = 'file'
        SourcePath     = $srcPath
        SourceLastWriteTimeUtc = $mtimeUtc
      }
      return $png
    }

    $txt   = Get-Content $srcPath -Raw
    $clean = Sanitize-Json $txt
    $hash  = Get-StringSha256 $clean

    if ((Test-Path $png) -and (-not $Force) -and $metaExisting -and ($metaExisting.Hash -eq $hash)) {
      Save-PreviewMeta $metaPath @{
        Version        = 1
        Name           = $Name
        Url            = $Url
        LastCheckedUtc = $nowUtc.ToString('o')
        RenderedUtc    = $metaExisting.RenderedUtc
        Hash           = $hash
        SourceKind     = 'file'
        SourcePath     = $srcPath
        SourceLastWriteTimeUtc = $mtimeUtc
      }
      return $png
    }

    $cfg = Join-Path $env:TEMP ('omp_' + [IO.Path]::GetRandomFileName() + '.json')
    $clean | Set-Content -Path $cfg -Encoding UTF8 -Force
    try {
      & $omp config export image -c $cfg -o $png | Out-Null
      if (-not (Test-Path $png)) { throw "Export fehlgeschlagen (kein PNG erzeugt)." }
    } finally {
      Remove-Item $cfg -Force -ErrorAction SilentlyContinue
    }

    Save-PreviewMeta $metaPath @{
      Version        = 1
      Name           = $Name
      Url            = $Url
      LastCheckedUtc = $nowUtc.ToString('o')
      RenderedUtc    = $nowUtc.ToString('o')
      Hash           = $hash
      SourceKind     = 'file'
      SourcePath     = $srcPath
      SourceLastWriteTimeUtc = $mtimeUtc
    }

    return $png
  }

  $g = Get-ThemeContent $Url
  if (-not $g.Ok) { throw "Ungültiges JSON/Download: $($g.Error)" }

  $clean = Sanitize-Json $g.Text
  $hash  = Get-StringSha256 $clean

  if ((Test-Path $png) -and (-not $Force) -and $metaExisting -and ($metaExisting.Hash -eq $hash)) {
    Save-PreviewMeta $metaPath @{
      Version        = 1
      Name           = $Name
      Url            = $Url
      LastCheckedUtc = $nowUtc.ToString('o')
      RenderedUtc    = $metaExisting.RenderedUtc
      Hash           = $hash
      SourceKind     = 'remote'
      SourcePath     = $null
      SourceLastWriteTimeUtc = $null
    }
    return $png
  }

  $cfg = Join-Path $env:TEMP ('omp_' + [IO.Path]::GetRandomFileName() + '.json')
  $clean | Set-Content -Path $cfg -Encoding UTF8 -Force
  try {
    & $omp config export image -c $cfg -o $png | Out-Null
    if (-not (Test-Path $png)) { throw "Export fehlgeschlagen (kein PNG erzeugt)." }
  } finally {
    Remove-Item $cfg -Force -ErrorAction SilentlyContinue
  }

  Save-PreviewMeta $metaPath @{
    Version        = 1
    Name           = $Name
    Url            = $Url
    LastCheckedUtc = $nowUtc.ToString('o')
    RenderedUtc    = $nowUtc.ToString('o')
    Hash           = $hash
    SourceKind     = 'remote'
    SourcePath     = $null
    SourceLastWriteTimeUtc = $null
  }

  return $png
}

function Preview-Theme([string]$Url){
  $g = Get-ThemeContent $Url
  if (-not $g.Ok) { throw "Ungültiges JSON/Download: $($g.Error)" }

  $cfg = Join-Path $env:TEMP ('omp_'+[IO.Path]::GetRandomFileName()+'.json')
  (Sanitize-Json $g.Text) | Set-Content -Path $cfg -Encoding UTF8 -Force

  $omp = Get-OhMyPoshPath

  $cmd = "Remove-Item `"$env:LOCALAPPDATA\oh-my-posh\init.*.ps1`" -ErrorAction SilentlyContinue; " +
         "`$pkg=(Join-Path `"$env:LOCALAPPDATA`" 'Packages'); " +
         "Get-ChildItem `$pkg -Directory | ? Name -like 'ohmyposh.cli_*' | " +
         "%{ Remove-Item `"$($_.FullName)\LocalCache\Local\oh-my-posh\init.*.ps1`" -ErrorAction SilentlyContinue }; " +
         "(& `"$omp`" init pwsh --config `"$cfg`") | Invoke-Expression; " +
         "Write-Host 'Preview – Fenster schließen, um zur aktuellen Session zurückzukehren.' -ForegroundColor Yellow"

  $encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
  Start-Process -FilePath 'pwsh.exe' -ArgumentList @('-NoExit','-NoProfile','-EncodedCommand',$encoded) | Out-Null
}

function Apply-Theme([string]$Url){
  $g = Get-ThemeContent $Url
  if (-not $g.Ok) { throw "Ungültiges JSON/Download: $($g.Error)" }

  $cfg = Join-Path $env:TEMP ('omp_'+[IO.Path]::GetRandomFileName()+'.json')
  (Sanitize-Json $g.Text) | Set-Content -Path $cfg -Encoding UTF8 -Force

  $omp = Get-OhMyPoshPath
  Clear-OMPInitCaches | Out-Null

  $init = & $omp init pwsh --config $cfg
  if ($init) { Invoke-Expression $init }

  Set-Content -Path (Join-Path $HOME '.posh_last_theme.txt') -Value $Url -Encoding UTF8 -Force
}

# ============================================================================
# WINDOWS THEME + ACCENT (WPF: System.Windows.Media.*)
# ============================================================================
function Get-WindowsAppTheme {
  try {
    $p = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -ErrorAction Stop
    if ($p.AppsUseLightTheme -eq 0) { return 'Dark' }
    return 'Light'
  } catch { return 'Dark' }
}

function Get-WindowsAccentColor {
  try {
    $dwm = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\DWM' -ErrorAction Stop
    $v = [uint32]$dwm.ColorizationColor
    $a = [byte](($v -shr 24) -band 0xFF)
    $r = [byte](($v -shr 16) -band 0xFF)
    $g = [byte](($v -shr  8) -band 0xFF)
    $b = [byte](($v       ) -band 0xFF)
    return [System.Windows.Media.Color]::FromArgb($a,$r,$g,$b)
  } catch {
    return [System.Windows.Media.Color]::FromRgb(79,193,255)
  }
}

function Set-BrushResource {
  param(
    [Parameter(Mandatory)]$Window,
    [Parameter(Mandatory)][string]$Key,
    [Parameter(Mandatory)][System.Windows.Media.Color]$Color
  )

  $brush = [System.Windows.Media.SolidColorBrush]::new($Color)
  $brush.Freeze()
  $Window.Resources[$Key] = $brush
}

function Apply-ThemeToThemeManagerWindow {
  param([Parameter(Mandatory)]$Window)

  $mode   = Get-WindowsAppTheme
  $accent = Get-WindowsAccentColor

  if ($mode -eq 'Light') {
    Set-BrushResource $Window 'Bg'       ([System.Windows.Media.Color]::FromRgb(245,245,245))
    Set-BrushResource $Window 'Surface'  ([System.Windows.Media.Color]::FromRgb(255,255,255))
    Set-BrushResource $Window 'Surface2' ([System.Windows.Media.Color]::FromRgb(248,248,248))
    Set-BrushResource $Window 'Border'   ([System.Windows.Media.Color]::FromRgb(220,220,220))
    Set-BrushResource $Window 'Fg'       ([System.Windows.Media.Color]::FromRgb(20,20,20))
    Set-BrushResource $Window 'FgDim'    ([System.Windows.Media.Color]::FromRgb(90,90,90))
    Set-BrushResource $Window 'BtnBg'    ([System.Windows.Media.Color]::FromRgb(255,255,255))
    Set-BrushResource $Window 'BtnHover' ([System.Windows.Media.Color]::FromRgb(240,240,240))
  } else {
    Set-BrushResource $Window 'Bg'       ([System.Windows.Media.Color]::FromRgb(18,18,18))
    Set-BrushResource $Window 'Surface'  ([System.Windows.Media.Color]::FromRgb(30,30,30))
    Set-BrushResource $Window 'Surface2' ([System.Windows.Media.Color]::FromRgb(24,24,24))
    Set-BrushResource $Window 'Border'   ([System.Windows.Media.Color]::FromRgb(55,55,55))
    Set-BrushResource $Window 'Fg'       ([System.Windows.Media.Color]::FromRgb(235,235,235))
    Set-BrushResource $Window 'FgDim'    ([System.Windows.Media.Color]::FromRgb(170,170,170))
    Set-BrushResource $Window 'BtnBg'    ([System.Windows.Media.Color]::FromRgb(42,42,42))
    Set-BrushResource $Window 'BtnHover' ([System.Windows.Media.Color]::FromRgb(58,58,58))
  }

  Set-BrushResource $Window 'Accent' $accent
  Set-BrushResource $Window 'SelBg'  ([System.Windows.Media.Color]::FromArgb(90, $accent.R, $accent.G, $accent.B))
}

# ============================================================================
# WIN11 BACKDROP (DWMSETWINDOWATTRIBUTE) + ACRYLIC BLUR
# ============================================================================
function Enable-Win11Backdrop {
  param(
    [Parameter(Mandatory)]$Window,
    [ValidateSet('Mica','Acrylic','Tabbed')]$Mode = 'Tabbed'
  )

  if (-not ('Win11.Dwm' -as [type])) {
    $cs = @'
using System;
using System.Runtime.InteropServices;

namespace Win11 {
  public static class Dwm {
    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);
  }
}
'@
    Add-Type -TypeDefinition $cs -Language CSharp -ErrorAction Stop
  }

  $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper($Window)).Handle

  # DWMWA_SYSTEMBACKDROP_TYPE (38): Mica (2), Acrylic (3), Tabbed (4)
  $DWMWA_SYSTEMBACKDROP_TYPE = 38
  $backdrop = switch ($Mode) { 'Mica' { 2 } 'Acrylic' { 3 } 'Tabbed' { 4 } }
  [Win11.Dwm]::DwmSetWindowAttribute($hwnd, $DWMWA_SYSTEMBACKDROP_TYPE, [ref]$backdrop, 4) | Out-Null

  # DWMWA_USE_IMMERSIVE_DARK_MODE (20): Dark mode
  $DWMWA_USE_IMMERSIVE_DARK_MODE = 20
  $dark = if ((Get-WindowsAppTheme) -eq 'Dark') { 1 } else { 0 }
  [Win11.Dwm]::DwmSetWindowAttribute($hwnd, $DWMWA_USE_IMMERSIVE_DARK_MODE, [ref]$dark, 4) | Out-Null

  # DWMWA_BORDER_COLOR (34): Custom accent border
  $DWMWA_BORDER_COLOR = 34
  $accent = Get-WindowsAccentColor
  $colorValue = [int]([uint32]($accent.A -shl 24) -bor ($accent.R -shl 16) -bor ($accent.G -shl 8) -bor $accent.B)
  [Win11.Dwm]::DwmSetWindowAttribute($hwnd, $DWMWA_BORDER_COLOR, [ref]$colorValue, 4) | Out-Null
}

# ============================================================================
# WPF UI: THEME MANAGER (FIXED: XAML ERRORS + RESPONSIVE)
# ============================================================================
function Show-ThemeManager{
  Add-Type -AssemblyName PresentationCore,PresentationFramework,WindowsBase | Out-Null

$xml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Oh-My-Posh Theme Manager"
        Height="720" Width="1400"
        MinHeight="500" MinWidth="900"
        WindowStartupLocation="CenterScreen"
        Background="{DynamicResource Bg}"
        UseLayoutRounding="True"
        SnapsToDevicePixels="True"
        SizeToContent="Manual"
        WindowStyle="SingleBorderWindow"
        AllowsTransparency="False">

  <Window.Resources>
    <SolidColorBrush x:Key="Bg" />
    <SolidColorBrush x:Key="Surface" />
    <SolidColorBrush x:Key="Surface2" />
    <SolidColorBrush x:Key="Border" />
    <SolidColorBrush x:Key="Fg" />
    <SolidColorBrush x:Key="FgDim" />
    <SolidColorBrush x:Key="Accent" />
    <SolidColorBrush x:Key="BtnBg" />
    <SolidColorBrush x:Key="BtnHover" />
    <SolidColorBrush x:Key="SelBg" />

    <!-- Icon Font -->
    <FontFamily x:Key="IconFont">Segoe Fluent Icons</FontFamily>
    <Style x:Key="IconText" TargetType="TextBlock">
      <Setter Property="FontFamily" Value="{StaticResource IconFont}"/>
      <Setter Property="FontSize" Value="16"/>
      <Setter Property="Margin" Value="0,0,8,0"/>
      <Setter Property="VerticalAlignment" Value="Center"/>
    </Style>

    <Style TargetType="TextBlock">
      <Setter Property="Foreground" Value="{DynamicResource Fg}"/>
    </Style>

    <Style TargetType="Button">
      <Setter Property="Margin" Value="0,0,6,6"/>
      <Setter Property="Padding" Value="12,7"/>
      <Setter Property="Foreground" Value="{DynamicResource Fg}"/>
      <Setter Property="Background" Value="{DynamicResource BtnBg}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource Border}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border Background="{TemplateBinding Background}"
                    BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}"
                    CornerRadius="8"
                    Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter Property="Background" Value="{DynamicResource BtnHover}" />
                <Setter Property="BorderBrush" Value="{DynamicResource Accent}" />
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.55" />
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="ListView">
      <Setter Property="Background" Value="{DynamicResource Surface}"/>
      <Setter Property="Foreground" Value="{DynamicResource Fg}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource Border}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="2"/>
      <Setter Property="ScrollViewer.VerticalScrollBarVisibility" Value="Auto"/>
      <Setter Property="ScrollViewer.HorizontalScrollBarVisibility" Value="Disabled"/>
    </Style>

    <!-- Eigene Zeilen-Vorlage: Standard-Auswahl (weiß) wäre mit heller Schrift unlesbar -->
    <Style TargetType="ListViewItem">
      <Setter Property="Foreground" Value="{DynamicResource Fg}"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Padding" Value="2,3"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ListViewItem">
            <Border x:Name="Bd"
                    Background="{TemplateBinding Background}"
                    BorderBrush="Transparent"
                    BorderThickness="1"
                    CornerRadius="4"
                    Padding="{TemplateBinding Padding}">
              <GridViewRowPresenter Columns="{TemplateBinding GridView.ColumnCollection}"
                                    Content="{TemplateBinding Content}"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="{DynamicResource BtnHover}"/>
              </Trigger>
              <Trigger Property="IsSelected" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="{DynamicResource SelBg}"/>
                <Setter TargetName="Bd" Property="BorderBrush" Value="{DynamicResource Accent}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="StatusBar">
      <Setter Property="Background" Value="{DynamicResource Surface2}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource Border}"/>
      <Setter Property="BorderThickness" Value="1,1,0,0"/>
    </Style>

    <Style TargetType="GridViewColumnHeader">
      <Setter Property="Background" Value="{DynamicResource Surface2}"/>
      <Setter Property="Foreground" Value="{DynamicResource FgDim}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource Border}"/>
      <Setter Property="Padding" Value="8,4"/>
      <Setter Property="FontSize" Value="11"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
    </Style>
  </Window.Resources>

  <DockPanel LastChildFill="True" Margin="8">

    <!-- Toolbar oben -->
    <Border DockPanel.Dock="Top"
            Background="{DynamicResource Surface}"
            BorderBrush="{DynamicResource Border}"
            BorderThickness="1"
            CornerRadius="10"
            Padding="8"
            Margin="0,0,0,8">
      <WrapPanel Orientation="Horizontal" TextBlock.FontSize="12">
        <Button x:Name="ReloadBtn" ToolTip="Neu laden">
          <StackPanel Orientation="Horizontal">
            <TextBlock Style="{StaticResource IconText}" Text="&#xE72C;"/>
            <TextBlock Text="Laden"/>
          </StackPanel>
        </Button>
        <Button x:Name="RepairBtn" ToolTip="RAW reparieren">
          <StackPanel Orientation="Horizontal">
            <TextBlock Style="{StaticResource IconText}" Text="&#xE7D7;"/>
            <TextBlock Text="Repair"/>
          </StackPanel>
        </Button>
        <Button x:Name="AddBtn" ToolTip="Neu hinzufügen">
          <StackPanel Orientation="Horizontal">
            <TextBlock Style="{StaticResource IconText}" Text="&#xE710;"/>
            <TextBlock Text="Add"/>
          </StackPanel>
        </Button>
        <Button x:Name="RemoveBtn" ToolTip="Entfernen">
          <StackPanel Orientation="Horizontal">
            <TextBlock Style="{StaticResource IconText}" Text="&#xE74D;"/>
            <TextBlock Text="Remove"/>
          </StackPanel>
        </Button>
        <Button x:Name="PreviewBtn" ToolTip="Preview">
          <StackPanel Orientation="Horizontal">
            <TextBlock Style="{StaticResource IconText}" Text="&#xE8A7;"/>
            <TextBlock Text="Preview"/>
          </StackPanel>
        </Button>
        <Button x:Name="RenderBtn" ToolTip="Render">
          <StackPanel Orientation="Horizontal">
            <TextBlock Style="{StaticResource IconText}" Text="&#xE895;"/>
            <TextBlock Text="Render"/>
          </StackPanel>
        </Button>
        <Button x:Name="ApplyBtn" ToolTip="Apply">
          <StackPanel Orientation="Horizontal">
            <TextBlock Style="{StaticResource IconText}" Text="&#xE8FB;"/>
            <TextBlock Text="Apply"/>
          </StackPanel>
        </Button>
        <Button x:Name="CloseBtn" ToolTip="Close">
          <StackPanel Orientation="Horizontal">
            <TextBlock Style="{StaticResource IconText}" Text="&#xE8BB;"/>
            <TextBlock Text="Close"/>
          </StackPanel>
        </Button>
      </WrapPanel>
    </Border>

    <!-- StatusBar unten über die volle Breite -->
    <StatusBar DockPanel.Dock="Bottom" Height="26" Margin="0,8,0,0">
      <StatusBarItem>
        <TextBlock x:Name="StatusLeft"  Foreground="{DynamicResource FgDim}" FontSize="10"/>
      </StatusBarItem>
      <StatusBarItem HorizontalAlignment="Right">
        <TextBlock x:Name="StatusRight" Foreground="{DynamicResource FgDim}" FontSize="10"/>
      </StatusBarItem>
    </StatusBar>

    <!-- Hauptbereich -->
    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto" />
        <RowDefinition Height="1.5*" MinHeight="150"/>
        <RowDefinition Height="2.5*" MinHeight="200"/>
      </Grid.RowDefinitions>
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="1*" MinWidth="250"/>
        <ColumnDefinition Width="10" />
        <ColumnDefinition Width="1*" MinWidth="250"/>
      </Grid.ColumnDefinitions>

      <!-- Überschriften -->
      <TextBlock Grid.Row="0" Grid.Column="0"
                 Text="📦 Built-in"
                 FontWeight="SemiBold"
                 Foreground="{DynamicResource Accent}"
                 Margin="4,0,0,6"/>
      <TextBlock Grid.Row="0" Grid.Column="2"
                 Text="⭐ Custom"
                 FontWeight="SemiBold"
                 Foreground="{DynamicResource Accent}"
                 Margin="4,0,0,6"/>

      <!-- Built-in Liste -->
      <ListView x:Name="BuiltList"
                Grid.Row="1" Grid.Column="0"
                SelectionMode="Single">
        <ListView.View>
          <GridView>
            <GridViewColumn Header="Name" Width="150" DisplayMemberBinding="{Binding Name}"/>
            <GridViewColumn Header="URL"  Width="350" DisplayMemberBinding="{Binding Url}"/>
          </GridView>
        </ListView.View>
      </ListView>

      <!-- Splitter -->
      <GridSplitter Grid.Row="0"
                    Grid.RowSpan="3"
                    Grid.Column="1"
                    Width="10"
                    HorizontalAlignment="Center"
                    VerticalAlignment="Stretch"
                    Background="Transparent"/>

      <!-- Custom Liste -->
      <ListView x:Name="CustList"
                Grid.Row="1" Grid.Column="2"
                SelectionMode="Extended">
        <ListView.View>
          <GridView>
            <GridViewColumn Header="Name" Width="150" DisplayMemberBinding="{Binding Name}"/>
            <GridViewColumn Header="URL"  Width="350" DisplayMemberBinding="{Binding Url}"/>
          </GridView>
        </ListView.View>
      </ListView>

      <!-- Preview unten -->
      <Border Grid.Row="2" Grid.ColumnSpan="3"
              Background="{DynamicResource Surface}"
              BorderBrush="{DynamicResource Border}"
              BorderThickness="1"
              Padding="8"
              CornerRadius="10"
              Margin="0,8,0,0">
        <DockPanel LastChildFill="True">
          <TextBlock x:Name="PreviewInfo"
                     DockPanel.Dock="Top"
                     Margin="4,0,0,8"
                     Foreground="{DynamicResource FgDim}"
                     FontSize="11">Keine Auswahl</TextBlock>
		  <Border Background="{DynamicResource Surface2}"
				  CornerRadius="8"
				  Padding="8"
				  BorderBrush="{DynamicResource Border}"
				  BorderThickness="1"
				  ClipToBounds="True">
		    <Viewbox Stretch="Uniform">
			  <Image x:Name="PreviewImage"/>
		    </Viewbox>
		  </Border>
        </DockPanel>
      </Border>
    </Grid>

  </DockPanel>
</Window>
"@

  $sr = New-Object System.IO.StringReader($xml)
  $xr = [System.Xml.XmlReader]::Create($sr)
  $window = [Windows.Markup.XamlReader]::Load($xr)

  Apply-ThemeToThemeManagerWindow -Window $window
  $window.Add_SourceInitialized({ Enable-Win11Backdrop -Window $window -Mode Acrylic })
  $window.Add_Loaded({ Enable-Win11Backdrop -Window $window -Mode Acrylic })

  $ReloadBtn    = $window.FindName('ReloadBtn')
  $RepairBtn    = $window.FindName('RepairBtn')
  $AddBtn       = $window.FindName('AddBtn')
  $RemoveBtn    = $window.FindName('RemoveBtn')
  $PreviewBtn   = $window.FindName('PreviewBtn')
  $RenderBtn    = $window.FindName('RenderBtn')
  $ApplyBtn     = $window.FindName('ApplyBtn')
  $CloseBtn     = $window.FindName('CloseBtn')
  $BuiltList    = $window.FindName('BuiltList')
  $CustList     = $window.FindName('CustList')
  $PreviewImage = $window.FindName('PreviewImage')
  $PreviewInfo  = $window.FindName('PreviewInfo')
  $StatusLeft   = $window.FindName('StatusLeft')
  $StatusRight  = $window.FindName('StatusRight')

  function Show-Status([string]$text, [int]$ms = 2500) {
    $StatusRight.Text = $text
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds($ms)
    $timer.Add_Tick({
      param($s,$e)
      $StatusRight.Text = ''
      $s.Stop()
    })
    $timer.Start()
  }

  function ToItems($src,$kind){
    @(@($src | ForEach-Object {
      if($_){ [pscustomobject]@{ Name=$_.Name; Url=$_.Url; Kind=$kind } }
    }) | Sort-Object Name)
  }

  function Refresh-Lists {
    $b = ToItems $BuiltInThemes 'Built-in'
    $c = ToItems (Load-CustomThemes) 'Custom'
    $BuiltList.ItemsSource = $b
    $CustList.ItemsSource  = $c
    $StatusLeft.Text  = "Built-in: $($b.Count)   Custom: $($c.Count)"
    $StatusRight.Text = "Store: $script:CustomThemesFile"
  }

  $script:lastList = $null

  function SelectedItem {
    if ($script:lastList -eq 'built' -and $BuiltList.SelectedItem) { return $BuiltList.SelectedItem }
    if ($script:lastList -eq 'cust'  -and $CustList.SelectedItem)  { return $CustList.SelectedItem }
    if ($BuiltList.SelectedItem) { return $BuiltList.SelectedItem }
    if ($CustList.SelectedItem)  { return $CustList.SelectedItem }
    return $null
  }

  function Resolve-SelectedUrl([object]$sel){
    if (-not $sel) { return $null }
    $url = $sel.Url
    if (-not $url -or [string]::IsNullOrWhiteSpace($url)) {
      $url = ($BuiltInThemes | Where-Object { $_.Name -eq $sel.Name } | Select-Object -First 1 -ExpandProperty Url)
    }
    return (Resolve-ThemeUrlToRaw (Normalize-ThemeUrl $url))
  }

  function Update-Preview([switch]$Force) {
    $sel = SelectedItem
    if(-not $sel){
      $PreviewImage.Source = $null
      $PreviewInfo.Text = 'Keine Auswahl'
      return
    }

    try{
      $url = Resolve-SelectedUrl $sel
      if (-not $url) { throw "Keine gültige URL bestimmt." }

      $png = Export-ThemePreviewImage -Url $url -Name $sel.Name -Force:$Force

      $bmp = New-Object System.Windows.Media.Imaging.BitmapImage
      $bmp.BeginInit()
      $bmp.CacheOption = 'OnLoad'
      $bmp.UriSource = (New-Object System.Uri($png))
      $bmp.EndInit()

      $PreviewImage.Source = $bmp
      $PreviewInfo.Text = "$($sel.Name) — $url"
    } catch {
      $PreviewImage.Source = $null
      $PreviewInfo.Text = "$($sel.Name) — Vorschau fehlgeschlagen: $($_.Exception.Message)"
    }
  }

  $ReloadBtn.Add_Click({ Refresh-Lists; Show-Status "↻ Reloaded" })

  $RepairBtn.Add_Click({
    $changed = 0
    foreach($r in $RootCandidates){
      $changed += Repair-StoreUrls (Join-Path $r '.omp_custom_themes.json')
    }
    Refresh-Lists
    Show-Status ("🔧 Repair: {0} fixed" -f $changed) 3500
  })

  $AddBtn.Add_Click({
    $dlgX = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='Add Theme' Height='240' Width='780' WindowStartupLocation='CenterOwner' Background='#1e1e1e' ResizeMode='NoResize'>
  <Grid Margin='12'>
    <Grid.RowDefinitions>
      <RowDefinition Height='Auto'/>
      <RowDefinition Height='Auto'/>
      <RowDefinition Height='*'/>
      <RowDefinition Height='Auto'/>
    </Grid.RowDefinitions>
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width='120'/>
      <ColumnDefinition Width='*'/>
    </Grid.ColumnDefinitions>
    <TextBlock Grid.Row='0' Grid.Column='0' Text='URL:' Foreground='#dcdcdc' VerticalAlignment='Center'/>
    <TextBox   Grid.Row='0' Grid.Column='1' x:Name='UrlBox' Background='#2a2a2a' Foreground='#dcdcdc' BorderBrush='#555' Padding='6'/>
    <TextBlock Grid.Row='1' Grid.Column='0' Text='Name:' Foreground='#dcdcdc' VerticalAlignment='Center' Margin='0,8,0,0'/>
    <TextBox   Grid.Row='1' Grid.Column='1' x:Name='NameBox' Background='#2a2a2a' Foreground='#dcdcdc' BorderBrush='#555' Padding='6' Margin='0,8,0,0'/>
    <TextBlock Grid.Row='2' Grid.ColumnSpan='2' Text='Paste GitHub blob URL or Gist URL – it will auto-convert to RAW.' Foreground='#aaaaaa' Margin='0,10,0,0' TextWrapping='Wrap' FontSize='11'/>
    <StackPanel Grid.Row='3' Grid.ColumnSpan='2' Orientation='Horizontal' HorizontalAlignment='Right' Margin='0,12,0,0'>
      <Button x:Name='OkBtn' Content='OK' Width='120' Margin='0,0,8,0'/>
      <Button x:Name='CancelBtn' Content='Cancel' Width='140'/>
    </StackPanel>
  </Grid>
</Window>
"@
    $dlg = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader ([xml]$dlgX)))
    $ub=$dlg.FindName('UrlBox'); $nb=$dlg.FindName('NameBox'); $ok=$dlg.FindName('OkBtn'); $ca=$dlg.FindName('CancelBtn')

    $ok.Add_Click({ $script:url=$ub.Text; $script:name=$nb.Text; $dlg.DialogResult=$true; $dlg.Close() })
    $ca.Add_Click({ $dlg.DialogResult=$false; $dlg.Close() })

    $dlg.Owner=$window
    $null=$dlg.ShowDialog()
    if(-not $dlg.DialogResult){ return }

    try{
      $res = Add-CustomTheme -Name $script:name -Url $script:url -AutoRename
      Refresh-Lists
      Show-Status ("✔ Added: {0}" -f $res.name)
    }catch{
      Show-Status ("❌ Error: {0}" -f $_.Exception.Message) 4000
    }
  })

  $RemoveBtn.Add_Click({
    $sel=$CustList.SelectedItems
    if(-not $sel -or $sel.Count -eq 0){ Show-Status '⚠️ Select custom theme(s)'; return }

    $names = $sel | ForEach-Object Name
    $ans = [System.Windows.MessageBox]::Show(
      $window,
      ("Remove:`n`n- " + ($names -join "`n- ")),
      'Confirm','YesNo','Question'
    )

    if($ans -eq 'Yes'){
      Remove-CustomTheme -Name $names
      Refresh-Lists
      Show-Status ("🗑 Removed: {0}" -f (($names) -join ', '))
    }
  })

  $PreviewBtn.Add_Click({
    $sel = SelectedItem
    if(-not $sel){ Show-Status '⚠️ Select a theme'; return }
    try{
      $url = Resolve-SelectedUrl $sel
      if (-not $url) { throw "No URL" }
      Preview-Theme $url
      Show-Status ("🔍 Preview: {0}" -f $sel.Name)
    }catch{
      Show-Status ("❌ Preview Error: {0}" -f $_.Exception.Message) 4000
    }
  })

  $RenderBtn.Add_Click({ Update-Preview -Force })

  $BuiltList.Add_SelectionChanged({
    if ($BuiltList.SelectedItems -and $BuiltList.SelectedItems.Count -gt 0) {
      $script:lastList = 'built'
      if ($CustList.SelectedItems.Count -gt 0) { $CustList.SelectedItems.Clear() }
      Update-Preview
    }
  })
  $CustList.Add_SelectionChanged({
    if ($CustList.SelectedItems -and $CustList.SelectedItems.Count -gt 0) {
      $script:lastList = 'cust'
      if ($BuiltList.SelectedItem) { $BuiltList.SelectedItem = $null }
      Update-Preview
    }
  })

  $ApplyBtn.Add_Click({
    $sel=SelectedItem
    if($sel){
      try{
        $url = Resolve-SelectedUrl $sel
        if (-not $url) { throw "No URL" }
        Apply-Theme $url
        Show-Status ("✅ Applied: {0}" -f $sel.Name)
        $window.Close()
      }catch{
        Show-Status ("❌ Apply Error: {0}" -f $_.Exception.Message) 4000
      }
    } else {
      Show-Status '⚠️ Select a theme'
    }
  })

  $CloseBtn.Add_Click({ $window.Close() })

  Refresh-Lists

  $window.Add_Loaded({

  # 1 Tick später ausführen, damit WPF Listen/Binding wirklich fertig hat
  $null = $window.Dispatcher.BeginInvoke([Action]{

    try {
      $lastThemeFile = Join-Path $HOME ".posh_last_theme.txt"
      if (-not (Test-Path $lastThemeFile)) { return }

      $lastTheme = (Get-Content $lastThemeFile -Raw).Trim()
      if ([string]::IsNullOrWhiteSpace($lastTheme)) { return }

      $lastThemeRaw = Resolve-ThemeUrlToRaw (Normalize-ThemeUrl $lastTheme)

      $b = @($BuiltList.ItemsSource)
      $c = @($CustList.ItemsSource)

      $hitB = $b | Where-Object { (Resolve-ThemeUrlToRaw (Normalize-ThemeUrl $_.Url)) -ieq $lastThemeRaw } | Select-Object -First 1
      $hitC = $c | Where-Object { (Resolve-ThemeUrlToRaw (Normalize-ThemeUrl $_.Url)) -ieq $lastThemeRaw } | Select-Object -First 1

      if ($hitB) {
        $BuiltList.SelectedItem = $hitB
        $BuiltList.ScrollIntoView($hitB)
        $script:lastList = 'built'
      }
      elseif ($hitC) {
        $CustList.SelectedItem = $hitC
        $CustList.ScrollIntoView($hitC)
        $script:lastList = 'cust'
      }
      else {
        [System.Windows.MessageBox]::Show("AutoSelect: kein Treffer`n$lastThemeRaw") | Out-Null
        return
      }

      # Preview wirklich sofort erzeugen (wie Render-Button)
      Update-Preview -Force

    } catch {
      [System.Windows.MessageBox]::Show($_.Exception.ToString()) | Out-Null
    }

  }) # BeginInvoke

})

	$null = $window.ShowDialog()
}


function mythemes { Show-ThemeManager }

# ============================================================================
# AUTO-REPAIR & AUTO-APPLY ON START
# ============================================================================
try {
  $changed = 0
  foreach ($r in $RootCandidates) { $changed += Repair-StoreUrls (Join-Path $r '.omp_custom_themes.json') }
  if ($changed -gt 0) {
    Write-Host ("RAW-Repair at startup: {0} entries fixed." -f $changed) -ForegroundColor Green
  }
} catch {}

try {
  $lastThemeFile = Join-Path $HOME '.posh_last_theme.txt'
  if (Test-Path $lastThemeFile) {
    $lastTheme = (Get-Content $lastThemeFile -Raw).Trim()
    if ($lastTheme) {
      # Do not clear generated init files before Oh My Posh starts.
      $omp = Get-OhMyPoshPath
      $init = & $omp init pwsh --config $lastTheme
      if ($init) { Invoke-Expression $init }
      $env:POSH_THEME = $lastTheme
    }
  }
} catch {
  Write-Host "⚠️ Failed to load theme at startup: $($_.Exception.Message)" -ForegroundColor Yellow
}

# ============================================================================
# STARTUP CARD (KONSOLE / POWERLINE)
# ============================================================================
$ompv = (Get-Command oh-my-posh -ErrorAction SilentlyContinue)?.Source
$script:StartupCardMaxWidth = 120
$script:StartupShowUrl      = $true

function Get-ConsoleWidth {
  try { [Math]::Max(74, [Math]::Min([int]$Host.UI.RawUI.WindowSize.Width, $script:StartupCardMaxWidth)) }
  catch { $script:StartupCardMaxWidth }
}

function Wrap-Text([string]$Text, [int]$Width) {
  if ($null -eq $Text) { return @('') }
  $Text = $Text -replace "`r",""
  $out = New-Object System.Collections.Generic.List[string]
  foreach ($line in ($Text -split "`n")) {
    $s = $line
    while ($s.Length -gt $Width) { $out.Add($s.Substring(0, $Width)); $s = $s.Substring($Width) }
    $out.Add($s)
  }
  return ,$out.ToArray()
}

function Get-ThemeName([string]$urlOrPath) {
  if ([string]::IsNullOrWhiteSpace($urlOrPath)) { return $null }
  $file = $null
  if (Test-Path $urlOrPath) {
    $file = [IO.Path]::GetFileName((Resolve-Path $urlOrPath).Path)
  } else {
    try { $file = [IO.Path]::GetFileName(([Uri]$urlOrPath).AbsolutePath) } catch { $file = $urlOrPath }
  }
  if ($file -match '\.omp\.json$') { return ($file -replace '\.omp\.json$','') }
  if ($file -match '\.json$') { return ([IO.Path]::GetFileNameWithoutExtension($file)) }
  return $file
}

function Get-PreviewSafeName([string]$name) {
  if ([string]::IsNullOrWhiteSpace($name)) { return $null }
  return ($name -replace '[^\w.-]','_')
}

function Format-Bytes([long]$bytes) {
  if ($bytes -lt 1024) { return "$bytes B" }
  if ($bytes -lt 1024*1024) { return ("{0:N1} KB" -f ($bytes/1024.0)) }
  if ($bytes -lt 1024*1024*1024) { return ("{0:N1} MB" -f ($bytes/1024.0/1024.0)) }
  return ("{0:N2} GB" -f ($bytes/1024.0/1024.0/1024.0))
}

function Try-ParseUtc([string]$s) {
  if ([string]::IsNullOrWhiteSpace($s)) { return $null }

  # 1) ISO / RFC: als UTC erzwingen (robust gegen RoundtripKind-Bugs/Overrides)
  try {
    $styles = [System.Globalization.DateTimeStyles]::AssumeUniversal -bor
              [System.Globalization.DateTimeStyles]::AdjustToUniversal
    $dt = [DateTime]::Parse($s, [System.Globalization.CultureInfo]::InvariantCulture, $styles)
    return [DateTime]::SpecifyKind($dt, [DateTimeKind]::Utc)
  } catch {}

  # 2) Fallback: deine Heuristiken (wie bisher), aber am Ende immer .ToUniversalTime()
  try {
    $now = (Get-Date).ToUniversalTime()
    $cands = New-Object System.Collections.Generic.List[datetime]

    function AddExact([string[]]$formats, $culture, $styles) {
      $dt = [datetime]::MinValue
      if ([datetime]::TryParseExact($s, $formats, $culture, $styles, [ref]$dt)) {
        $cands.Add([DateTime]::SpecifyKind($dt.ToUniversalTime(), [DateTimeKind]::Utc))
      }
    }

    AddExact @('o') ([System.Globalization.CultureInfo]::InvariantCulture) ([System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal)

    $enUS = [System.Globalization.CultureInfo]::GetCultureInfo('en-US')
    $enGB = [System.Globalization.CultureInfo]::GetCultureInfo('en-GB')
    $deDE = [System.Globalization.CultureInfo]::GetCultureInfo('de-DE')

    $mdy    = @('MM/dd/yyyy HH:mm','M/d/yyyy HH:mm','MM/dd/yyyy H:mm','M/d/yyyy H:mm','MM/dd/yyyy HH:mm:ss','M/d/yyyy HH:mm:ss','M/d/yyyy h:mm tt','MM/dd/yyyy h:mm tt')
    $dmy    = @('dd/MM/yyyy HH:mm','d/M/yyyy HH:mm','dd/MM/yyyy H:mm','d/M/yyyy H:mm','dd/MM/yyyy HH:mm:ss','d/M/yyyy HH:mm:ss','d/M/yyyy h:mm tt','dd/MM/yyyy h:mm tt')
    $deDots = @('dd.MM.yyyy HH:mm','d.M.yyyy HH:mm','dd.MM.yyyy H:mm','d.M.yyyy H:mm','dd.MM.yyyy HH:mm:ss','d.M.yyyy HH:mm:ss')

    AddExact $mdy    $enUS ([System.Globalization.DateTimeStyles]::AssumeLocal)
    AddExact $dmy    $enGB ([System.Globalization.DateTimeStyles]::AssumeLocal)
    AddExact $deDots $deDE ([System.Globalization.DateTimeStyles]::AssumeLocal)

    $dt2 = [datetime]::MinValue
    if ([datetime]::TryParse($s, [System.Globalization.CultureInfo]::CurrentCulture, [System.Globalization.DateTimeStyles]::AssumeLocal, [ref]$dt2)) {
      $cands.Add([DateTime]::SpecifyKind($dt2.ToUniversalTime(), [DateTimeKind]::Utc))
    }

    if ($cands.Count -eq 0) { return $null }

    $best = $null
    $bestScore = [double]::PositiveInfinity
    foreach ($c in $cands) {
      $diff = [Math]::Abs(($now - $c).TotalSeconds)
      $futurePenalty = 0
      if ($c -gt $now.AddMinutes(10)) { $futurePenalty = 1e12 }
      $score = $futurePenalty + $diff
      if ($score -lt $bestScore) { $bestScore = $score; $best = $c }
    }

    return $best
  } catch {
    return $null
  }
}

function Show-BoxRow {
  param(
    [Parameter(Mandatory)][string]$Icon,
    [Parameter(Mandatory)][string]$Label,
    [Parameter(Mandatory)][string]$Value,
    [int]$Width,
    [string]$LabelStyle,
    [string]$ValueStyle,
    [string]$Reset
  )

  $innerW = $Width - 2

  # feste Spaltenbreiten für saubere Optik
  $iconCol  = 2   # 1 Leerzeichen + 1 Symbol
  $labelCol = 9   # genug für Preview/Binary/Theme usw.

  $iconText  = (' ' + $Icon).PadRight($iconCol)
  $labelText = $Label.PadRight($labelCol)
  $prefixPlain = $iconText + ' ' + $labelText + ': '
  $valueIndent = (' ' * $prefixPlain.Length)

  $wrapW = [Math]::Max(12, $innerW - $prefixPlain.Length)
  $parts = Wrap-Text $Value $wrapW

  for ($i = 0; $i -lt $parts.Count; $i++) {
    if ($i -eq 0) {
      $leftPlain = $prefixPlain
      $plain = $leftPlain + $parts[$i]
      $padLen = [Math]::Max(0, $innerW - $plain.Length)
      $pad = ' ' * $padLen

      Write-Host -NoNewline '│'
      Write-Host -NoNewline ($LabelStyle + $iconText + ' ' + $labelText + ': ' + $Reset)
      Write-Host -NoNewline ($ValueStyle + $parts[$i] + $Reset)
      Write-Host -NoNewline $pad
      Write-Host '│'
    }
    else {
      $plain = $valueIndent + $parts[$i]
      $padLen = [Math]::Max(0, $innerW - $plain.Length)
      $pad = ' ' * $padLen

      Write-Host -NoNewline '│'
      Write-Host -NoNewline ($LabelStyle + $valueIndent + $Reset)
      Write-Host -NoNewline ($ValueStyle + $parts[$i] + $Reset)
      Write-Host -NoNewline $pad
      Write-Host '│'
    }
  }
}

function Get-PreviewCacheStats {
  param([string]$PreviewDir)
  $res = [ordered]@{ CountPng = 0; BytesPng = 0 }
  if (-not (Test-Path $PreviewDir)) { return $res }
  $pngs = Get-ChildItem -Path $PreviewDir -Filter '*.png' -File -ErrorAction SilentlyContinue
  if ($pngs) {
    $res.CountPng = $pngs.Count
    $res.BytesPng = ($pngs | Measure-Object -Property Length -Sum).Sum
  }
  return $res
}

function Parse-UtcIso([string]$s) {
  if ([string]::IsNullOrWhiteSpace($s)) { return $null }

  $styles =
    [System.Globalization.DateTimeStyles]::AssumeUniversal -bor
    [System.Globalization.DateTimeStyles]::AdjustToUniversal

  $dt = [DateTime]::Parse(
    $s,
    [System.Globalization.CultureInfo]::InvariantCulture,
    $styles
  )

  return [DateTime]::SpecifyKind($dt, [DateTimeKind]::Utc)
}


function Get-ThemePreviewStatus {
  param([string]$PreviewDir, [string]$ThemeName, [int]$TtlHours)

  if ([string]::IsNullOrWhiteSpace($ThemeName)) {
    return [ordered]@{ State='UNKNOWN'; Detail='No theme found.' }
  }

  $safe = Get-PreviewSafeName $ThemeName
  $png  = Join-Path $PreviewDir ($safe + '.png')

  if (-not (Test-Path $png)) {
    return [ordered]@{ State='MISS'; Detail=("No PNG ($safe.png).") }
  }

  $meta = $png + '.meta.json'
  $nowUtc = [DateTimeOffset]::UtcNow

  $pngUtc = $null
  try {
    # File time ist lokal/UTC sauber als DateTimeOffset in UTC
    $pngUtc = [DateTimeOffset]::new((Get-Item $png).LastWriteTimeUtc, [TimeSpan]::Zero)
  } catch { }

  $state  = 'HIT'
  $detail = "PNG: " + (Split-Path $png -Leaf)

  if (Test-Path $meta) {
    try {
      # Wichtig: Hashtable -> Werte bleiben Strings, kein Auto-DateTime
      $m = Get-Content $meta -Raw | ConvertFrom-Json -AsHashtable

	  $checkedUtc  = Parse-UtcIso ([string]$m['LastCheckedUtc'])
      $renderedUtc = Parse-UtcIso ([string]$m['RenderedUtc'])
      
      if (-not $checkedUtc -and $pngUtc)  { $checkedUtc  = $pngUtc }
      if (-not $renderedUtc -and $pngUtc) { $renderedUtc = $pngUtc }
      
      if ($renderedUtc) {
        $rendH = ($nowUtc - $renderedUtc).TotalHours
        if ($rendH -lt 0 -and $pngUtc) {
      	$renderedUtc = $pngUtc
      	$rendH = ($nowUtc - $renderedUtc).TotalHours
        }
      
        if ($rendH -ge $TtlHours) { $state = 'STALE' }
      }
      
      $detail = "PNG: " + (Split-Path $png -Leaf)
      
      if ($checkedUtc) {
        $checkH = ($nowUtc - $checkedUtc).TotalHours
        if ($checkH -lt 0 -and $pngUtc) {
      	$checkedUtc = $pngUtc
      	$checkH = ($nowUtc - $checkedUtc).TotalHours
        }
      
        $detail += " | Check: " + $checkedUtc.ToLocalTime().ToString('g') +
      			 " (" + ([int]$checkH) + "h)"
      }
      
      if ($renderedUtc) {
        $rendH = ($nowUtc - $renderedUtc).TotalHours
        if ($rendH -lt 0 -and $pngUtc) {
      	$renderedUtc = $pngUtc
      	$rendH = ($nowUtc - $renderedUtc).TotalHours
        }
      
        $detail += " | Render: " + $renderedUtc.ToLocalTime().ToString('g') +
      			 " (" + ([int]$rendH) + "h)"
      }
    } catch {
      $detail = "PNG: " + (Split-Path $png -Leaf) + " | Meta unreadable."
    }
  } else {
    if ($pngUtc) {
      $ageH = ($nowUtc - $pngUtc).TotalHours
      $detail = "PNG: " + (Split-Path $png -Leaf) +
                " | Age: " + $pngUtc.ToLocalTime().ToString('g') +
                " (" + ([int]$ageH) + "h)"
    }
  }

  return [ordered]@{ State=$state; Detail=$detail }
}

function Refresh-ThemePreviewIfStale {
  param(
    [Parameter(Mandatory)][string]$PreviewDir,
    [Parameter(Mandatory)][string]$ThemeUrl,
    [Parameter(Mandatory)][string]$ThemeName,
    [int]$TtlHours = 24
  )

  try {
    $st = Get-ThemePreviewStatus -PreviewDir $PreviewDir -ThemeName $ThemeName -TtlHours $TtlHours
    if ($st.State -eq 'STALE' -or $st.State -eq 'MISS') {
      Export-ThemePreviewImage -Url $ThemeUrl -Name $ThemeName -Force | Out-Null
    }
  } catch {}
}



function Show-OMPStartupCard {
  param(
    [string]$LastThemeUrl,
    [string]$RootDir,
    [string]$StorePath,
    [string]$PreviewDir,
    [string]$OhMyPoshPath
  )
  $w = Get-ConsoleWidth
  $vt = $false
  try { $vt = [bool]$Host.UI.SupportsVirtualTerminal } catch {}
  if ($vt -and $PSStyle) {
    $Reset = $PSStyle.Reset
    $HdrBg = $PSStyle.Background.FromRgb(0,92,165)
    $HdrFg = $PSStyle.Foreground.White + $PSStyle.Bold
    $Lbl   = $PSStyle.Foreground.FromRgb(165,165,165)
    $Val   = $PSStyle.Foreground.FromRgb(235,235,235)
    $Key   = $PSStyle.Foreground.FromRgb(255,215,0) + $PSStyle.Bold
    $Hint  = $PSStyle.Foreground.FromRgb(79,193,255)
    $Ok    = $PSStyle.Foreground.FromRgb(120,220,120) + $PSStyle.Bold
    $Warn  = $PSStyle.Foreground.FromRgb(255,170,0) + $PSStyle.Bold
    $Bad   = $PSStyle.Foreground.FromRgb(255,100,100) + $PSStyle.Bold
  } else {
    $Reset=''; $HdrBg=''; $HdrFg=''; $Lbl=''; $Val=''; $Key=''; $Hint=''; $Ok=''; $Warn=''; $Bad=''
  }
  $ttl = 24
  if ($null -ne $script:PreviewMaxAgeHours -and $script:PreviewMaxAgeHours -gt 0) { $ttl = [int]$script:PreviewMaxAgeHours }
  $lastRaw = Resolve-ThemeUrlToRaw (Normalize-ThemeUrl $LastThemeUrl)

  $themeName = (Load-CustomThemes | Where-Object { (Resolve-ThemeUrlToRaw (Normalize-ThemeUrl $_.Url)) -ieq $lastRaw } | Select-Object -First 1 -ExpandProperty Name)

  if (-not $themeName) { $themeName = Get-ThemeName $LastThemeUrl }

  if ($themeName -and $LastThemeUrl) {
  Refresh-ThemePreviewIfStale -PreviewDir $PreviewDir -ThemeUrl $LastThemeUrl -ThemeName $themeName -TtlHours $ttl
	}
  $binPath   = $(if($OhMyPoshPath){ $OhMyPoshPath } else { 'not found' })
  $script:OhMyPoshVersion = "unknown"
	try {
		if ($OhMyPoshPath -and (Test-Path $OhMyPoshPath)) {
			$script:OhMyPoshVersion = (& $OhMyPoshPath version | Select-Object -First 1).Trim()
		}
	} 
	catch {}
  $cacheStats = Get-PreviewCacheStats -PreviewDir $PreviewDir
  $themePrev  = Get-ThemePreviewStatus -PreviewDir $PreviewDir -ThemeName $themeName -TtlHours $ttl
  $stateStyle = $Val
  if ($themePrev.State -eq 'HIT')   { $stateStyle = $Ok }
  if ($themePrev.State -eq 'STALE') { $stateStyle = $Warn }
  if ($themePrev.State -eq 'MISS')  { $stateStyle = $Bad }
  Write-Host ""
  Write-Host ("┌{0}┐" -f ('─' * ($w-2)))
  $title = " oh-my-posh Theme Manager "
  $titleInner = $title.PadRight($w-2)
  Write-Host ("│{0}{1}{2}│" -f ($HdrBg + $HdrFg), $titleInner, $Reset)
  Write-Host ("├{0}┤" -f ('─' * ($w-2)))
  if ($themeName) { Show-BoxRow -Icon '◆' -Label 'Theme' -Value $themeName -Width $w -LabelStyle $Lbl -ValueStyle $Key -Reset $Reset }
  if ($script:StartupShowUrl -and $LastThemeUrl) { Show-BoxRow -Icon '↗' -Label 'URL' -Value $LastThemeUrl -Width $w -LabelStyle $Lbl -ValueStyle $Val -Reset $Reset }
  Show-BoxRow -Icon '›' -Label 'Tipp' -Value "mythemes (Theme Manager UI)" -Width $w -LabelStyle $Lbl -ValueStyle $Hint -Reset $Reset
  Show-BoxRow -Icon '⌂' -Label 'Root' -Value $RootDir -Width $w -LabelStyle $Lbl -ValueStyle $Val -Reset $Reset
  Show-BoxRow -Icon '≣' -Label 'Store' -Value $StorePath -Width $w -LabelStyle $Lbl -ValueStyle $Val -Reset $Reset
  Show-BoxRow -Icon '▣' -Label 'Previews' -Value $PreviewDir -Width $w -LabelStyle $Lbl -ValueStyle $Val -Reset $Reset
  Show-BoxRow -Icon '⛭' -Label 'Binary' -Value $binPath -Width $w -LabelStyle $Lbl -ValueStyle $Val -Reset $Reset
  Show-BoxRow -Icon "Ⓞ" -Label "OMP" -Value $script:OhMyPoshVersion -Width $w -LabelStyle $Lbl -ValueStyle $Val -Reset $Reset
  Show-BoxRow -Icon 'P' -Label 'PS' -Value $PSVersionTable.PSVersion.ToString() -Width $w -LabelStyle $Lbl -ValueStyle $Val -Reset $Reset
  Write-Host ("├{0}┤" -f ('─' * ($w-2)))
  $cacheLine = ("TTL: {0}h | PNGs: {1} | Size: {2}" -f $ttl, $cacheStats.CountPng, (Format-Bytes $cacheStats.BytesPng))
  Show-BoxRow -Icon '⧉' -Label 'Cache' -Value $cacheLine -Width $w -LabelStyle $Lbl -ValueStyle $Val -Reset $Reset
  $prevLine = ("{0} | {1}" -f $themePrev.State, $themePrev.Detail)
  Show-BoxRow -Icon '◎' -Label 'Preview' -Value $prevLine -Width $w -LabelStyle $Lbl -ValueStyle $stateStyle -Reset $Reset
  Write-Host ("└{0}┘" -f ('─' * ($w-2)))
}

try {
  $lastThemeFile = Join-Path $HOME '.posh_last_theme.txt'
  $lastTheme = $null
  if (Test-Path $lastThemeFile) { $lastTheme = (Get-Content $lastThemeFile -Raw).Trim() }
  Show-OMPStartupCard -LastThemeUrl $lastTheme -RootDir $script:RootDir -StorePath $script:CustomThemesFile -PreviewDir $script:PreviewDir -OhMyPoshPath $ompv
} catch {}
