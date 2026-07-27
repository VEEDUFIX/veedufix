param(
  [switch]$SkipShared
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

$targets = @(
  'packages/marketplace_shared',
  'apps/customer_app',
  'apps/worker_app',
  'apps/admin_web'
)

foreach ($target in $targets) {
  if ($SkipShared -and $target -eq 'packages/marketplace_shared') {
    Write-Host "Skipping $target"
    continue
  }

  $path = Join-Path $repoRoot $target
  if (-not (Test-Path (Join-Path $path 'pubspec.yaml'))) {
    throw "Missing pubspec.yaml in $path"
  }

  Write-Host "Running flutter pub get in $target"
  Push-Location $path
  try {
    flutter pub get
  } finally {
    Pop-Location
  }
}

Write-Host 'All Flutter packages are up to date.'
