# Test plan and results

Commands must preserve failure exit codes. `scripts/build.sh` runs host CTest,
cross-builds both Android ABIs, builds APK/test APK and runs Android lint.
`scripts/emulator-test.sh` boots Android 16, configures tablet landscape, runs
instrumentation and captures logcat, emulator output and a screenshot. CI keeps
these plus Gradle reports. No test treats an absent emulator as a pass.

Instrumentation verifies an actual packaged native subprocess, private filesystem
round trip, fork/wait and executable anonymous memory in a non-root Android UID;
it also checks separate Activities share a prefix and the test screen is a tablet.
Native host tests run on both x86_64 and ARM64 CI runners.

Runtime path tests cover an aliased private directory, traversal attempts,
escaping parent symlinks, and replacement of a dangling native-library symlink.
With `-PwineRuntime=true`, separate Wine tests require `wine --version` and
successful `wineboot`, an actual Windows `cmd` write into drive C, and a
nonempty registry persisted after wineserver shutdown. They are skipped only when the default APK intentionally excludes Wine.
APK builds, packaging and instrumentation share a lock to prevent output races.

## Observed results (2026-10-07)

- Local setup was rerun successfully; JDK 21, SDK 36, NDK r28c, CMake/Ninja,
  Gradle 8.13, LLVM-MinGW, flex/bison/m4 and emulator components are installed.
- Both Android ABI native builds, APK assembly and Android lint pass locally.
- Wine 11.0 plus FreeType compiles and packages for both ABIs. Repeating the
  x86_64 Wine build also succeeds.
- [Core CI run 37660737536](https://github.com/tqmane/officedroid/actions/runs/37660737536)
  passes host tests on x86_64/ARM64 and Android 16 tablet instrumentation.
  The diagnostic APK passes four device tests; its two Wine tests are skipped.
- Local software-only emulation boots but ddmlib times out reading device
  properties before instrumentation. This is an unrun device test, not a pass.
  GitHub Actions provides the working Android emulator test environment.
- [Wine CI run 37660737612](https://github.com/tqmane/officedroid/actions/runs/37660737612)
  builds both Android ABIs and passes Android 16 x86_64 instrumentation with
  Wine included: `wine --version`, `wineboot --init`, a Windows `cmd` filesystem
  write and a nonempty shared-prefix registry after wineserver shutdown.
  This verifies the headless Wine milestone in the application sandbox without
  Termux, PRoot, root or SELinux changes. GUI and Office are not validated.
- Runtime failures were fixed in tracked patches: Android directory aliases;
  the APK wineserver executable path; wineserver NLS assets; and anonymous PE
  image mappings where app-data-backed executable mappings are rejected.
  Registry checks wait until shutdown because Wine saves periodically, not at
  the instant `wineboot` exits.
- SDK Manager retries incomplete package installations up to three times and
  preserves the final failure status. Repeated setup and a simulated persistent
  failure verify successful reuse and bounded retries respectively.

The workflow uploads failure logs and JUnit reports, not just APKs. Wine build
outputs are cached before device testing, so runtime fixes can reuse compilation.

## Milestone gates

| Gate | Required evidence |
| --- | --- |
| Android shell | APK install, launcher and instrumented native subprocess |
| Wine starts | Wine JNI / loader logs and successful wineboot on Android |
| Win32 GUI | Test application appears on tablet screen; input assertions |
| Office installer | Official installer starts and finishes with captured logs |
| Office applications | Word/Excel/PowerPoint edit/save in the shared prefix |
| Files and concurrency | Content URI import/write-back, simultaneous apps, recovery |

Keyboard shortcuts (copy/paste/undo/save), right click, wheel, selection, touch
and stylus remain unrun for Wine until the GUI gate. UI launchers are not a
substitute for these tests. Cross-build success is not Android runtime success.

## Initial cloud host observations

Linux x86_64, 5 CPUs, approximately 30 GB initially free, no `/dev/kvm`.
Direct host probe passed the process/filesystem/memory check and rejected an
invalid directory. Further results are recorded after builds and CI execution.
