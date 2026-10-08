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

`scripts/prepare-office.sh` pins Microsoft's ODT 16.0.20326.20112 and its
SHA-256, and extracts it with pinned 7-Zip 25.01. The ODT executable is i386
even when installing 64-bit Office, so the x86_64 runtime includes WoW64 PE DLLs.
The script also fetches pinned Microsoft Visual C++ 14.44.35211 x64 and x86
redistributables from Microsoft's versioned download URLs. The installation
batch runs both official installers before ODT, records their exit codes and
logs, and accepts only success or reboot-required status. Wine prefers the
installed native MSVC runtime DLLs. This dependency was identified when the
downloaded Click-to-Run client called an unimplemented Wine CRT exception handler;
its installation and Office editing remain unverified on Android.
`runtime/office/configuration.xml` pins Microsoft 365 16.0.20430.20146, the
Current channel version published by Microsoft's official `v64.cab` on
2026-10-07, and selects Word, Excel and PowerPoint in English.

After HTTPS and Win32 input/save/reopen checks pass, `scripts/office-install-test.py`
stages the official installer in the Android app's shared prefix and launches
ODT there. It verifies staging checksums, records exit status and checks the
three installed executables. Screenshots, OCR, Wine logs and installer logs
are saved under `.build/emulator/office-install/`. Microsoft binaries are not
uploaded as build artifacts or included in APKs. Account activation remains
the user's normal Microsoft licensing flow.

Run [37722194013](https://github.com/tqmane/officedroid/actions/runs/37722194013)
verifies ODT's actual preparation window on Android, but installation stalls
there for 30 minutes. No Office application is installed or verified. Subsequent
runs retain installer-specific network/service traces and post-failure WineDbg
backtraces to identify the wait. An installer exit code and executable presence
remain separate from each application's editing tests.
Run [37738721411](https://github.com/tqmane/officedroid/actions/runs/37738721411)
passes the network regression tests and progresses to downloading, extracting
and launching the official Click-to-Run client. That client encounters a graphics
initialization error followed by the missing CRT exception handler; ODT still
times out. No Microsoft Word, Excel or PowerPoint editing is claimed.
