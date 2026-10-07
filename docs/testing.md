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
