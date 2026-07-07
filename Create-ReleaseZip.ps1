[CmdletBinding()]
param(
    [string]$Version = "0.1.0"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$releaseRoot = Join-Path $root "release\Windows11-Optimizer-Toolkit"
$zipPath = Join-Path $root "release\Windows11-Optimizer-Toolkit-v$Version.zip"
$zipAliasPath = Join-Path $root "release\Windows11-Optimizer-Toolkit.zip"

$resolvedRoot = (Resolve-Path -LiteralPath $root).Path
$releaseParent = Join-Path $root "release"
if (-not (Test-Path -LiteralPath $releaseParent)) {
    New-Item -ItemType Directory -Path $releaseParent -Force | Out-Null
}

if (Test-Path -LiteralPath $releaseRoot) {
    $resolvedRelease = (Resolve-Path -LiteralPath $releaseRoot).Path
    if (-not $resolvedRelease.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Safety check failed. Refusing to remove release folder outside project root: $resolvedRelease"
    }
    Remove-Item -LiteralPath $releaseRoot -Recurse -Force
}

New-Item -ItemType Directory -Path $releaseRoot -Force | Out-Null

$files = @(
    "README.md",
    "LICENSE.txt",
    "CHANGELOG.md",
    "Start-Windows11Optimizer.ps1",
    "Optimize-Windows11.ps1",
    "Undo-Windows11.ps1",
    "Install-UpdateGuard.ps1",
    "Uninstall-UpdateGuard.ps1",
    "Invoke-DebloatGuard.ps1",
    "Create-ReleaseZip.ps1",
    "Sign-WindowsInstaller.ps1"
)

foreach ($file in $files) {
    Copy-Item -LiteralPath (Join-Path $root $file) -Destination (Join-Path $releaseRoot $file) -Force
}

foreach ($folder in @("config", "docs", "gui", "lib")) {
    Copy-Item -LiteralPath (Join-Path $root $folder) -Destination (Join-Path $releaseRoot $folder) -Recurse -Force
}

foreach ($folder in @("logs", "backups", "reports")) {
    $target = Join-Path $releaseRoot $folder
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $target ".gitkeep") -Force | Out-Null
}

$sampleReport = @"
Windows11-Optimizer-Toolkit Sample Dry Run Report
Mode: Safe
Dry Run: True
AppsRemovedOrWouldRemove: 0
ProvisionedAppsRemovedOrWouldRemove: 0
ServicesChangedOrWouldChange: 0
ScheduledTasksDisabledOrWouldDisable: 0
RegistryChangesAppliedOrWouldApply: 0
SkippedItems: 0
FailedItems: 0
RestorePointStatus: Skipped
RebootRecommended: True
"@
$sampleReport | Set-Content -LiteralPath (Join-Path $releaseRoot "reports\sample-dry-run-report.txt") -Encoding UTF8

if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}
if (Test-Path -LiteralPath $zipAliasPath) {
    Remove-Item -LiteralPath $zipAliasPath -Force
}

Compress-Archive -LiteralPath $releaseRoot -DestinationPath $zipPath -Force
Copy-Item -LiteralPath $zipPath -Destination $zipAliasPath -Force

Write-Host "Release folder: $releaseRoot"
Write-Host "Release ZIP: $zipPath"
Write-Host "Release ZIP alias: $zipAliasPath"
