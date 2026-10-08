# OfficeDroid

Research and implementation of a shared, app-managed Wine runtime for Windows
Word, Excel and PowerPoint on Android tablets. No Termux, PRoot, root or external
Linux distribution is part of the application architecture.

**Development prototype, not a working Office product.** The APK currently
provides separate launchers and a real native-executable diagnostic. An optional
APK packages Wine 11.0 and FreeType built for Android. Android 16 x86_64 tests
verify Wine initialization, 32/64-bit Windows commands, validated HTTPS and a
persisted shared prefix. The actual Win32 Notepad editor displays keyboard input,
copies/pastes, undoes changes, saves and shows the saved document after a cold
restart. Microsoft Office installation, editing, authentication, document
write-back and a shared graphical session lifecycle are not yet working.
Launcher entries alone do not demonstrate Office compatibility.

## Build and test

Linux x86_64 host; Android targets are `x86_64` and `arm64-v8a`.
Use an existing checkout. Cloud tasks are already isolated; no worktree is needed.

```sh
./scripts/setup.sh --wine
./scripts/build.sh
./scripts/build-wine.sh x86_64
./scripts/build-wine.sh arm64-v8a
python3 scripts/package-wine.py x86_64 arm64-v8a
./scripts/build.sh -PwineRuntime=true
```

Setup detects missing JDK and Wine build tools. SDK 36, NDK r28c, CMake/Ninja,
Gradle 8.13 and LLVM-MinGW are installed locally with verified downloads. Ubuntu
uses APT when required; Debian read-only cloud images use signed APT downloads
and local extraction. Sources, downloads and outputs are ignored by Git.
Allow roughly 25 GB for tools, both Wine builds and an emulator image.
The default APK excludes Wine. `-PwineRuntime=true` includes the locally packaged
ABIs; Windows PE/data assets go into private storage, while Unix executable code
is installed by Android's package manager. No Microsoft binaries are included.

```sh
./scripts/setup.sh --emulator
./scripts/emulator-test.sh
# After packaging Wine and rebuilding the APK:
./scripts/emulator-test.sh -PwineRuntime=true
```

The emulator uses Android 16 and a 2560×1600, 240 dpi landscape display. KVM is
preferred; the script uses software acceleration and a bounded boot timeout when
unavailable. CI builds both Android ABIs, tests host processes on x86_64 and ARM64
Linux, and runs Android instrumentation. Results and APKs are uploaded as artifacts.

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
