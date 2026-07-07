# Windows11-Optimizer-Toolkit

Windows11-Optimizer-Toolkit is a PowerShell-first Windows 11 debloat, optimization, rollback, and Update Guard toolkit with a light WinForms interface.

It is designed to be adaptive and consent-based. It checks whether a package, service, task, registry key, or feature exists before changing it, logs every action, writes undo data, and skips protected Windows components.

> This tool does not disable Defender, Firewall, Windows Update, Smart Card support, Clipboard/Win+V, Microsoft Store, WebView2 Runtime, core device services, or core Windows shell components.

## Run the GUI

Open PowerShell as Administrator:

```powershell
.\Start-Windows11Optimizer.ps1
```

The launcher will attempt to relaunch itself elevated if needed.

## Command Line

```powershell
.\Optimize-Windows11.ps1 -Mode Safe
.\Optimize-Windows11.ps1 -Mode Gaming
.\Optimize-Windows11.ps1 -Mode Extreme
.\Optimize-Windows11.ps1 -Mode Gaming -DryRun
.\Optimize-Windows11.ps1 -Mode Extreme -CreateRestorePoint -ConfirmExtreme
.\Optimize-Windows11.ps1 -Mode Gaming -InstallUpdateGuard -GuardMode Conservative
.\Undo-Windows11.ps1 -UndoFilePath ".\backups\undo-file.json"
.\Install-UpdateGuard.ps1 -GuardMode Conservative
.\Uninstall-UpdateGuard.ps1
```

Extreme mode requires explicit confirmation. In non-interactive automation, pass `-ConfirmExtreme` only after reading the warning.

## Modes

Safe Mode is for normal users. It removes obvious consumer bloatware if present, disables tips and suggestions, disables legacy services such as Fax and RetailDemo if present, keeps Microsoft Store, Windows Update, Defender, Firewall, Smart Card, clipboard, Win+V, Xbox, OneDrive, Edge, WebView2, and core system services.

Gaming Mode includes Safe Mode plus lower background activity settings, reduced telemetry, reduced feedback prompts, Windows Search set to Manual by default, and GameDVR disabled by default. It does not disable audio, input, Bluetooth, USB, networking, core device services, Smart Card, Defender, Firewall, Store, or Windows Update.

Extreme Debloat Mode includes Gaming Mode plus more aggressive scheduled task and content delivery reductions. It uses maximum practical telemetry reduction without breaking Windows. It does not claim complete telemetry elimination and does not remove protected system components.

## Risk Levels

Safe means low-risk for most Windows 11 users and usually easy to reverse.

Medium Risk means a convenience, integration, telemetry path, search behavior, gaming overlay, or app experience may stop working or need reinstall.

High Risk means the action can break a user workflow, Windows convenience, Xbox/Game Pass, OneDrive sync, Widgets, Edge-dependent flows, or require manual reinstall. These actions require extra confirmation.

## Dry Run

Dry Run shows what would happen without making changes:

```powershell
.\Optimize-Windows11.ps1 -Mode Gaming -DryRun
```

Dry runs still create logs and reports, but they do not remove packages, change services, disable tasks, set registry values, or install Update Guard.

## Restore Point

Before real optimization, the toolkit attempts to create a restore point named `Before Debloat` unless `-SkipRestorePoint` is passed. If restore point creation fails, the GUI shows the failure and allows the user to cancel or continue.

Manual restore point:

```powershell
.\Optimize-Windows11.ps1 -Mode Safe -CreateRestorePoint
```

The GUI also has a `Create Restore Point Now` button.

## Undo

Undo data is written to:

```text
backups/undo-[timestamp].json
```

Undo attempts to restore:

- Service startup types.
- Scheduled task enabled states.
- Registry values.
- Startup entries.
- Update Guard settings where applicable.

Some Appx package removals may not be perfectly reversible and may require reinstall from Microsoft Store or winget.

## Update Guard

Update Guard creates visible scheduled tasks under:

```text
\Windows11Optimizer\DebloatGuard\
```

It preserves the selected debloat profile by detecting and repairing drift after updates. It does not block security updates. It does not disable Windows Update, BITS, TrustedInstaller, Defender, Firewall, Store, WebView2, Smart Card, clipboard, core device services, or core shell.

Install:

```powershell
.\Install-UpdateGuard.ps1 -GuardMode Conservative
```

Manual scan:

```powershell
.\Invoke-DebloatGuard.ps1 -GuardMode Conservative
```

Uninstall:

```powershell
.\Uninstall-UpdateGuard.ps1
```

Uninstalling Update Guard removes only the toolkit scheduled tasks unless you explicitly request guard config removal. It does not undo debloat changes.

## Optional High-Risk Warnings

Edge removal is never default. Some Windows components and apps may rely on Edge. WebView2 Runtime is never removed.

OneDrive removal is never default. Cloud-only files may become unavailable locally. The toolkit does not delete OneDrive folders or user files.

Xbox, Xbox Identity Provider, Gaming Services, and Game Bar removal can break Game Pass, Store games, Xbox sign-in, overlays, and captures.

Windows Search indexing changes can make Start Menu search and file search slower.

Extreme Mode is aggressive and should be tested in a VM before regular use.

## Local Policy Cleanup

The GUI label is `Local Policy Cleanup — personal device only`.

This feature is only for personally owned devices where local policies were left behind by old scripts, old work/school accounts, OEM tools, or user mistakes.

If the device appears domain-joined, Entra ID joined, MDM-enrolled, Intune-managed, school-managed, work-managed, or organization-managed, the toolkit does not remove policies and shows:

```text
This device appears to be organization-managed. Corporate policy removal is not supported.
```

This toolkit is not a corporate restriction bypass tool.

## Package a Release

```powershell
.\Create-ReleaseZip.ps1
```

The output is:

```text
release/Windows11-Optimizer-Toolkit/
release/Windows11-Optimizer-Toolkit-v0.1.0.zip
```

## Windows Installer

The Windows installer uses Inno Setup. It installs the toolkit to:

```text
C:\Program Files\Windows11OptimizerToolkit\
```

Build the installer:

```powershell
.\Build-WindowsInstaller.ps1 -Version 0.1.0 -Publisher "Topse Development"
```

Build and sign the installer for Microsoft Store submission:

```powershell
.\Build-WindowsInstaller.ps1 -Version 0.1.0 -Publisher "Topse Development" -SignInstaller -CertificateThumbprint "<THUMBPRINT>"
```

If Inno Setup is not installed locally and you need a quick Win32 validation package, build the fallback setup executable:

```powershell
.\Build-Win32SetupFallback.ps1 -Version 0.1.0 -Publisher "Topse Development"
```

The Microsoft Store requires the installer to be signed with a trusted code-signing certificate. A self-signed certificate will not pass certification. Verify before submitting:

```powershell
.\Sign-WindowsInstaller.ps1 -InstallerPath .\release\installer\Windows11-Optimizer-Toolkit-Setup-0.1.0.exe -VerifyOnly
```

Expected output:

```text
release/installer/Windows11-Optimizer-Toolkit-Setup-0.1.0.exe
release/installer/checksums-sha256.txt
release/installer/SILENT-INSTALL.md
release/installer/PACKAGE-URL.md
```

The installer creates a Start Menu shortcut, offers an optional Desktop shortcut, and registers a normal Windows uninstaller. It does not run the app after install and does not apply any debloat or optimization actions during install.

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

Microsoft Store Package URL format:

```text
https://topsedition4-wq.github.io/Windows11-Optimizer-Toolkit/packages/Windows11-Optimizer-Toolkit-Setup-0.1.0.exe
```

Use a direct `HTTP 200 OK` package URL with no redirect. GitHub Release asset URLs commonly redirect and may be rejected by Partner Center. For the included publishing flow, configure the GitHub Actions signing secrets documented in `installer/STORE-SIGNING.md`, push tag `v0.1.0`, publish the signed installer to the GitHub Pages `packages/` path, then use that static URL in Partner Center.

## Optional Standalone EXE Wrapper

The recommended release is a ZIP because PowerShell scripts are transparent and auditable. If you need an EXE wrapper, use a reputable PowerShell-to-EXE wrapper such as PS2EXE and point it at `Start-Windows11Optimizer.ps1`. Keep the scripts, configs, docs, logs, backups, and reports folders visible beside the wrapper. Do not obfuscate the toolkit.

## Project Layout

See the final section of this README and the `docs/` folder for architecture, safety, mode behavior, Update Guard behavior, and VM testing checklists.
