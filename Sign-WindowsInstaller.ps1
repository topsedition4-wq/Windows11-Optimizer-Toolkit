[CmdletBinding()]
param(
    [string]$Version = "0.1.0",
    [string]$InstallerPath,
    [string]$CertificateThumbprint,
    [string]$CertificateSubject,
    [ValidateSet("CurrentUser", "LocalMachine")]
    [string]$CertificateStoreLocation = "CurrentUser",
    [string]$PfxPath,
    [string]$PfxPasswordEnvironmentVariable = "WINDOWS_CODESIGN_PFX_PASSWORD",
    [switch]$KeepImportedCertificate,
    [string]$SigntoolPath,
    [string]$TimestampServer = "http://timestamp.digicert.com",
    [switch]$UpdateChecksums,
    [switch]$VerifyOnly
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $InstallerPath) {
    $InstallerPath = Join-Path $root "release\installer\Windows11-Optimizer-Toolkit-Setup-$Version.exe"
}

function Resolve-ExistingFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Description was not found: $Path"
    }

    return (Resolve-Path -LiteralPath $Path).Path
}

function Find-SignTool {
    param([string]$RequestedPath)

    if ($RequestedPath) {
        return Resolve-ExistingFile -Path $RequestedPath -Description "signtool.exe"
    }

    $command = Get-Command "signtool.exe" -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $windowsKitsRoot = "C:\Program Files (x86)\Windows Kits\10\bin"
    if (Test-Path -LiteralPath $windowsKitsRoot) {
        $candidate = Get-ChildItem -LiteralPath $windowsKitsRoot -Filter "signtool.exe" -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match "\\x64\\signtool\.exe$" } |
            Sort-Object FullName -Descending |
            Select-Object -First 1

        if ($candidate) {
            return $candidate.FullName
        }
    }

    throw "signtool.exe was not found. Install the Windows SDK or pass -SigntoolPath."
}

function Find-CodeSigningCertificate {
    param(
        [string]$Thumbprint,
        [string]$Subject,
        [ValidateSet("CurrentUser", "LocalMachine")]
        [string]$StoreLocation
    )

    $storePath = "Cert:\$StoreLocation\My"

    if ($Thumbprint) {
        $normalizedThumbprint = ($Thumbprint -replace "\s", "").ToUpperInvariant()
        $certificatePath = Join-Path $storePath $normalizedThumbprint
        if (-not (Test-Path -Path $certificatePath)) {
            throw "Code-signing certificate thumbprint was not found in ${storePath}: $normalizedThumbprint"
        }

        $certificate = Get-Item -Path $certificatePath
    }
    else {
        $certificates = Get-ChildItem -Path $storePath -CodeSigningCert -ErrorAction SilentlyContinue |
            Where-Object { $_.HasPrivateKey -and $_.NotAfter -gt (Get-Date) }

        if ($Subject) {
            $certificates = $certificates | Where-Object { $_.Subject -like "*$Subject*" }
        }

        $certificate = $certificates |
            Sort-Object NotAfter -Descending |
            Select-Object -First 1
    }

    if (-not $certificate) {
        throw "No usable code-signing certificate with a private key was found in $storePath. Microsoft Store will not accept a self-signed certificate."
    }

    if (-not $certificate.HasPrivateKey) {
        throw "The selected certificate does not have a private key: $($certificate.Thumbprint)"
    }

    if ($certificate.NotAfter -le (Get-Date)) {
        throw "The selected certificate is expired: $($certificate.Thumbprint)"
    }

    return $certificate
}

function Import-PfxForSigning {
    param(
        [string]$Path,
        [string]$PasswordEnvironmentVariable
    )

    $resolvedPfx = Resolve-ExistingFile -Path $Path -Description "PFX certificate"
    $passwordValue = [Environment]::GetEnvironmentVariable($PasswordEnvironmentVariable)
    $securePassword = $null

    if ($passwordValue) {
        $securePassword = ConvertTo-SecureString -String $passwordValue -AsPlainText -Force
    }

    $importParams = @{
        FilePath          = $resolvedPfx
        CertStoreLocation = "Cert:\CurrentUser\My"
        Exportable        = $false
    }

    if ($securePassword) {
        $importParams.Password = $securePassword
    }

    $imported = Import-PfxCertificate @importParams
    if (-not $imported) {
        throw "The PFX certificate could not be imported."
    }

    $certificate = @($imported | Where-Object { $_.HasPrivateKey } | Select-Object -First 1)[0]
    if (-not $certificate) {
        throw "The imported PFX did not contain a private key."
    }

    return $certificate
}

function Assert-ValidSignature {
    param(
        [string]$Path,
        [string]$ToolPath
    )

    $signature = Get-AuthenticodeSignature -FilePath $Path
    if ($signature.Status -ne "Valid") {
        throw "Installer signature is not valid. Status: $($signature.Status). $($signature.StatusMessage)"
    }

    & $ToolPath verify /pa /v $Path
    if ($LASTEXITCODE -ne 0) {
        throw "signtool verification failed for: $Path"
    }
}

function Write-Checksums {
    param(
        [string]$Installer,
        [string]$ProjectRoot,
        [string]$AppVersion
    )

    $installerOutputRoot = Split-Path -Parent $Installer
    $hashTargets = @(
        $Installer,
        (Join-Path $ProjectRoot "release\Windows11-Optimizer-Toolkit-v$AppVersion.zip"),
        (Join-Path $ProjectRoot "release\Windows11-Optimizer-Toolkit.zip")
    ) | Where-Object { Test-Path -LiteralPath $_ }

    $hashLines = foreach ($target in $hashTargets) {
        $hash = Get-FileHash -LiteralPath $target -Algorithm SHA256
        "{0}  {1}" -f $hash.Hash.ToLowerInvariant(), (Split-Path -Leaf $target)
    }

    $hashLines | Set-Content -LiteralPath (Join-Path $installerOutputRoot "checksums-sha256.txt") -Encoding UTF8
}

$resolvedInstallerPath = Resolve-ExistingFile -Path $InstallerPath -Description "Installer"
$resolvedSignTool = Find-SignTool -RequestedPath $SigntoolPath
$importedCertificateThumbprint = $null

if ($VerifyOnly) {
    Assert-ValidSignature -Path $resolvedInstallerPath -ToolPath $resolvedSignTool
    Write-Host "Installer signature is valid: $resolvedInstallerPath"
    return
}

try {
    if ($PfxPath) {
        $certificate = Import-PfxForSigning -Path $PfxPath -PasswordEnvironmentVariable $PfxPasswordEnvironmentVariable
        $CertificateThumbprint = $certificate.Thumbprint
        $CertificateStoreLocation = "CurrentUser"
        $importedCertificateThumbprint = $certificate.Thumbprint
    }
    else {
        $certificate = Find-CodeSigningCertificate -Thumbprint $CertificateThumbprint -Subject $CertificateSubject -StoreLocation $CertificateStoreLocation
    }

    $signArgs = @(
        "sign",
        "/fd", "SHA256",
        "/tr", $TimestampServer,
        "/td", "SHA256",
        "/sha1", $certificate.Thumbprint,
        "/s", "My"
    )

    if ($CertificateStoreLocation -eq "LocalMachine") {
        $signArgs += "/sm"
    }

    $signArgs += $resolvedInstallerPath

    & $resolvedSignTool @signArgs
    if ($LASTEXITCODE -ne 0) {
        throw "signtool signing failed for: $resolvedInstallerPath"
    }

    Assert-ValidSignature -Path $resolvedInstallerPath -ToolPath $resolvedSignTool

    if ($UpdateChecksums) {
        Write-Checksums -Installer $resolvedInstallerPath -ProjectRoot $root -AppVersion $Version
    }

    $statusPath = Join-Path (Split-Path -Parent $resolvedInstallerPath) "signing-status.txt"
    @(
        "Installer: $resolvedInstallerPath",
        "Signature status: Valid",
        "Certificate subject: $($certificate.Subject)",
        "Certificate thumbprint: $($certificate.Thumbprint)",
        "Timestamp server: $TimestampServer",
        "Signed at: $((Get-Date).ToString('o'))"
    ) | Set-Content -LiteralPath $statusPath -Encoding UTF8

    Write-Host "Signed installer: $resolvedInstallerPath"
    Write-Host "Signature status: $statusPath"
}
finally {
    if ($importedCertificateThumbprint -and -not $KeepImportedCertificate) {
        $importedPath = "Cert:\CurrentUser\My\$importedCertificateThumbprint"
        if (Test-Path -Path $importedPath) {
            Remove-Item -Path $importedPath -Force
        }
    }
}
