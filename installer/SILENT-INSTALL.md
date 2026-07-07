# Windows11 Optimizer Toolkit Silent Install

Installer:

```powershell
Windows11-Optimizer-Toolkit-Setup-0.1.0.exe
```

Default install location:

```text
C:\Program Files\Windows11OptimizerToolkit\
```

Silent install without Desktop shortcut:

```powershell
.\Windows11-Optimizer-Toolkit-Setup-0.1.0.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /MERGETASKS="!desktopicon"
```

Silent install with Desktop shortcut:

```powershell
.\Windows11-Optimizer-Toolkit-Setup-0.1.0.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /TASKS="desktopicon"
```

Silent uninstall:

```powershell
& "C:\Program Files\Windows11OptimizerToolkit\unins000.exe" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART
```

Microsoft Store submission note:

```text
Install command: Windows11-Optimizer-Toolkit-Setup-0.1.0.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /MERGETASKS="!desktopicon"
Uninstall command: "C:\Program Files\Windows11OptimizerToolkit\unins000.exe" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART
```

Before using the Package URL in Partner Center, verify that the installer is code signed:

```powershell
.\Sign-WindowsInstaller.ps1 -InstallerPath .\release\installer\Windows11-Optimizer-Toolkit-Setup-0.1.0.exe -VerifyOnly
```

The installer only copies files, creates Start Menu/Desktop shortcuts, and registers the uninstaller. It does not run the application after install and does not apply debloat or optimization actions during install.
