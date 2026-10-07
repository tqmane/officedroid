# Office compatibility and installation gates

No Office binary, installer or license material is part of this repository.
No successful Office installation or launch is claimed.

The intended distribution path is the [Microsoft Office Deployment Tool](https://www.microsoft.com/en-us/download/details.aspx?id=49117)
and [Microsoft's deployment documentation](https://learn.microsoft.com/en-us/microsoft-365-apps/deploy/overview-office-deployment-tool).
After wineboot and Win32 GUI/input work, test official ODT extraction,
`setup.exe /download configuration.xml`, then `/configure`, recording versions,
exit codes, Click-to-Run logs and Wine channels. Downloading files is not proof of
installation. Do not request account credentials in logs or commit installer payloads.

Known areas requiring evidence: App-V / Click-to-Run services, COM activation,
DLL overrides, msxml/riched/gdiplus, fonts/DirectWrite/Direct2D, licensing services,
WinRT authentication, browser redirects and WebView. Fonts and native Microsoft
DLLs must not be obtained from unlicensed redistributions.

Reviewed Linux references:

- [Troplo/office-install.sh](https://github.com/Troplo/office-install.sh): README
  reports broken Microsoft login, update restrictions and Excel flicker. It is
  not evidence for modern Android or reliable Microsoft 365 authentication.
- [aldobox/Office365LinuxInstaller](https://github.com/aldobox/Office365LinuxInstaller):
  distinguishes VM extraction from beta direct C2R installation, and documents
  Wine installer limitations. A transferred Windows installation does not prove
  ODT works under Wine.
- Soda's recent Office changes are catalogued in [soda-analysis.md](soda-analysis.md).

ODT execution remains behind the Wine runtime gate. This is an unrun check,
not a diagnosed Microsoft installer defect.
