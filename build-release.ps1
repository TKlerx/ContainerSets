<#
build-release.ps1 (Allowlist, cross-platform, self-test)
Builds a Firefox .xpi release package in ./release and preserves folder structure.

Usage:
  pwsh ./build-release.ps1

Run from the addon root directory (where this script and manifest.json live).
#>

$ErrorActionPreference = "Stop"

# -------- Config --------
$AddonSlug  = "container-sets"
$ReleaseDir = "release"

# Allowlist entries relative to project root.
$AllowFolders = @("icons", "options", "_locales")
$AllowFiles   = @(
  "manifest.json",
  "background.js",
  "LICENSE",
  "README.md",
  "CHANGELOG.md",
  "CONTRIBUTING.md"
)

# -------- Helpers --------
function Ensure-Dir([string]$path) {
  if (-not (Test-Path -Path $path)) {
    New-Item -ItemType Directory -Path $path -Force | Out-Null
  }
}

function Copy-FolderRecursive([string]$srcDir, [string]$dstDir) {
  if (-not (Test-Path -Path $srcDir)) { return $false }
  Ensure-Dir $dstDir
  Copy-Item -Path (Join-Path $srcDir "*") -Destination $dstDir -Recurse -Force
  return $true
}

function Copy-File([string]$src, [string]$dst) {
  if (-not (Test-Path -Path $src)) { return $false }
  Ensure-Dir (Split-Path $dst -Parent)
  Copy-Item -Path $src -Destination $dst -Force
  return $true
}

# -------- XPI verification --------
function Verify-XpiStructure([string]$xpiPath) {
  try { Add-Type -AssemblyName System.IO.Compression } catch {}
  try { Add-Type -AssemblyName System.IO.Compression.FileSystem } catch {}

  if (-not (Test-Path $xpiPath)) {
    throw "XPI not found: $xpiPath"
  }

  $zip = [System.IO.Compression.ZipFile]::OpenRead($xpiPath)
  try {
    $hasManifest = $false
    $hasLocales  = $false
    $hasOptions  = $false
    $hasIcons    = $false

    foreach ($e in $zip.Entries) {
      # ❌ Firefox requires "/" – never "\"
      if ($e.FullName -match '\\') {
        throw "INVALID ZIP ENTRY: '$($e.FullName)' contains backslashes"
      }

      if ($e.FullName -eq "manifest.json") {
        $hasManifest = $true
      }

      if ($e.FullName -match '^_locales/[^/]+/messages\.json$') {
        $hasLocales = $true
      }

      if ($e.FullName -match '^options/.+') {
        $hasOptions = $true
      }

      if ($e.FullName -match '^icons/.+') {
        $hasIcons = $true
      }
    }

    if (-not $hasManifest) { throw "manifest.json missing at XPI root" }
    if (-not $hasLocales)  { throw "_locales/<lang>/messages.json missing" }
    if (-not $hasOptions)  { throw "options/ folder missing" }
    if (-not $hasIcons)    { throw "icons/ folder missing" }
  }
  finally {
    $zip.Dispose()
  }
}

# -------- Self test (explicit CI guard) --------
function Self-TestXpi([string]$xpiPath) {
  Write-Host "Running XPI self-test..." -ForegroundColor Cyan

  Verify-XpiStructure $xpiPath

  # Extra: list entries count (useful CI signal)
  $zip = [System.IO.Compression.ZipFile]::OpenRead($xpiPath)
  try {
    $count = $zip.Entries.Count
    if ($count -lt 5) {
      throw "XPI suspiciously small ($count entries)"
    }
    Write-Host "Self-test OK ($count entries)" -ForegroundColor Green
  }
  finally {
    $zip.Dispose()
  }
}

# -------- Main --------
$ProjectRoot  = $PSScriptRoot
$ManifestPath = Join-Path $ProjectRoot "manifest.json"

if (-not (Test-Path $ManifestPath)) {
  throw "manifest.json not found next to this script"
}

$manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
$version  = $manifest.version
if ([string]::IsNullOrWhiteSpace($version)) {
  throw "manifest.json has no 'version'"
}

Write-Host "Building release for $AddonSlug v$version" -ForegroundColor Cyan

$ReleaseDirFull = Join-Path $ProjectRoot $ReleaseDir
Ensure-Dir $ReleaseDirFull

$xpiName = "$AddonSlug-$version.xpi"
$xpiPath = Join-Path $ReleaseDirFull $xpiName
$zipPath = [System.IO.Path]::ChangeExtension($xpiPath, ".zip")

Remove-Item $xpiPath -Force -ErrorAction SilentlyContinue
Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

$tempRoot = [System.IO.Path]::GetTempPath()
if ([string]::IsNullOrWhiteSpace($tempRoot)) { $tempRoot = $ProjectRoot }

$stageDir = Join-Path $tempRoot ("xpi-stage-{0}" -f ([guid]::NewGuid().ToString("N")))
Ensure-Dir $stageDir

try {
  Write-Host "Staging allowlisted files..." -ForegroundColor Cyan

  foreach ($f in $AllowFiles) {
    $ok = Copy-File (Join-Path $ProjectRoot $f) (Join-Path $stageDir $f)
    if (-not $ok -and ($f -eq "manifest.json" -or $f -eq "background.js")) {
      throw "Required file missing: $f"
    }
  }

  foreach ($d in $AllowFolders) {
    $ok = Copy-FolderRecursive (Join-Path $ProjectRoot $d) (Join-Path $stageDir $d)
    if (-not $ok -and $d -eq "_locales") {
      throw "Required folder missing: _locales"
    }
  }

  if (-not (Test-Path (Join-Path $stageDir "manifest.json"))) {
    throw "manifest.json missing from staging root"
  }

  # -------- ZIP creation (cross-platform safe) --------
  Write-Host "Creating ZIP..." -ForegroundColor Cyan
  try { Add-Type -AssemblyName System.IO.Compression } catch {}
  try { Add-Type -AssemblyName System.IO.Compression.FileSystem } catch {}

  $zipFs = [System.IO.File]::Open($zipPath, [System.IO.FileMode]::CreateNew)
  $zip   = [System.IO.Compression.ZipArchive]::new(
             $zipFs,
             [System.IO.Compression.ZipArchiveMode]::Create,
             $false
           )

  try {
    $stageFull = (Resolve-Path $stageDir).Path.TrimEnd(
      [System.IO.Path]::DirectorySeparatorChar,
      [System.IO.Path]::AltDirectorySeparatorChar
    )

    Get-ChildItem -Path $stageFull -Recurse -File | ForEach-Object {
      $fileFull = $_.FullName

      $rel = $fileFull.Substring($stageFull.Length).TrimStart(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
      )

      $entryName = $rel -replace '\\','/'
      $entryName = $entryName -replace '^\.\/',''
      $entryName = $entryName -replace '\/\/+','/'

      $entry = $zip.CreateEntry(
        $entryName,
        [System.IO.Compression.CompressionLevel]::Optimal
      )

      $inStream  = [System.IO.File]::OpenRead($fileFull)
      $outStream = $entry.Open()
      try { $inStream.CopyTo($outStream) }
      finally {
        $outStream.Dispose()
        $inStream.Dispose()
      }
    }
  }
  finally {
    $zip.Dispose()
    $zipFs.Dispose()
  }

  Write-Host "Renaming ZIP to XPI..." -ForegroundColor Cyan
  [System.IO.File]::Move($zipPath, $xpiPath)

  Write-Host "Release created:" -ForegroundColor Green
  Write-Host "  $xpiPath" -ForegroundColor Green

  # -------- Self test --------
  Self-TestXpi $xpiPath

  Write-Host "Ready for AMO upload." -ForegroundColor Green
}
finally {
  if (Test-Path $stageDir) {
    Remove-Item $stageDir -Recurse -Force
  }
  if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
  }
}
