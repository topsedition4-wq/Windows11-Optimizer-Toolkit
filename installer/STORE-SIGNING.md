# Microsoft Store Code Signing

Microsoft Store Win32 package certification requires the submitted installer and any included Portable Executable files to be digitally signed with a trusted code-signing certificate. A self-signed certificate is not enough for Store certification.

The installer must pass:

```powershell
Get-AuthenticodeSignature .\Windows11-Optimizer-Toolkit-Setup-0.1.0.exe
```

Expected result:

```text
Status: Valid
SignatureType: Authenticode
```

## Local signing with an installed certificate

Install a real code-signing certificate into `Cert:\CurrentUser\My` or `Cert:\LocalMachine\My`, then run:

```powershell
.\Sign-WindowsInstaller.ps1 -InstallerPath .\release\installer\Windows11-Optimizer-Toolkit-Setup-0.1.0.exe -CertificateThumbprint "<THUMBPRINT>" -UpdateChecksums
```

Or sign while building:

```powershell
.\Build-WindowsInstaller.ps1 -Version 0.1.0 -Publisher "Topse Development" -SignInstaller -CertificateThumbprint "<THUMBPRINT>"
```

## Local signing with a PFX

Store the PFX password in an environment variable, then sign:

```powershell
$env:WINDOWS_CODESIGN_PFX_PASSWORD = "<PFX_PASSWORD>"
.\Sign-WindowsInstaller.ps1 -InstallerPath .\release\installer\Windows11-Optimizer-Toolkit-Setup-0.1.0.exe -PfxPath .\codesign.pfx -UpdateChecksums
```

The script imports the PFX into `Cert:\CurrentUser\My`, signs the installer using SHA256 with timestamping, verifies the signature, updates `checksums-sha256.txt`, then removes the imported certificate unless `-KeepImportedCertificate` is passed.

## GitHub Actions signing

Set these repository secrets:

```text
WINDOWS_CODE_SIGNING_PFX_BASE64
WINDOWS_CODE_SIGNING_PASSWORD
```

`WINDOWS_CODE_SIGNING_PFX_BASE64` must be the Base64 contents of the `.pfx` file. The workflow decodes it into the runner temp folder, imports it only for the signing step, signs the installer, verifies the signature, and updates checksums.

## Store submission rule

Do not submit the package URL until:

```powershell
.\Sign-WindowsInstaller.ps1 -InstallerPath .\release\installer\Windows11-Optimizer-Toolkit-Setup-0.1.0.exe -VerifyOnly
```

passes successfully.
