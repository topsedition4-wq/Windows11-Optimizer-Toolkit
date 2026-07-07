# Installer Build

This project uses Inno Setup 6 for the Windows installer.

Build command:

```powershell
.\Build-WindowsInstaller.ps1 -Version 0.1.0 -Publisher "Topse Development"
```

Microsoft Store build command with code signing:

```powershell
.\Build-WindowsInstaller.ps1 -Version 0.1.0 -Publisher "Topse Development" -SignInstaller -CertificateThumbprint "<THUMBPRINT>"
```

Output:

```text
release\installer\Windows11-Optimizer-Toolkit-Setup-0.1.0.exe
release\installer\checksums-sha256.txt
release\installer\SILENT-INSTALL.md
release\installer\STORE-SIGNING.md
```

The installer copies the toolkit to `C:\Program Files\Windows11OptimizerToolkit\`, creates Start Menu shortcuts, optionally creates a Desktop shortcut, and registers an Inno Setup uninstaller.

The installer intentionally has no `[Run]` action. It does not launch the toolkit and does not apply debloat or optimization actions during install.

For Microsoft Store submission, the final `.exe` must be signed with a trusted code-signing certificate and must pass:

```powershell
.\Sign-WindowsInstaller.ps1 -InstallerPath .\release\installer\Windows11-Optimizer-Toolkit-Setup-0.1.0.exe -VerifyOnly
```
