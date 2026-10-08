# OfficeDroid

Research and implementation of a shared, app-managed Wine runtime for Windows
Word, Excel and PowerPoint on Android tablets. No Termux, PRoot, root or external
Linux distribution is part of the application architecture.

**Development prototype; no Office editing screen has been verified.** The active
target is ARM64 Android on standard GitHub-hosted runners. Wine 11.0 with ARM64EC,
FEX, TLS and Kerberos builds and packages locally; host tests and Android lint pass.
The ARM64 Android emulator currently reaches ADB but crashes in ART during boot.
CI also evaluates native ARM64 Android container infrastructure and records its
sandbox differences. See [current test evidence](docs/testing.md).

Historical Android 16 x86_64 runs verify Wine initialization, HTTPS, network/RPC
providers and native/WoW64 Notepad editing, saving and cold reopening. Official
Office installation still fails during App-V XML manifest merging. A pinned
Microsoft MSXML6 experiment is prepared but has not run on ARM64. Authentication,
Office editing, SAF write-back and concurrent graphical lifecycle remain unfinished.

## Build and test

Linux x86_64 cross-build host; the active Android execution target is `arm64-v8a`.
Use an existing checkout. Cloud tasks are already isolated; no worktree is needed.

```sh
./scripts/setup.sh --wine
./scripts/build.sh
./scripts/build-wine.sh arm64-v8a
python3 scripts/package-wine.py arm64-v8a
./scripts/build.sh -PwineRuntime=true
```

Setup detects missing JDK and Wine build tools. SDK 36, NDK r28c, CMake/Ninja,
Gradle 8.13 and pinned LLVM-MinGW/ARM64EC toolchains are installed locally with verified downloads. Ubuntu
uses APT when required; Debian read-only cloud images use signed APT downloads
and local extraction. Sources, downloads and outputs are ignored by Git.
Allow roughly 50 GB for tools, runtime builds, the emulator and Office validation.
The default APK excludes Wine. `-PwineRuntime=true` includes the locally packaged
ABIs; Windows PE/data assets go into private storage, while Unix executable code
is installed by Android's package manager. No Microsoft binaries are included.

```sh
./scripts/emulator-test.sh
# After packaging Wine and rebuilding the APK:
./scripts/emulator-test.sh -PwineRuntime=true
```

The emulator script installs pinned Android 16 ARM64 components and uses a
2560×1600 landscape test display. Standard ARM runners lack usable VM acceleration;
the current emulator experiment uses QEMU TCG on a Linux build host. Boot failures
remain failures, and Office tests require all runtime checks first. Actions retains
APK/source artifacts and separate boot, runtime, installer and editing evidence.
The native Android container experiment is separate test infrastructure; it is not
an application dependency and does not establish stock Android sandbox compatibility.

Minimum Android is 10 / API 29; compile/target SDK is 36. Older-device behavior and
ARM64 Android runtime behavior must be tested separately from cross-compilation.

## Office setup

There is currently no validated installation path. Do not copy Office into the
repository or APK. Future installation must use Microsoft's official distribution
and the user's license, in one shared private prefix. See
[compatibility investigation](docs/office-compatibility.md).

## Status and design

- [Architecture](docs/architecture.md)
- [Wine Android](docs/wine-android.md)
- [Soda analysis](docs/soda-analysis.md)
- [ARM64 paths](docs/arm64.md)
- [Android restrictions](docs/android-runtime.md)
- [Tests and observed results](docs/testing.md)
- [Licenses and upstreams](docs/licenses.md)
- [GitHub Actions](https://github.com/tqmane/officedroid/actions)

OfficeDroid code is MIT licensed. Wine and other upstreams retain their own
licenses. No Microsoft software or Microsoft icons are distributed here.
