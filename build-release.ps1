	<#
	build-release.ps1 (Allowlist, robust copy)
	Builds a Firefox .xpi release package in ./release and preserves folder structure.

	Usage:
	  .\build-release.ps1

	Run from the addon root directory (where this script and manifest.json live).
	#>

	$ErrorActionPreference = "Stop"

	# -------- Config --------
	$AddonSlug  = "container-sets"
	$ReleaseDir = "release"

	# Allowlist entries relative to project root.
	# Use folder names (copied recursively) and files (copied as-is).
	$AllowFolders = @("icons", "options", "_locales")
	$AllowFiles   = @("manifest.json", "background.js", "LICENSE", "README.md", "CHANGELOG.md", "CONTRIBUTING.md")

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
	  $parent = Split-Path $dst -Parent
	  Ensure-Dir $parent
	  Copy-Item -Path $src -Destination $dst -Force
	  return $true
	}

	# -------- Main --------
	$ProjectRoot = $PSScriptRoot
	$ManifestPath = Join-Path $ProjectRoot "manifest.json"
	if (-not (Test-Path -Path $ManifestPath)) {
	  throw "manifest.json not found next to this script. Put build-release.ps1 in the addon root and run again."
	}

	# Read version
	$manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
	$version  = $manifest.version
	if ([string]::IsNullOrWhiteSpace($version)) { throw "manifest.json has no 'version'." }

	Write-Host "Building release for $AddonSlug v$version" -ForegroundColor Cyan

	# Prepare release paths (absolute)
	$ReleaseDirFull = Join-Path $ProjectRoot $ReleaseDir
	Ensure-Dir $ReleaseDirFull

	$xpiName = "$AddonSlug-$version.xpi"
	$xpiPath = Join-Path $ReleaseDirFull $xpiName
	$zipPath = [System.IO.Path]::ChangeExtension($xpiPath, ".zip")

	# Remove previous outputs
	Remove-Item -Path $xpiPath -Force -ErrorAction SilentlyContinue
	Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue

	# Create staging dir
	$tempRoot = [System.IO.Path]::GetTempPath()
	if ([string]::IsNullOrWhiteSpace($tempRoot)) { $tempRoot = $ProjectRoot }
	$stageDir = Join-Path $tempRoot ("xpi-stage-{0}" -f ([guid]::NewGuid().ToString("N")))
	Ensure-Dir $stageDir

	try {
	  Write-Host "Staging allowlisted files..." -ForegroundColor Cyan

	  # Copy files
	  foreach ($f in $AllowFiles) {
		$src = Join-Path $ProjectRoot $f
		$dst = Join-Path $stageDir $f
		$ok = Copy-File $src $dst
		if (-not $ok -and ($f -eq "manifest.json" -or $f -eq "background.js")) {
		  throw "Required file missing: $f"
		}
	  }

	  # Copy folders recursively
	  foreach ($d in $AllowFolders) {
		$srcDir = Join-Path $ProjectRoot $d
		$dstDir = Join-Path $stageDir $d
		$ok = Copy-FolderRecursive $srcDir $dstDir
		if (-not $ok -and $d -eq "_locales") {
		  throw "Required folder missing: $d (check that the folder name is exactly '_locales')"
		}
	  }

	  # Ensure manifest.json exists at root of staging
	  if (-not (Test-Path -Path (Join-Path $stageDir "manifest.json"))) {
		throw "ERROR: manifest.json missing from staging root."
	  }

	  Write-Host "Creating ZIP..." -ForegroundColor Cyan
	  Compress-Archive -Path (Join-Path $stageDir "*") -DestinationPath $zipPath -Force

	  if (-not (Test-Path -Path $zipPath)) {
		throw "ERROR: ZIP not created at expected path: $zipPath"
	  }

	  Write-Host "Renaming ZIP to XPI..." -ForegroundColor Cyan
	  if (Test-Path -Path $xpiPath) { Remove-Item -Path $xpiPath -Force }
	  [System.IO.File]::Move($zipPath, $xpiPath)

	  Write-Host "Release created:" -ForegroundColor Green
	  Write-Host "  $xpiPath" -ForegroundColor Green

	  # Verify structure inside XPI
	  Add-Type -AssemblyName System.IO.Compression.FileSystem
	  $zip = [System.IO.Compression.ZipFile]::OpenRead($xpiPath)

	  $hasManifest = $false
	  $hasLocales  = $false
	  $hasOptions  = $false
	  $hasIcons    = $false

		foreach ($e in $zip.Entries) {
		  if ($e.FullName -eq "manifest.json") { $hasManifest = $true }

			if ($e.FullName -match '^_locales[\\/][^\\/]+[\\/]messages\.json$') { $hasLocales = $true }
			if ($e.FullName -match '^options[\\/].+')  { $hasOptions = $true }
		  if ($e.FullName -match '^icons[\\/].+')    { $hasIcons   = $true }
		}


	  $zip.Dispose()

	  if (-not $hasManifest) { throw "ERROR: manifest.json is not at the root of the XPI." }
	  if (-not $hasLocales)  { throw "ERROR: _locales/ folder missing in XPI (needed for i18n)." }
	  if (-not $hasOptions)  { throw "ERROR: options/ folder missing in XPI." }
	  if (-not $hasIcons)    { throw "ERROR: icons/ folder missing in XPI." }

	  Write-Host "Structure OK (_locales/, options/, icons/ present)" -ForegroundColor Green
	  Write-Host "Ready for AMO upload." -ForegroundColor Green
	}
	finally {
	  if (Test-Path -Path $stageDir) {
		Remove-Item -Path $stageDir -Recurse -Force
	  }
	  if (Test-Path -Path $zipPath) {
		Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
	  }
	}
