# Upstream and license inventory

OfficeDroid-authored code is MIT. This does not relicense upstream code.
Downloaded SDKs, toolchains and Wine source/build outputs are excluded from Git.
The current diagnostic APK contains only project code and test-independent Android
platform integration; it contains no Microsoft or Wine binaries.

| Project | License / use in this revision |
| --- | --- |
| [Wine](https://github.com/wine-mirror/wine/blob/wine-11.0/LICENSE) | LGPL-2.1-or-later; separately downloaded cross-build experiment |
| [Bottles](https://github.com/bottlesdevs/Bottles) | GPL-3.0; research only |
| [Soda / Bottles Wine](https://github.com/bottlesdevs/wine) | Wine-derived, per-file and patch notices must be retained; research only |
| [Bottles build-tools](https://github.com/bottlesdevs/build-tools) | Inspected scripts carry MIT notices; research only |
| [Wine-Staging](https://github.com/wine-staging/wine-staging) | Inspect per-patch licensing before any import; metadata reviewed, not built |
| [Valve Wine / Proton](https://github.com/ValveSoftware/wine) | Wine and component-specific licenses; Soda source dependency reviewed |
| [Wine-TKG](https://github.com/Frogging-Family/wine-tkg-git) | Per-script/patch licenses; Soda build dependency reviewed |
| [FEX](https://github.com/FEX-Emu/FEX), [Box64](https://github.com/ptitSeb/box64), [Box86](https://github.com/ptitSeb/box86) | MIT projects, with separately licensed dependencies; research only |
| [Hangover](https://github.com/AndreRH/hangover) | LGPL-2.1 repository, component notices still apply; research only |
| [Winlator](https://github.com/brunodev85/winlator) | LGPL-2.1 repository and separately licensed bundled components; research only |
| [LLVM-MinGW](https://github.com/mstorsjo/llvm-mingw) | Build tool, LLVM/MinGW/runtime licenses; not distributed in APK |
| Android SDK/NDK | Google's SDK terms and bundled open-source notices; downloaded by setup |

If distributing a Wine APK later, ship corresponding Wine source, patches, build
instructions and LGPL notices, and preserve the user's ability to replace/relink
the LGPL component as required. Inventory each bundled font, DLL, library and
translator before release. Do not assume the GitHub repository-level license
covers every binary in a release.

Office, Microsoft authentication material and Microsoft trademark icons are not
bundled. Launchers use Android's generic icon until project artwork is supplied.
