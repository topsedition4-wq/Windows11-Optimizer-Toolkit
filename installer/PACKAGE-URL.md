# Package URL For Microsoft Store

Use this Package URL only after the uploaded installer is signed with a trusted code-signing certificate. It is a static GitHub Pages URL and should return `HTTP 200 OK` directly with no redirect:

```text
https://topsedition4-wq.github.io/Windows11-Optimizer-Toolkit/packages/Windows11-Optimizer-Toolkit-Setup-0.1.0.exe
```

Previous URL validation performed:

```text
HTTP/1.1 200 OK
Content-Length: 181248
Content-Type: application/octet-stream
No Location header / no redirect
Magic bytes: MZ
SHA256: 12e0fb6a1d78d93901c0169c4e44f765897b54d55eef6ed9c32dcb7a6c4595be
```

That SHA256 belongs to the earlier unsigned installer. After signing, upload the new signed `.exe` and replace this hash with the new SHA256 from `release\installer\checksums-sha256.txt`.

Required local signing check before resubmission:

```powershell
.\Sign-WindowsInstaller.ps1 -InstallerPath .\release\installer\Windows11-Optimizer-Toolkit-Setup-0.1.0.exe -VerifyOnly
```

Fallback non-redirect raw URL:

```text
https://raw.githubusercontent.com/topsedition4-wq/Windows11-Optimizer-Toolkit/5232a2c8da4f29289d714a917de448c85a9a0f97/packages/Windows11-Optimizer-Toolkit-Setup-0.1.0.exe
```

Do not use the GitHub Release URL for Partner Center if it rejects redirects. GitHub Release asset URLs redirect to asset storage.
