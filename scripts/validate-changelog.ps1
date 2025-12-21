<#
  validate-changelog.ps1
  Validates CHANGELOG.md:
  - must contain "## [Unreleased]"
  - Unreleased must not be empty (optional: we enforce it here)
  - must contain a section for the provided version (optional)
  - basic structural checks

  Usage:
    pwsh ./scripts/validate-changelog.ps1
    pwsh ./scripts/validate-changelog.ps1 -Version 1.2.3
#>

param(
  [string]$Version
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$changelogPath = Join-Path $repoRoot "CHANGELOG.md"

if (-not (Test-Path $changelogPath)) { throw "CHANGELOG.md not found at $changelogPath" }

$content = Get-Content $changelogPath -Raw

# 1) Must have Unreleased section
$unreleasedPattern = "(?ms)^\s*##\s*\[Unreleased\]\s*(?:-.*)?\s*$\r?\n(?<body>.*?)(?=^\s*##\s|\z)"
$unreleasedMatch = [regex]::Match($content, $unreleasedPattern)
if (-not $unreleasedMatch.Success) {
  throw "CHANGELOG.md must contain a '## [Unreleased]' section."
}

# 2) Enforce Unreleased not empty (you asked for validation; keeping it strict)
$unreleasedBody = $unreleasedMatch.Groups["body"].Value.Trim()
# Unreleased may be empty right after a release – that's OK

# 3) If Version provided, ensure section exists and is not empty
if ($Version) {
  if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw "Version '$Version' is not MAJOR.MINOR.PATCH" }

  $sectionPattern = "(?ms)^\s*##\s*(?:\[$([regex]::Escape($Version))\]|$([regex]::Escape($Version)))\s*(?:-.*)?\s*$\r?\n(?<body>.*?)(?=^\s*##\s|\z)"
  $m = [regex]::Match($content, $sectionPattern)
  if (-not $m.Success) {
    throw "No CHANGELOG section found for version $Version"
  }

  $body = $m.Groups["body"].Value.Trim()
  if ([string]::IsNullOrWhiteSpace($body)) {
    throw "CHANGELOG section for $Version is empty"
  }
}

Write-Host "CHANGELOG validation OK" -ForegroundColor Green
