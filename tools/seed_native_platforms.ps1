$ErrorActionPreference = 'Stop'

$flutterSdk = 'C:\flutter'
$androidTemplateRoot = Join-Path $flutterSdk 'packages\flutter_tools\templates\app'
$iosTemplateRoot = Join-Path $flutterSdk 'packages\flutter_tools\templates\app\ios.tmpl'
$androidCommonTemplate = Join-Path $androidTemplateRoot 'android.tmpl'
$androidKotlinTemplate = Join-Path $androidTemplateRoot 'android-kotlin.tmpl'

$apps = @(
  @{
    Root = 'C:\Users\AAA\Documents\veedufix\apps\customer_app'
    DisplayName = 'VeeduFix'
    AndroidId = 'com.veedufix.customer'
    IosId = 'com.veedufix.customer'
  },
  @{
    Root = 'C:\Users\AAA\Documents\veedufix\apps\worker_app'
    DisplayName = 'VeeduFix Partner'
    AndroidId = 'com.veedufix.partner'
    IosId = 'com.veedufix.partner'
  }
)

function Get-TargetPath {
  param(
    [string]$SourceRoot,
    [string]$DestinationRoot,
    [string]$SourceFile
  )

  $relative = $SourceFile.Substring($SourceRoot.Length).TrimStart('\')
  $relative = $relative -replace '\.copy\.tmpl$', ''
  $relative = $relative -replace '\.img\.tmpl$', '.png'
  $relative = $relative -replace '\.tmpl$', ''
  return Join-Path $DestinationRoot $relative
}

function Copy-TemplateTree {
  param(
    [string]$SourceRoot,
    [string]$DestinationRoot,
    [hashtable]$Replacements
  )

  if (-not (Test-Path $SourceRoot)) {
    throw "Missing template root: $SourceRoot"
  }

  Get-ChildItem -LiteralPath $SourceRoot -Recurse -File | ForEach-Object {
    $targetPath = Get-TargetPath -SourceRoot $SourceRoot -DestinationRoot $DestinationRoot -SourceFile $_.FullName
    $targetDir = Split-Path $targetPath -Parent
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null

    $sourceName = $_.Name
    $binarySource = $sourceName.EndsWith('.png') -or $sourceName.EndsWith('.ico') -or $sourceName.EndsWith('.jpg') -or $sourceName.EndsWith('.jpeg') -or $sourceName.EndsWith('.img.tmpl') -or $sourceName.EndsWith('.copy.tmpl')

    if ($binarySource) {
      Copy-Item -LiteralPath $_.FullName -Destination $targetPath -Force
      return
    }

    $content = Get-Content -LiteralPath $_.FullName -Raw
    foreach ($entry in $Replacements.GetEnumerator()) {
      $content = $content.Replace($entry.Key, $entry.Value)
    }

    Set-Content -LiteralPath $targetPath -Value $content -NoNewline -Encoding UTF8
  }
}

function Seed-Android {
  param(
    [string]$AppRoot,
    [string]$DisplayName,
    [string]$AndroidId
  )

  $destination = Join-Path $AppRoot 'android'
  if (Test-Path $destination) {
    Remove-Item -Recurse -Force $destination
  }

  $replacements = @{
    '{{projectName}}' = $DisplayName
    '{{androidIdentifier}}' = $AndroidId
  }

  Copy-TemplateTree -SourceRoot $androidCommonTemplate -DestinationRoot $destination -Replacements $replacements
  Copy-TemplateTree -SourceRoot $androidKotlinTemplate -DestinationRoot $destination -Replacements $replacements
}

function Seed-Ios {
  param(
    [string]$AppRoot,
    [string]$DisplayName,
    [string]$IosId
  )

  $destination = Join-Path $AppRoot 'ios'
  if (Test-Path $destination) {
    Remove-Item -Recurse -Force $destination
  }

  $replacements = @{
    '{{projectName}}' = $DisplayName
    '{{titleCaseProjectName}}' = $DisplayName
    '{{iosIdentifier}}' = $IosId
  }

  Copy-TemplateTree -SourceRoot $iosTemplateRoot -DestinationRoot $destination -Replacements $replacements
}

foreach ($app in $apps) {
  Seed-Android -AppRoot $app.Root -DisplayName $app.DisplayName -AndroidId $app.AndroidId
  Seed-Ios -AppRoot $app.Root -DisplayName $app.DisplayName -IosId $app.IosId
}

Write-Host 'Seeded native platform folders for customer and worker apps.'
