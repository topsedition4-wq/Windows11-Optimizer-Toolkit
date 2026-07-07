[CmdletBinding()]
param(
    [string]$Version = "0.1.0",
    [string]$Publisher = "Topse Development",
    [string]$OutputPath,
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
$releaseRoot = Join-Path $root "release"
$zipPath = Join-Path $releaseRoot "Windows11-Optimizer-Toolkit.zip"
$installerOutputRoot = Join-Path $releaseRoot "installer"
$buildRoot = Join-Path $releaseRoot "win32-setup-build"
$installerFileName = "Windows11-Optimizer-Toolkit-Setup-$Version.exe"

if (-not $OutputPath) {
    $OutputPath = Join-Path $installerOutputRoot $installerFileName
}

& (Join-Path $root "Create-ReleaseZip.ps1") -Version $Version

if (-not (Test-Path -LiteralPath $zipPath)) {
    throw "Release ZIP was not created: $zipPath"
}

New-Item -ItemType Directory -Path $installerOutputRoot -Force | Out-Null
if (Test-Path -LiteralPath $buildRoot) {
    Remove-Item -LiteralPath $buildRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $buildRoot -Force | Out-Null

$cscCandidates = @(
    (Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"),
    (Join-Path $env:WINDIR "Microsoft.NET\Framework\v4.0.30319\csc.exe")
)
$csc = $cscCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $csc) {
    throw "The .NET Framework C# compiler was not found."
}

$payloadBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($zipPath))
$payloadChunks = [regex]::Matches($payloadBase64, ".{1,76}") | ForEach-Object { $_.Value }
$chunkLiterals = ($payloadChunks | ForEach-Object { '            "' + $_ + '"' }) -join ",`r`n"
$escapedVersion = $Version.Replace("\", "\\").Replace('"', '\"')
$escapedPublisher = $Publisher.Replace("\", "\\").Replace('"', '\"')
$versionParts = @($Version.Split("."))
while ($versionParts.Count -lt 4) {
    $versionParts += "0"
}
$assemblyVersion = ($versionParts | Select-Object -First 4) -join "."

$sourcePath = Join-Path $buildRoot "Windows11OptimizerSetup.cs"
$manifestPath = Join-Path $buildRoot "app.manifest"

$manifest = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">
  <trustInfo xmlns="urn:schemas-microsoft-com:asm.v3">
    <security>
      <requestedPrivileges>
        <requestedExecutionLevel level="requireAdministrator" uiAccess="false" />
      </requestedPrivileges>
    </security>
  </trustInfo>
</assembly>
"@
$manifest | Set-Content -LiteralPath $manifestPath -Encoding UTF8

$source = @"
using Microsoft.Win32;
using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;

[assembly: AssemblyTitle("Windows11 Optimizer Toolkit Setup")]
[assembly: AssemblyDescription("Windows11 Optimizer Toolkit Win32 installer")]
[assembly: AssemblyCompany("$escapedPublisher")]
[assembly: AssemblyProduct("Windows11 Optimizer Toolkit")]
[assembly: AssemblyCopyright("Copyright (C) $escapedPublisher")]
[assembly: AssemblyVersion("$assemblyVersion")]
[assembly: AssemblyFileVersion("$assemblyVersion")]

namespace Windows11OptimizerToolkitSetup
{
    internal static class Program
    {
        private const string AppName = "Windows11 Optimizer Toolkit";
        private const string AppVersion = "$escapedVersion";
        private const string Publisher = "$escapedPublisher";
        private const string InstallFolderName = "Windows11OptimizerToolkit";

        [STAThread]
        private static int Main(string[] args)
        {
            bool silent = HasArg(args, "/VERYSILENT") || HasArg(args, "/SILENT") || HasArg(args, "/quiet") || HasArg(args, "/qn");
            bool uninstall = HasArg(args, "/UNINSTALL") || Path.GetFileNameWithoutExtension(Application.ExecutablePath).Equals("unins000", StringComparison.OrdinalIgnoreCase);
            bool fromTemp = HasArg(args, "/FROMTEMP");

            try
            {
                string installDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), InstallFolderName);

                if (uninstall)
                {
                    if (!fromTemp && Application.ExecutablePath.StartsWith(installDir, StringComparison.OrdinalIgnoreCase))
                    {
                        string tempUninstaller = Path.Combine(Path.GetTempPath(), "Windows11OptimizerToolkit-Uninstall-" + Guid.NewGuid().ToString("N") + ".exe");
                        File.Copy(Application.ExecutablePath, tempUninstaller, true);
                        ProcessStartInfo psi = new ProcessStartInfo(tempUninstaller);
                        psi.Arguments = BuildUninstallArgs(args) + " /FROMTEMP";
                        psi.UseShellExecute = true;
                        psi.Verb = "runas";
                        Process.Start(psi);
                        return 0;
                    }

                    Uninstall(installDir);
                    if (!silent)
                    {
                        MessageBox.Show(AppName + " was uninstalled.", AppName, MessageBoxButtons.OK, MessageBoxIcon.Information);
                    }
                    return 0;
                }

                bool createDesktopShortcut = HasTask(args, "desktopicon");
                bool suppressDesktopShortcut = HasMergeTask(args, "!desktopicon");
                if (!silent && !createDesktopShortcut && !suppressDesktopShortcut)
                {
                    DialogResult result = MessageBox.Show("Create a Desktop shortcut?", AppName, MessageBoxButtons.YesNo, MessageBoxIcon.Question);
                    createDesktopShortcut = result == DialogResult.Yes;
                }

                Install(installDir, createDesktopShortcut);
                if (!silent)
                {
                    MessageBox.Show(AppName + " was installed successfully. No optimization actions were applied during installation.", AppName, MessageBoxButtons.OK, MessageBoxIcon.Information);
                }
                return 0;
            }
            catch (Exception ex)
            {
                if (!silent)
                {
                    MessageBox.Show(ex.Message, AppName, MessageBoxButtons.OK, MessageBoxIcon.Error);
                }
                return 1;
            }
        }

        private static void Install(string installDir, bool createDesktopShortcut)
        {
            Directory.CreateDirectory(installDir);
            ExtractPayload(installDir);

            string exePath = Application.ExecutablePath;
            string uninstallerPath = Path.Combine(installDir, "unins000.exe");
            File.Copy(exePath, uninstallerPath, true);

            CreateShortcuts(installDir, createDesktopShortcut);
            RegisterUninstaller(installDir, uninstallerPath);
        }

        private static void Uninstall(string installDir)
        {
            DeleteShortcuts();
            try
            {
                Registry.LocalMachine.DeleteSubKeyTree(@"Software\Microsoft\Windows\CurrentVersion\Uninstall\Windows11OptimizerToolkit", false);
            }
            catch { }

            if (Directory.Exists(installDir))
            {
                Directory.Delete(installDir, true);
            }
        }

        private static void ExtractPayload(string installDir)
        {
            string[] chunks = new string[]
            {
$chunkLiterals
            };
            byte[] zipBytes = Convert.FromBase64String(string.Concat(chunks));
            string tempZip = Path.Combine(Path.GetTempPath(), "Windows11OptimizerToolkit-" + Guid.NewGuid().ToString("N") + ".zip");
            File.WriteAllBytes(tempZip, zipBytes);

            using (ZipArchive archive = ZipFile.OpenRead(tempZip))
            {
                foreach (ZipArchiveEntry entry in archive.Entries)
                {
                    string relative = NormalizeEntryName(entry.FullName);
                    if (string.IsNullOrWhiteSpace(relative))
                    {
                        continue;
                    }

                    string destinationPath = Path.GetFullPath(Path.Combine(installDir, relative));
                    string fullInstallDir = Path.GetFullPath(installDir);
                    if (!destinationPath.StartsWith(fullInstallDir, StringComparison.OrdinalIgnoreCase))
                    {
                        continue;
                    }

                    if (string.IsNullOrEmpty(entry.Name))
                    {
                        Directory.CreateDirectory(destinationPath);
                        continue;
                    }

                    string parent = Path.GetDirectoryName(destinationPath);
                    if (!string.IsNullOrEmpty(parent))
                    {
                        Directory.CreateDirectory(parent);
                    }
                    entry.ExtractToFile(destinationPath, true);
                }
            }

            try { File.Delete(tempZip); } catch { }
        }

        private static string NormalizeEntryName(string entryName)
        {
            string normalized = entryName.Replace('\\', '/').TrimStart('/');
            string prefix = "Windows11-Optimizer-Toolkit/";
            if (normalized.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
            {
                normalized = normalized.Substring(prefix.Length);
            }
            return normalized.Replace('/', Path.DirectorySeparatorChar);
        }

        private static void CreateShortcuts(string installDir, bool createDesktopShortcut)
        {
            string startMenuDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonStartMenu), "Programs", AppName);
            Directory.CreateDirectory(startMenuDir);

            string powershell = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), @"WindowsPowerShell\v1.0\powershell.exe");
            string startScript = Path.Combine(installDir, "Start-Windows11Optimizer.ps1");
            string arguments = "-NoProfile -ExecutionPolicy Bypass -File \"" + startScript + "\"";

            CreateShortcut(Path.Combine(startMenuDir, AppName + ".lnk"), powershell, arguments, installDir, AppName);
            CreateShortcut(Path.Combine(startMenuDir, "Uninstall " + AppName + ".lnk"), Path.Combine(installDir, "unins000.exe"), "/UNINSTALL", installDir, "Uninstall " + AppName);

            if (createDesktopShortcut)
            {
                string desktop = Environment.GetFolderPath(Environment.SpecialFolder.CommonDesktopDirectory);
                CreateShortcut(Path.Combine(desktop, AppName + ".lnk"), powershell, arguments, installDir, AppName);
            }
        }

        private static void DeleteShortcuts()
        {
            string startMenuDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonStartMenu), "Programs", AppName);
            if (Directory.Exists(startMenuDir))
            {
                Directory.Delete(startMenuDir, true);
            }

            string desktopShortcut = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonDesktopDirectory), AppName + ".lnk");
            if (File.Exists(desktopShortcut))
            {
                File.Delete(desktopShortcut);
            }
        }

        private static void RegisterUninstaller(string installDir, string uninstallerPath)
        {
            using (RegistryKey key = Registry.LocalMachine.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Uninstall\Windows11OptimizerToolkit"))
            {
                key.SetValue("DisplayName", AppName);
                key.SetValue("DisplayVersion", AppVersion);
                key.SetValue("Publisher", Publisher);
                key.SetValue("InstallLocation", installDir);
                key.SetValue("DisplayIcon", uninstallerPath);
                key.SetValue("UninstallString", "\"" + uninstallerPath + "\" /UNINSTALL");
                key.SetValue("QuietUninstallString", "\"" + uninstallerPath + "\" /UNINSTALL /VERYSILENT /SUPPRESSMSGBOXES /NORESTART");
                key.SetValue("NoModify", 1, RegistryValueKind.DWord);
                key.SetValue("NoRepair", 1, RegistryValueKind.DWord);
                key.SetValue("EstimatedSize", GetDirectorySizeKb(installDir), RegistryValueKind.DWord);
            }
        }

        private static int GetDirectorySizeKb(string path)
        {
            long total = 0;
            foreach (string file in Directory.GetFiles(path, "*", SearchOption.AllDirectories))
            {
                try { total += new FileInfo(file).Length; } catch { }
            }
            return (int)Math.Max(1, total / 1024);
        }

        private static string BuildUninstallArgs(string[] args)
        {
            StringBuilder builder = new StringBuilder("/UNINSTALL");
            foreach (string arg in args)
            {
                if (!arg.Equals("/UNINSTALL", StringComparison.OrdinalIgnoreCase) && !arg.Equals("/FROMTEMP", StringComparison.OrdinalIgnoreCase))
                {
                    builder.Append(' ').Append(arg);
                }
            }
            return builder.ToString();
        }

        private static bool HasArg(string[] args, string value)
        {
            foreach (string arg in args)
            {
                if (arg.Equals(value, StringComparison.OrdinalIgnoreCase))
                {
                    return true;
                }
            }
            return false;
        }

        private static bool HasTask(string[] args, string task)
        {
            foreach (string arg in args)
            {
                if (arg.StartsWith("/TASKS=", StringComparison.OrdinalIgnoreCase) && arg.IndexOf(task, StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    return true;
                }
            }
            return false;
        }

        private static bool HasMergeTask(string[] args, string task)
        {
            foreach (string arg in args)
            {
                if (arg.StartsWith("/MERGETASKS=", StringComparison.OrdinalIgnoreCase) && arg.IndexOf(task, StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    return true;
                }
            }
            return false;
        }

        private static void CreateShortcut(string shortcutPath, string targetPath, string arguments, string workingDirectory, string description)
        {
            IShellLinkW link = (IShellLinkW)new ShellLink();
            link.SetPath(targetPath);
            link.SetArguments(arguments);
            link.SetWorkingDirectory(workingDirectory);
            link.SetDescription(description);
            IPersistFile file = (IPersistFile)link;
            file.Save(shortcutPath, true);
        }
    }

    [ComImport]
    [Guid("00021401-0000-0000-C000-000000000046")]
    internal class ShellLink { }

    [ComImport]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    [Guid("000214F9-0000-0000-C000-000000000046")]
    internal interface IShellLinkW
    {
        void GetPath([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszFile, int cchMaxPath, IntPtr pfd, uint fFlags);
        void GetIDList(out IntPtr ppidl);
        void SetIDList(IntPtr pidl);
        void GetDescription([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszName, int cchMaxName);
        void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string pszName);
        void GetWorkingDirectory([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszDir, int cchMaxPath);
        void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string pszDir);
        void GetArguments([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszArgs, int cchMaxPath);
        void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string pszArgs);
        void GetHotkey(out short pwHotkey);
        void SetHotkey(short wHotkey);
        void GetShowCmd(out int piShowCmd);
        void SetShowCmd(int iShowCmd);
        void GetIconLocation([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszIconPath, int cchIconPath, out int piIcon);
        void SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string pszIconPath, int iIcon);
        void SetRelativePath([MarshalAs(UnmanagedType.LPWStr)] string pszPathRel, uint dwReserved);
        void Resolve(IntPtr hwnd, uint fFlags);
        void SetPath([MarshalAs(UnmanagedType.LPWStr)] string pszFile);
    }

    [ComImport]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    [Guid("0000010b-0000-0000-C000-000000000046")]
    internal interface IPersistFile
    {
        void GetClassID(out Guid pClassID);
        void IsDirty();
        void Load([MarshalAs(UnmanagedType.LPWStr)] string pszFileName, uint dwMode);
        void Save([MarshalAs(UnmanagedType.LPWStr)] string pszFileName, bool fRemember);
        void SaveCompleted([MarshalAs(UnmanagedType.LPWStr)] string pszFileName);
        void GetCurFile([MarshalAs(UnmanagedType.LPWStr)] out string ppszFileName);
    }
}
"@

$source | Set-Content -LiteralPath $sourcePath -Encoding UTF8

if (Test-Path -LiteralPath $OutputPath) {
    Remove-Item -LiteralPath $OutputPath -Force
}

& $csc `
    /nologo `
    /target:winexe `
    /optimize+ `
    /out:$OutputPath `
    /win32manifest:$manifestPath `
    /reference:System.Windows.Forms.dll `
    /reference:System.IO.Compression.dll `
    /reference:System.IO.Compression.FileSystem.dll `
    $sourcePath

if (-not (Test-Path -LiteralPath $OutputPath)) {
    throw "The compiler did not create the expected setup EXE: $OutputPath"
}

if ($SignInstaller) {
    $signParams = @{
        Version                        = $Version
        InstallerPath                  = $OutputPath
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
        InstallerPath = $OutputPath
        VerifyOnly    = $true
    }

    if ($SigntoolPath) { $verifyParams.SigntoolPath = $SigntoolPath }

    & (Join-Path $root "Sign-WindowsInstaller.ps1") @verifyParams
}

foreach ($doc in @("SILENT-INSTALL.md", "PACKAGE-URL.md", "STORE-SIGNING.md")) {
    $sourceDoc = Join-Path $root "installer\$doc"
    if (Test-Path -LiteralPath $sourceDoc) {
        Copy-Item -LiteralPath $sourceDoc -Destination (Join-Path $installerOutputRoot $doc) -Force
    }
}

$hashTargets = @(
    $OutputPath,
    (Join-Path $releaseRoot "Windows11-Optimizer-Toolkit-v$Version.zip"),
    (Join-Path $releaseRoot "Windows11-Optimizer-Toolkit.zip")
) | Where-Object { Test-Path -LiteralPath $_ }

$hashLines = foreach ($target in $hashTargets) {
    $hash = Get-FileHash -LiteralPath $target -Algorithm SHA256
    "{0}  {1}" -f $hash.Hash.ToLowerInvariant(), (Split-Path -Leaf $target)
}

$hashLines | Set-Content -LiteralPath (Join-Path $installerOutputRoot "checksums-sha256.txt") -Encoding UTF8

Write-Host "Win32 setup EXE created: $OutputPath"
Write-Host "Checksums: $(Join-Path $installerOutputRoot 'checksums-sha256.txt')"
