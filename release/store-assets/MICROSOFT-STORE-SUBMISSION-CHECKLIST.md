# Microsoft Store Submission Checklist

Use this checklist for the Windows11 Optimizer Toolkit EXE/MSI submission.

## Availability

- Markets: Required. Use all markets unless you want to restrict sales.
- Discoverability: Required. Choose public Store listing or link-only.
- Pricing: Required. Choose Free, Paid, Freemium, or Subscription.
- Free trial: Required if pricing is Paid.

## Properties

- Category: Required. Recommended: Utilities & tools.
- Subcategory: Optional.
- Product access to personal information: Required answer.
  - Recommended answer for current app design: No, because the app runs locally and does not transmit telemetry.
  - If Microsoft still asks for a privacy URL, use the privacy policy URL below.
- Privacy policy URL:
  - https://topsedition4-wq.github.io/Windows11-Optimizer-Toolkit/privacy-policy.html
- Website:
  - https://github.com/topsedition4-wq/Windows11-Optimizer-Toolkit
- Support URL:
  - https://topsedition4-wq.github.io/Windows11-Optimizer-Toolkit/support.html
- Contact details: Required for business/company accounts.

## Age Ratings

- Complete all questionnaire pages.
- Recommended answers for this utility:
  - No violence.
  - No sexual content.
  - No gambling.
  - No user-generated content.
  - No social sharing.
  - No unrestricted web browser.
  - No location sharing.
  - No purchases inside the app unless you actually add them.

## Packages

- Package URL:
  - https://topsedition4-wq.github.io/Windows11-Optimizer-Toolkit/packages/Windows11-Optimizer-Toolkit-Setup-0.1.0.exe
- Code signing:
  - Required. The installer must pass `.\Sign-WindowsInstaller.ps1 -InstallerPath .\release\installer\Windows11-Optimizer-Toolkit-Setup-0.1.0.exe -VerifyOnly`.
  - Microsoft Store will reject an unsigned installer under policy `10.2.9 Security - Package Submissions`.
  - A self-signed certificate is not enough. Use a trusted code-signing certificate or Microsoft Trusted Signing.
- Architecture: x64.
- Language: English.
- App type: EXE.
- Silent install parameters:
  - /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /MERGETASKS="!desktopicon"
- Silent uninstall parameters:
  - /VERYSILENT /SUPPRESSMSGBOXES /NORESTART
- Do not add duplicate packages for the same architecture/language.

## Store Listing

- Description: Required.
- Screenshots: Required. Minimum 1, recommended 4+.
- Store logos: Required 1:1 box art. 2:3 poster art recommended.
- Applicable license terms: Required.
- Short description: Optional but recommended.
- App features: Optional but recommended.
- Keywords: Optional, max 7 terms.
- Developed by: Optional. Use Topse Development.

## If Submit Is Still Disabled

- Open every left-side section and click Save, even if it looks complete.
- Reopen Store listings, verify English listing is saved.
- Check if any red validation message appears under images, package, age rating, or license terms.
- Remove duplicate package rows for the same architecture/language.
- Wait a few minutes after package validation, then refresh.
- If all sections show Complete but Submit is still blocked, contact Partner Center support with the exact error text and timestamp.
