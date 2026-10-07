# Upstream and license inventory

OfficeDroid-authored code is MIT. This does not relicense upstream code.
Downloaded SDKs, toolchains and Wine source/build outputs are excluded from Git.
The default diagnostic APK excludes Wine. The optional Wine APK contains Wine,
its bundled libraries/fonts, and FreeType, with upstream notices in
`assets/licenses/`. No APK includes Microsoft binaries. Gradle's wrapper remains
under its Apache-2.0 source notice.

| Project | License / use in this revision |
| --- | --- |
| [Wine](https://github.com/wine-mirror/wine/blob/wine-11.0/LICENSE) | LGPL-2.1-or-later, with bundled component notices; optional APK runtime |
| [FreeType 2.13.3](https://github.com/freetype/freetype/blob/VER-2-13-3/LICENSE.TXT) | FreeType License (FTL) selected, with contributed component notices; host font tool and optional APK runtime |
| [Bottles](https://github.com/bottlesdevs/Bottles) | GPL-3.0; research only |
| [Soda / Bottles Wine](https://github.com/bottlesdevs/wine) | Wine-derived, per-file and patch notices must be retained; research only |
| [Bottles build-tools](https://github.com/bottlesdevs/build-tools) | Inspected scripts carry MIT notices; research only |
| [Wine-Staging](https://github.com/wine-staging/wine-staging) | Inspect per-patch licensing before any import; metadata reviewed, not built |
| [Valve Wine / Proton](https://github.com/ValveSoftware/wine) | Wine and component-specific licenses; Soda source dependency reviewed |
| [Wine-TKG](https://github.com/Frogging-Family/wine-tkg-git) | Per-script/patch licenses; Soda build dependency reviewed |
| [FEX](https://github.com/FEX-Emu/FEX), [Box64](https://github.com/ptitSeb/box64), [Box86](https://github.com/ptitSeb/box86) | MIT projects, with separately licensed dependencies; research only |
| [Hangover](https://github.com/AndreRH/hangover) | LGPL-2.1 repository, component notices still apply; research only |
| [Winlator](https://github.com/brunodev85/winlator) | LGPL-2.1 repository and separately licensed bundled components; research only |
| [LLVM-MinGW](https://github.com/mstorsjo/llvm-mingw) | Build tool; LLVM and MinGW runtime notices are included for code linked into PE binaries |
| Android SDK/NDK | Google's SDK terms and bundled open-source notices; downloaded by setup |

Portions of this software are copyright © 1996–2024 The FreeType Project
(www.freetype.org). All rights reserved.

Wine workflow artifacts include the exact unmodified Wine and FreeType sources
and the complete OfficeDroid source revision containing patches and build scripts.
The APK's license assets retain Wine's LGPL, author list, bundled-library notices,
FreeType notices, and LLVM/MinGW notices. The runtime is not signature-locked:
users can modify/rebuild/repackage it using the documented scripts and their own
Android signing key. Reverse engineering for debugging changes to LGPL components
is permitted. Wine modifications in `patches/wine/` retain LGPL-2.1-or-later.
Any future translator, font or proprietary library needs its own inventory.

Office, Microsoft authentication material and Microsoft trademark icons are not
bundled. Launchers use Android's generic icon until project artwork is supplied.
