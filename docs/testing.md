# Test plan and results

## Current target and blockers (2026-10-08)

The required target is **ARM64 Android on standard GitHub-hosted runners**.
No Windows Word, Excel or PowerPoint editing screen has been verified. Prior
x86_64 Android results below are historical and do not validate this target.

- ARM64 Wine compilation passes (run 37762079154). The Wine workflow currently
  builds/packages ARM64 only; its green result does not mean Android or Office ran.
- Standard Ubuntu ARM has no `/dev/kvm`; standard macOS ARM rejects actual
  Hypervisor VM creation (`0xfae9400f`), measured in run 37762282587.
- macOS emulator 37.2.12 ignores `-accel off` for ARM64 and still enables HVF.
  Explicit QEMU TCG also crashes in HVF initialization (run 37763903773).
  `android-arm64.yml` now measures the bundled AArch64 QEMU engine on a standard
  Linux host with software translation. Its guest ABI must be `arm64-v8a`.
- `scripts/build-fex.sh` builds pinned upstream FEX unchanged for i386 and AMD64
  Windows execution inside ARM64 Wine. Both PE DLL builds pass locally. Wine's
  ARM64EC integration and Android execution remain under validation. x86/x64
  network and RPC probes are mandatory in the Wine APK, including on ARM64.
- Last historical Office installation (run 37757895102) passes all eleven runtime
  checks and both Notepad editing paths on x86_64 Android. Kerberos registration
  now succeeds for services 16, 9 and 10. ODT exits 17002 during App-V manifest
  merging: `removeChild failed, Error: 0x80070057`. No editor ran, and no account
  or license prompt was reached. Native MSXML6 is a possible next compatibility
  experiment; it has not yet been integrated or validated.


Commands must preserve failure exit codes. `scripts/build.sh` runs host CTest,
cross-builds both Android ABIs, builds APK/test APK and runs Android lint.
`scripts/emulator-test.sh` boots Android 16, configures tablet landscape, runs
instrumentation and captures logcat, emulator output and a screenshot. CI keeps
these plus Gradle reports. No test treats an absent emulator as a pass.

The Wine workflow exposes separate runtime, official Office installation and
Office editing steps. It uploads `wine-android-runtime-checks` immediately after
the runtime step, so its JUnit/GUI evidence is available while Office runs.
After every runtime check passes, CI retains that emulator and shared prefix
for the Office steps; an `always()` teardown captures diagnostics and stops it.
The default local emulator command still runs all stages with exit-trap cleanup.

Native and WoW64 RPC probes enumerate real SSPI packages, require successful
Kerberos/Negotiate/NTLM server registration, and reject an unknown service.
This reproduces App-V's registration requirement without declaring Office usable.

After instrumentation, the emulator script retains the APK (installing it only
if instrumentation removed it) and runs
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

Run [37714593963](https://github.com/tqmane/officedroid/actions/runs/37714593963)
at `135707f` passes all seven instrumented tests and the full Win32 GUI test:
typing, copy/paste, undo, exact saved file content and cold reopening. The
artifact includes `gui/gui-smoke.txt` and the actual `edited.png` / `reopened.png`.
The next stage downloads and verifies official ODT, but its Android staging fails
before the installer executes. ADB's `exec-in` quotes already-quoted shell
arguments again and does not report the remote command's exit code. Office
staging and private file checks now use non-PTY shell v2 (`adb shell -T`), which
preserves binary input, waits for completion and propagates command failures.
Installer execution and the three Office editing tests remain unverified.

Run [37716247862](https://github.com/tqmane/officedroid/actions/runs/37716247862)
at `09f50bc` verifies all staged ODT files and starts the official installer.
The installer is a 32-bit executable and cannot initialize the Android GUI
driver: unlike Wine's other GUI drivers, wineandroid lacks a WoW64 Unix-call
table. The new driver thunk marshals its initialization arguments; CI now also
requires 32-bit Notepad input/save/cold-reopen before attempting ODT. This fix
has compiled locally but has not yet passed its Android runtime check.
The installer batch file also writes its exit code with the redirect before
`echo`, avoiding interpretation of a numeric exit code as a file descriptor.
Neither Office installation nor any Office editing screen has passed.

Run [37718501288](https://github.com/tqmane/officedroid/actions/runs/37718501288)
at `494508d` again passes all seven Android tests and full 64-bit editing.
The 32-bit driver now initializes and requests its first application window,
but stalls before its first position update. The driver's device I/O used an
uninitialized `IO_STATUS_BLOCK.Pointer`, which ntdll treats as a pointer to the
32-bit completion block in WoW64. The follow-up patch supplies that block and
handles both immediate and pending completions; Android validation is pending.
CI also avoids reinstalling an APK already retained by instrumentation, since
that changes its native library directory and forces runtime re-extraction.
Office installation and editing remain unverified.

Run [37720737990](https://github.com/tqmane/officedroid/actions/runs/37720737990)
at `b146773` passes all seven instrumented tests but is blocked before the GUI
tests by a system dialog: Pixel Launcher's notification service has an ANR.
The screenshot shows OfficeDroid's successful native probe behind that dialog.
The WoW64 I/O fix therefore remains untested on Android. CI now uses Google's
official Android 16 AOSP (`default;x86_64`) system image, without the Google
apps background services, and recreates its dedicated tablet AVD configuration.
OfficeDroid's UI checks and all editing assertions remain required.

Run [37722194013](https://github.com/tqmane/officedroid/actions/runs/37722194013)
at `22c1bc0` passes all seven instrumented tests and the complete 64-bit **and
32-bit** Notepad editing/save/cold-reopen tests on the AOSP image. The WoW64
completion fix is now verified on Android. Official ODT renders its Microsoft
"We're getting things ready" window, but remains there until the 30-minute
timeout. Its configuration-service HTTPS request succeeds; the installer log
stops during `UniversalBootstrapper.Execute3`, before Office installation.
There is no evidence of any Office editing screen. Installer-specific HTTP,
service and process tracing and post-failure WineDbg thread backtraces now
capture the next failure. Manual workflow runs can use a shorter ODT time limit
for this startup-hang investigation; normal runs retain 1,800 seconds.

Diagnostic run [37726293879](https://github.com/tqmane/officedroid/actions/runs/37726293879)
at `9f25cd0` again passes Android instrumentation and both complete Notepad
editing tests. ODT still stops at the preparation window. HTTP traces show the
configuration requests finishing successfully, with no Office payload request.
The main installer thread's last process trace queries `TMP`. The attempted
backtrace capture fails: Android's APK path contains `=`, so `env` consumes the
loader path as another environment assignment. The diagnostic now executes it
through a shell positional argument (verified with an equivalent host path).
File and synchronization traces are enabled in the installer batch file, limiting
their scope to ODT and its children. Office installation/editing remains unverified.

Diagnostic run [37729508584](https://github.com/tqmane/officedroid/actions/runs/37729508584)
at `224c271` again passes the runtime and both Notepad gates. Its file trace
narrows the installer wait to `IOCTL_NSIPROXY_WINE_ENUMERATE_ALL` on `\\.\Nsi`:
both a background thread and the main setup thread enter the call without
returning. Configuration HTTPS requests still complete. WineDbg now launches,
but `bt all` overflows its stack while formatting an unrelated Explorer frame,
before reaching setup. Diagnostics therefore capture setup/device threads
individually and enable NSI driver traces from Wine startup.

The separate standard run [37729442149](https://github.com/tqmane/officedroid/actions/runs/37729442149)
fails because cold-boot Quickstep has no focused window when the test injects
MENU. The script now uses `wm dismiss-keyguard` without injecting input;
[37731431954](https://github.com/tqmane/officedroid/actions/runs/37731431954)
at `464b856` passes the standard build, lint, host and Android tests.

Run [37731430662](https://github.com/tqmane/officedroid/actions/runs/37731430662)
at `464b856` confirms `setup.exe` is blocked in `GetAdaptersInfo`, while the
NSI request thread is inside its Unix enumeration call. Startup's first
enumeration returns, but the next never does. Android's Bionic `if_nameindex`
uses restricted `RTM_GETLINK`; Wine dereferences its NULL result under
`if_list_lock`, and its Unix-call fault recovery skips the mutex unlock.
Patch 23 uses Bionic's application-compatible `getifaddrs` path on Android and
checks `if_nameindex` failure elsewhere.
New native/WoW64 instrumented probes require `GetIfTable2`, `GetAdaptersInfo`
and `GetAdaptersAddresses` to return real interfaces and unicast addresses.

Run [37733239683](https://github.com/tqmane/officedroid/actions/runs/37733239683)
at `f7f0d7f` verifies that patch 23 removes the enumeration hang: native and
WoW64 `GetIfTable2` both return success and four interfaces. The next API,
`GetAdaptersInfo`, returns error 50 because Wine reads Android's restricted
`/proc/net/route`. These two regression tests fail; the existing seven tests
and 64-bit GUI editing pass. The failed gate prevents this run from reaching
the Office installer. Patch 24 retrieves actual IPv4/IPv6 routes through a
bounded `RTM_GETROUTE` request, without a multicast bind or elevated privileges.
The probe also requires real gateway entries. Run
[37734923890](https://github.com/tqmane/officedroid/actions/runs/37734923890)
at `441aece` verifies `GetAdaptersInfo` succeeds for native and WoW64 callers.
`GetAdaptersAddresses` then returns `0xc0000005`: Android has no glibc `_res`
state, so Wine builds an empty DNS Unix library and calls its uninitialized
dispatch table. The failed regression gate prevents Office installation.
Patch 25 implements the DNS Unix calls with Bionic queries and the active
network's actual LinkProperties, supplied by the Android launcher. It also
initializes the DNS buffer size in iphlpapi. Probes require DNS server entries
and a successful `DnsQuery_A` for Microsoft's configuration host; Android
run [37736901201](https://github.com/tqmane/officedroid/actions/runs/37736901201)
at `0799ae4` verifies `GetAdaptersAddresses` succeeds for both callers, with four interfaces, ten
unicast addresses, four gateways and four DNS-server entries. `DnsQuery_A`
returns 9002: Bionic's legacy `res_query` uses process-local resolver state
without the system's configured nameservers. Patch 26 uses Android's public
`android_res_nquery`/`android_res_nresult` API, which delegates to the system
resolver, with a bounded wait and cancellation on timeout. It links the NDK's
`libandroid` and preserves DNS response errors. Office installation was not
attempted in the failed `0799ae4` run.

Run [37738721411](https://github.com/tqmane/officedroid/actions/runs/37738721411)
at `7c76cad` passes all nine Android tests and both 32/64-bit Win32 GUI editing,
saving and cold reopening. This verifies the system DNS fix. ODT now downloads
and extracts its 33 MB Click-to-Run client and launches it. The client encounters
a GL-context failure followed by repeated calls to Wine's unimplemented
`vcruntime140.__C_specific_handler_noexcept`, ending in stack overflow. ODT waits
for the client and times out after 30 minutes; no Office editor is verified.
The subsequent experiment installs pinned, official Visual C++ 14.44.35211 x64/x86
redistributables before ODT, preferring their native CRT DLLs. Both installer
exit codes must be 0 or 3010, followed by ODT success and all three edit tests.
Downloads/staging are checksum-verified; Microsoft files remain outside APKs,
Git and uploaded artifacts. Run `37746093034` at `a0597e1` verifies both official
redistributable installers exit 0 and C2R loads native MSVC DLLs. The missing
handler and stack overflow disappear, but OfficeC2RClient still fails after
repeated Direct3D GL-context failures and displays a Wine program-error dialog.
Office installation times out at the diagnostic 300-second limit; no editor runs.
ODT now uses its supported `Display Level="None"` unattended mode to avoid the
installer's graphical client. This does not waive the three graphical editing
gates. Installation captures prefix disk usage, individual runtime exit codes
and installer-log paths; HTTP tracing also covers the C2R service environment.

Run [37741820750](https://github.com/tqmane/officedroid/actions/runs/37741820750)
at `8a1da54` independently passes the nine tests and both GUI paths. Its separate
runtime artifact uploads successfully before Office, and the retained emulator
is available to the Office step. That installation was cancelled after the full
`7c76cad` run established the CRT failure; final diagnostics/teardown succeeds.
The Office edit step is skipped, not passed.

Failures printed by WineDbg while attaching to WoW64 processes
occur after installer timeout and do not establish a preceding Office crash.

The standard run at `f7f0d7f` reveals a separate Android System UI startup ANR,
before APK installation. A completed boot property alone is insufficient.
The emulator now requires a stable, visible AOSP home screen before installing
the app. A failed system boot retains its XML, screenshot and logcat, then gets
one reboot using its initialized system data; a second failure fails CI.
Application tests and input events are never retried by this startup check.
Standard run [37734925731](https://github.com/tqmane/officedroid/actions/runs/37734925731)
at `441aece` passes, with a stable home screen on the first boot.

Standard run [37741820906](https://github.com/tqmane/officedroid/actions/runs/37741820906)
at `8a1da54` exercises that recovery path but fails both boots before APK
installation: System UI cannot complete startup. Logs show guest CPU pressure
of 68–80%, with the graphics compositor and SurfaceFlinger dominating usage,
while memory pressure is near zero. Using up to four available host CPUs alone
does not fix startup: both `cda0e0f` runs fail before APK installation.
`a0597e1` boots at 1280x800 with the supported SwiftShader renderer option,
checks home-screen stability, switches to 2560x1600, and checks stability again.
Standard run [37746096289](https://github.com/tqmane/officedroid/actions/runs/37746096289)
passes without a recovery reboot. Wine run
[37746093034](https://github.com/tqmane/officedroid/actions/runs/37746093034)
also passes all nine instrumented tests and both Win32 GUI editing paths;
both redistributables install, while Office fails as described above.

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
installing those Python packages. An application's failure is recorded before
testing the remaining applications; the overall result requires all three to pass.

## Milestone gates

| Gate | Required evidence |
| --- | --- |
| Android shell | APK install, launcher and instrumented native subprocess |
| Wine starts | Wine JNI / loader logs and successful wineboot on Android |
| Win32 GUI | Test application appears on tablet screen; input assertions |
| Office installer | Official installer starts and finishes with captured logs |
| Office applications | Word/Excel/PowerPoint edit/save in the shared prefix |
| Files and concurrency | Content URI import/write-back, simultaneous apps, recovery |

Keyboard shortcuts (copy/paste/undo/save) pass in 32/64-bit Notepad. Right click,
wheel, arbitrary selection and stylus coverage remain incomplete. UI launchers
are not a substitute for editing tests. Cross-build success is not Android
runtime success.

## Initial cloud host observations

Linux x86_64, 5 CPUs, approximately 30 GB initially free, no `/dev/kvm`.
Direct host probe passed the process/filesystem/memory check and rejected an
invalid directory. Further results are recorded after builds and CI execution.
