# Soda / Microsoft 365 investigation

Inspected [bottlesdevs/wine, soda branch](https://github.com/bottlesdevs/wine/tree/2a6c0950e2294e088c591a0bf45836778433155d),
its README, `.github/workflows/build-soda.yml`, and Office patch contents/names.
Also inspected [Bottles](https://github.com/bottlesdevs/Bottles) metadata and
[build-tools](https://github.com/bottlesdevs/build-tools) build/dependency scripts.
Bottles is a Linux manager, not an Android runtime. Its historical build-tools
scripts assume Linux multilib, desktop dependencies and mutable build inputs;
they are unsuitable as the Android setup script.

The inspected Soda 11.0-27 experimental workflow pins Valve Wine, Wine-TKG,
Proton and FEX revisions. Its own release notes describe an Office startup TLS
regression fixed after Soda 26, and continuing Office startup/document crashes.
Therefore “Soda 11 works” is not a sufficient compatibility specification.

Candidate groups to isolate and test, not yet ported:

| Area | Upstream evidence | Android consideration |
| --- | --- | --- |
| Runtime APIs | `office-runtime-apis.mypatch`, `kernel32-office-compat.mypatch` | Kernel32/Kernelbase and ntdll API behavior needs focused PE tests |
| Web/WinRT | `windows-web-http-json.mypatch`, `office-winappsdk-webview2.mypatch` | COM activation, HTTP/JSON and WebView bootstrap differ from a working browser |
| Identity | Soda Identity Bridge and web-token patches | Linux broker/desktop credential store must be replaced with Android secure storage and browser return handling |
| Rendering | `d2d1-office-rendering.mypatch`, `win32u-fix-office-font-rendering.mypatch`, composition patches | Validate Direct2D, text, clipping and surfaces on wineandroid |
| Linux windows | X11/Wayland Office patches | Do not transplant driver-specific fixes into Android blindly |
| File state | Office native-storage-lock and shared-mode patches | Exercise simultaneous applications and document locks in one prefix |

No Office patch is claimed necessary or sufficient without an A/B experiment.
No patch set has been imported yet. Future imports must record source commit,
license, dependencies, patch application result and a regression test. Authentication
changes must preserve real Microsoft authentication and licensing.
