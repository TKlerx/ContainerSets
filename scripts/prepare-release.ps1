<#
  prepare-release.ps1
  Moves CHANGELOG "Unreleased" section into a new version section based on manifest.json version.
  Also ensures Unreleased section exists afterwards.

  Usage:
    pwsh ./scripts/prepare-release.ps1

  Typical flow:
    - Update code
    - Add notes under [Unreleased]
    - Bump manifest.json version
    - Run this script
    - Commit
    - Tag vX.Y.Z and push
#>

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$manifestPath = Join-Path $repoRoot "manifest.json"
$changelogPath = Join-Path $repoRoot "CHANGELOG.md"

if (-not (Test-Path $manifestPath)) { throw "manifest.json not found at $manifestPath" }
if (-not (Test-Path $changelogPath)) { throw "CHANGELOG.md not found at $changelogPath" }

$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
$version  = $manifest.version
if ([string]::IsNullOrWhiteSpace($version)) { throw "manifest.json has no version" }

# basic SemVer check (relaxed: 1.2.3)
if ($version -notmatch '^\d+\.\d+\.\d+$') {
  throw "manifest.json version '$version' is not in MAJOR.MINOR.PATCH format"
}

$content = Get-Content $changelogPath -Raw

# Find Unreleased section (Keep a Changelog style)
# Captures content until next "## " header or end
$unreleasedPattern = "(?ms)^\s*##\s*\[Unreleased\]\s*(?:-.*)?\s*$\r?\n(?<body>.*?)(?=^\s*##\s|\z)"
$unreleasedMatch = [regex]::Match($content, $unreleasedPattern)

if (-not $unreleasedMatch.Success) {
  throw "No '## [Unreleased]' section found in CHANGELOG.md"
}

$unreleasedBody = $unreleasedMatch.Groups["body"].Value.Trim()
if ([string]::IsNullOrWhiteSpace($unreleasedBody)) {
  throw "Unreleased section is empty. Add notes under '## [Unreleased]' before preparing a release."
}

# Prevent duplicate version section
$versionHeaderPattern = "(?m)^\s*##\s*(?:\[$([regex]::Escape($version))\]|$([regex]::Escape($version)))\b"
if ([regex]::IsMatch($content, $versionHeaderPattern)) {
  throw "CHANGELOG already contains a section for version $version"
}

$date = (Get-Date).ToString("yyyy-MM-dd")
$newVersionHeader = "## [$version] - $date"

# Replace the Unreleased section with:
# - Unreleased header (empty)
# - New version section with previous Unreleased body
$replacement = @"
## [Unreleased]

$newVersionHeader
$unreleasedBody

"@

$content2 = [regex]::Replace($content, $unreleasedPattern, $replacement, 1)

# Write back
Set-Content -Path $changelogPath -Value $content2.TrimEnd() + "`n" -Encoding utf8

Write-Host "Prepared release notes for $version ($date) from [Unreleased]." -ForegroundColor Green
Write-Host "Updated: $changelogPath" -ForegroundColor Green
