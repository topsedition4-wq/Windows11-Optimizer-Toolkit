[CmdletBinding()]
param(
    [string]$Version = "0.1.0",
    [string]$Publisher = "Topse Development",
    [string]$InnoCompilerPath,
    [switch]$SignInstaller,
    [string]$CertificateThumbprint,
    [string]$CertificateSubject,
    [ValidateSet("CurrentUser", "LocalMachine")]
    [string]$CertificateStoreLocation = "CurrentUser",
    [string]$PfxPath,
    [string]$PfxPasswordEnvironmentVariable = "WINDOWS_CODESIGN_PFX_PASSWORD",
    [switch]$KeepImportedCertificate,
    [string]$SigntoolPath,
    [string]$TimestampServer = "http://timestamp.digicert.com",
    [switch]$RequireStoreReady
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$installerScript = Join-Path $root "installer\Windows11-Optimizer-Toolkit.iss"
$payloadRoot = Join-Path $root "release\Windows11-Optimizer-Toolkit"
$installerOutputRoot = Join-Path $root "release\installer"
$installerFileName = "Windows11-Optimizer-Toolkit-Setup-$Version.exe"
$installerPath = Join-Path $installerOutputRoot $installerFileName
$checksumsPath = Join-Path $installerOutputRoot "checksums-sha256.txt"
$silentDocSource = Join-Path $root "installer\SILENT-INSTALL.md"
$silentDocTarget = Join-Path $installerOutputRoot "SILENT-INSTALL.md"
$packageUrlSource = Join-Path $root "installer\PACKAGE-URL.md"
$packageUrlTarget = Join-Path $installerOutputRoot "PACKAGE-URL.md"
$storeSigningSource = Join-Path $root "installer\STORE-SIGNING.md"
$storeSigningTarget = Join-Path $installerOutputRoot "STORE-SIGNING.md"

function Find-InnoCompiler {
    param([string]$RequestedPath)

    if ($RequestedPath) {
        if (-not (Test-Path -LiteralPath $RequestedPath)) {
            throw "Inno Setup compiler was not found at: $RequestedPath"
        }
        return (Resolve-Path -LiteralPath $RequestedPath).Path
    }

    $command = Get-Command "ISCC.exe" -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $candidates = @(
        "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
        "C:\Program Files\Inno Setup 6\ISCC.exe"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    return $null
}

if (-not (Test-Path -LiteralPath $installerScript)) {
    throw "Installer script not found: $installerScript"
}

& (Join-Path $root "Create-ReleaseZip.ps1") -Version $Version

New-Item -ItemType Directory -Path $installerOutputRoot -Force | Out-Null

if (Test-Path -LiteralPath $silentDocSource) {
    Copy-Item -LiteralPath $silentDocSource -Destination $silentDocTarget -Force
}

if (Test-Path -LiteralPath $packageUrlSource) {
    Copy-Item -LiteralPath $packageUrlSource -Destination $packageUrlTarget -Force
}

if (Test-Path -LiteralPath $storeSigningSource) {
    Copy-Item -LiteralPath $storeSigningSource -Destination $storeSigningTarget -Force
}

$innoCompiler = Find-InnoCompiler -RequestedPath $InnoCompilerPath
if (-not $innoCompiler) {
    $availableHashTargets = @(
        (Join-Path $root "release\Windows11-Optimizer-Toolkit-v$Version.zip"),
        (Join-Path $root "release\Windows11-Optimizer-Toolkit.zip")
    ) | Where-Object { Test-Path -LiteralPath $_ }

    if ($availableHashTargets.Count -gt 0) {
        $availableHashLines = foreach ($target in $availableHashTargets) {
            $hash = Get-FileHash -LiteralPath $target -Algorithm SHA256
            "{0}  {1}" -f $hash.Hash.ToLowerInvariant(), (Split-Path -Leaf $target)
        }
        $availableHashLines | Set-Content -LiteralPath $checksumsPath -Encoding UTF8
    }

    $compilerNote = @"
Inno Setup 6 compiler was not found on this machine.

Install Inno Setup 6, then run:

PowerShell -ExecutionPolicy Bypass -File .\Build-WindowsInstaller.ps1 -Version $Version -Publisher "$Publisher"

Expected installer output:

release\installer\$installerFileName
"@
    $compilerNote | Set-Content -LiteralPath (Join-Path $installerOutputRoot "BUILD-REQUIRES-INNO-SETUP.txt") -Encoding UTF8
    throw "Inno Setup 6 compiler was not found. Install Inno Setup, then run: .\Build-WindowsInstaller.ps1 -Version $Version"
}

if (Test-Path -LiteralPath $installerPath) {
    Remove-Item -LiteralPath $installerPath -Force
}

& $innoCompiler `
    "/DAppVersion=$Version" `
    "/DPublisher=$Publisher" `
    "/DSourceRoot=$payloadRoot" `
    "/DOutputRoot=$installerOutputRoot" `
    $installerScript

if (-not (Test-Path -LiteralPath $installerPath)) {
    throw "Expected installer was not created: $installerPath"
}

if ($SignInstaller) {
    $signParams = @{
        Version                        = $Version
        InstallerPath                  = $installerPath
        CertificateStoreLocation       = $CertificateStoreLocation
        PfxPasswordEnvironmentVariable = $PfxPasswordEnvironmentVariable
        TimestampServer                = $TimestampServer
        UpdateChecksums                = $true
    }

    if ($CertificateThumbprint) { $signParams.CertificateThumbprint = $CertificateThumbprint }
    if ($CertificateSubject) { $signParams.CertificateSubject = $CertificateSubject }
    if ($PfxPath) { $signParams.PfxPath = $PfxPath }
    if ($KeepImportedCertificate) { $signParams.KeepImportedCertificate = $true }
    if ($SigntoolPath) { $signParams.SigntoolPath = $SigntoolPath }

    & (Join-Path $root "Sign-WindowsInstaller.ps1") @signParams
}
elseif ($RequireStoreReady) {
    $verifyParams = @{
        Version       = $Version
        InstallerPath = $installerPath
        VerifyOnly    = $true
    }

    if ($SigntoolPath) { $verifyParams.SigntoolPath = $SigntoolPath }

    & (Join-Path $root "Sign-WindowsInstaller.ps1") @verifyParams
}

$hashTargets = @(
    $installerPath,
    (Join-Path $root "release\Windows11-Optimizer-Toolkit-v$Version.zip"),
    (Join-Path $root "release\Windows11-Optimizer-Toolkit.zip")
) | Where-Object { Test-Path -LiteralPath $_ }

$hashLines = foreach ($target in $hashTargets) {
    $hash = Get-FileHash -LiteralPath $target -Algorithm SHA256
    "{0}  {1}" -f $hash.Hash.ToLowerInvariant(), (Split-Path -Leaf $target)
}

$hashLines | Set-Content -LiteralPath $checksumsPath -Encoding UTF8

Write-Host "Installer: $installerPath"
Write-Host "Checksums: $checksumsPath"
Write-Host "Silent install parameters are documented in: $silentDocTarget"
