# Test plan and results

Commands must preserve failure exit codes. `scripts/build.sh` runs host CTest,
cross-builds both Android ABIs, builds APK/test APK and runs Android lint.
`scripts/emulator-test.sh` boots Android 16, configures tablet landscape, runs
instrumentation and captures logcat, emulator output and a screenshot. CI keeps
these plus Gradle reports. No test treats an absent emulator as a pass.

After instrumentation, the emulator script reinstalls the APK and runs
`scripts/launch-test.py`. It cold-starts all four launcher Activities using the
MAIN/LAUNCHER intent, requires visible title/native-success text and the resumed
Activity, and records a screenshot, UI XML and launch log for each. Wine builds
also tap **Check Wine version** on the main screen and require visible
`wine-11.0` output. Missing UI or a failed native startup fails the job.
See `.build/emulator/launch/` in the Actions results artifact and the job summary.
These screens are Android diagnostics, not the Microsoft Office editing UI.

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

## GUI and Office validation in progress

Run [37708167076](https://github.com/tqmane/officedroid/actions/runs/37708167076)
at `ab3bb95` passes all seven Android instrumented tests, including validated
HTTPS through WinHTTP, a 64-bit Windows command and a 32-bit WoW64 command.
The GUI test still fails: Notepad creates a window but the captured screen is
blank. Microsoft Office installation and editing have not run.

Tracked Wine patches fix desktop initialization, the JNI launch process,
Android's NT device path, executable mappings, APK runtime paths and certificate
roots. The modern CPU surface bridge uses a Wine shared section and public
`ANativeWindow_lock` / `ANativeWindow_unlockAndPost` calls. Explicit CPU buffer
usage fixes the Android 16 mapper failure. In the run above, both native calls
return zero and source pixels contain the desktop and window colors, but this
does not prove that Android displays them. The GUI gate requires visible title
text before keyboard tests and continues to fail when presentation is blank.
Run [37709799661](https://github.com/tqmane/officedroid/actions/runs/37709799661)
at `dd31d8c` fixes presentation using public RGBA buffers. Its screenshot shows
the actual Notepad title, menus and editor on the Wine desktop, and TextureView
reports frame updates. All seven instrumented tests pass. The GUI assertion
still fails because Tesseract omits the title text on the blue title bar while
correctly reading the complete menu. The test now accepts either the title or
Notepad's complete menu as rendering evidence. Input, persistence and Office
still require subsequent device verification.

Run [37711565331](https://github.com/tqmane/officedroid/actions/runs/37711565331)
at `aab980d` reaches keyboard input. The first capture occurs while Wine is still
processing the queued keys; its final screenshot visibly contains
`OFFICEDROIDGUI`. Default OCR misses the small editor text, while sparse-text
segmentation reads it correctly from that same screenshot. GUI assertions now
poll rendered content for up to 30 seconds instead of assuming a one-second
rendering delay, and GUI/Office OCR uses sparse-text segmentation. Copy/paste,
save/reopen and Office still require a passing run.

Run [37713115669](https://github.com/tqmane/officedroid/actions/runs/37713115669)
at `3291470` passes visible typing and copy/paste. Its undo/save assertion fails:
classic Notepad coalesces all contiguous insertions into one undo group, so
Ctrl+Z removes the original typing as well as the paste and Ctrl+S saves an empty
file. The test now saves and cold-reopens the initial text before exercising
paste/undo, giving that operation an independent undo history. Instrumentation
also keeps its installed APK/prefix for the subsequent GUI check; the AVD is
still wiped at the start, and each GUI test removes its own previous document.

Continuous Android logs are retained while the emulator runs, including when a
later ADB capture fails. Read-only captures can retry a transient offline device;
keyboard and touch events are never replayed. The AVD uses an explicit tablet
hardware profile so creation does not depend on an interactive prompt.

The GUI test requires visibly rendered keyboard input, copy/paste, undo, a saved
file and a cold restart displaying the saved content. It removes its previous
test file first. OCR output and screenshots are retained for review. This is
Win32 Notepad coverage; it does not constitute Microsoft Office coverage.

The dedicated CI AVD is reset for each run and has a 16 GiB data partition for
Office's download cache and installation. After runtime/GUI tests pass, the
ODT test runs the official installer and saves installer evidence. Neither ODT
installation nor Word/Excel/PowerPoint editing is currently reported as passed.

`scripts/office-edit-test.py` stages fresh, committed test documents and launches
Word, Excel and PowerPoint from their respective Android Activities. It finds
fixture text on the rendered Office screen, injects keyboard edits, saves using
Ctrl+S, checks the modified OOXML contents, terminates the app and verifies the
saved text is visible after a cold reopen. Screenshots, OCR and the edited test
documents are retained separately for each application. An account dialog or a
read-only editor cannot satisfy these assertions. These tests remain unrun until
the runtime and installer gates pass. Fixture regeneration requirements are in
`tests/generate-office-fixtures.py`; CI uses the committed documents without
installing those Python packages.

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
