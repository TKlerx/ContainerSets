param(
  
  [ValidateNotNullOrEmpty()]
  [string]$IconInput = "icon-master.png",

  [ValidateNotNullOrEmpty()]
  [string]$OutDir = "icons",

  [ValidateSet(256, 512, 1024)]
  [int]$Canvas = 512
)

$ErrorActionPreference = "Stop"

function Die($msg) { throw $msg }
function IsBlank([string]$s) { [string]::IsNullOrWhiteSpace($s) }

# --- Print environment sanity (helps on locked-down systems) ---
Write-Host "PSVersion: $($PSVersionTable.PSVersion)" -ForegroundColor Cyan
Write-Host "PWD      : $((Get-Location).Path)" -ForegroundColor Cyan
Write-Host "Input: '$IconInput'" -ForegroundColor Cyan
Write-Host "OutDir   : '$OutDir'" -ForegroundColor Cyan

# --- Check magick is available ---
$magickCmd = Get-Command magick -ErrorAction SilentlyContinue
if (-not $magickCmd) {
  Die "Command 'magick' not found. Install ImageMagick: choco install imagemagick -y  (then reopen PowerShell)."
}
Write-Host "magick   : $($magickCmd.Source)" -ForegroundColor Cyan

# --- Resolve input to full path without Resolve-Path pitfalls ---
# Resolve relative paths against the script directory (NOT the process CurrentDirectory)
$base = $PSScriptRoot

if ([System.IO.Path]::IsPathRooted($IconInput)) {
  $inputFull = $IconInput
} else {
  $inputFull = Join-Path $base $IconInput
}
$inputFull = [System.IO.Path]::GetFullPath($inputFull)

if ([System.IO.Path]::IsPathRooted($OutDir)) {
  $outFull = $OutDir
} else {
  $outFull = Join-Path $base $OutDir
}
$outFull = [System.IO.Path]::GetFullPath($outFull)



Write-Host "InputFull: '$inputFull'" -ForegroundColor Cyan

if (IsBlank($inputFull)) { Die "InputFull path resolved to empty string (unexpected)." }
if (-not (Test-Path -Path $inputFull)) { Die "Input file not found: $inputFull" }

# --- Ensure OutDir exists ---
# Use GetFullPath + Directory.CreateDirectory (no Test-Path LiteralPath)
Write-Host "OutFull  : '$outFull'" -ForegroundColor Cyan
if (IsBlank($outFull)) { Die "OutFull resolved to empty string (unexpected)." }

[System.IO.Directory]::CreateDirectory($outFull) | Out-Null
if (-not (Test-Path -Path $outFull)) { Die "Could not create output directory: $outFull" }

# --- Temp file: avoid env vars entirely ---
$tempDir = [System.IO.Path]::GetTempPath()
if (IsBlank($tempDir)) { $tempDir = $outFull }  # fallback
$tempSquare = Join-Path $tempDir ("icon-square-{0}.png" -f ([guid]::NewGuid().ToString("N")))

Write-Host "TempDir  : '$tempDir'" -ForegroundColor Cyan
Write-Host "TempFile : '$tempSquare'" -ForegroundColor Cyan
if (IsBlank($tempSquare)) { Die "TempSquare path is empty (unexpected)." }

try {
  Write-Host "`n[1/2] Create square canvas ${Canvas}x${Canvas}..." -ForegroundColor Green
  & magick $inputFull -background none -gravity center -extent "${Canvas}x${Canvas}" $tempSquare

  if (-not (Test-Path -Path $tempSquare)) {
    Die "Temp square image was not created: $tempSquare"
  }

  Write-Host "`n[2/2] Create icons..." -ForegroundColor Green

  $targets = @(
    @{ Size = 128; Name = "icon-128.png"; Extra = @() },
    @{ Size = 96; Name = "icon-96.png"; Extra = @() },
    @{ Size = 48; Name = "icon-48.png"; Extra = @() },
    @{ Size = 32; Name = "icon-32.png"; Extra = @() },
    @{ Size = 16; Name = "icon-16.png"; Extra = @("-unsharp","0x1") }
  )

  foreach ($t in $targets) {
    $size = $t.Size
    $outFile = Join-Path $outFull $t.Name

    Write-Host ("  -> {0}x{0}: {1}" -f $size, $outFile) -ForegroundColor Gray
    & magick $tempSquare -filter Lanczos -resize "${size}x${size}" @($t.Extra) $outFile

    if (-not (Test-Path -Path $outFile)) {
      Die "Failed to create: $outFile"
    }
  }

  Write-Host "`nDone ✅" -ForegroundColor Cyan
  Get-ChildItem -Path $outFull -Filter "icon-*.png" | Select-Object Name, Length, FullName
}
finally {
  if (-not (IsBlank($tempSquare)) -and (Test-Path -Path $tempSquare)) {
    Remove-Item -Path $tempSquare -Force
  }
}
