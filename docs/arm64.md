# ARM64 evaluation

The same NDK toolchain builds the Android-native probe for `arm64-v8a` and
`x86_64`. A separate `ubuntu-24.04-arm` CI job runs the C process/filesystem/memory
checks natively. Neither is evidence that x86 Office can run on ARM64 Android.

| Candidate | Observed upstream model | Remaining Android work |
| --- | --- | --- |
| Native Wine aarch64 | Wine supports aarch64 PE builds | Windows ARM64/ARM64EC application availability and dependencies |
| ARM64EC + FEX | [Hangover](https://github.com/AndreRH/hangover) describes native Unix Wine plus PE emulator DLLs | bionic build, JNI driver and Android mapping restrictions |
| FEX Linux | [FEX](https://github.com/FEX-Emu/FEX) documents ARM64 Linux and x86 rootfs | Linux FEX is not automatically a bionic Android library |
| Box64 | [Box64](https://github.com/ptitSeb/box64) runs x86_64 Linux code; Hangover also describes a PE integration | Distinguish whole-Linux emulation from PE-only integration |
| Box86 | [Box86](https://github.com/ptitSeb/box86) targets 32-bit x86 on ARM | Low priority because 32-bit ABIs are outside the initial scope |
| Winlator | [Winlator](https://github.com/brunodev85/winlator) packages Wine/Box64 and credits glibc patches | Reference for managed native/glibc execution, not proof our Wine Android path works |

The native aarch64 Wine cross-build and APK packaging pass locally and in CI.
ARM64 Android execution remains untested; the ARM64 Linux host probe is a separate
check of portable process/filesystem logic. No x86 translation or ARM64EC
Office compatibility is enabled implicitly. Add a translator only after the
native ABI experiment and its targeted tests identify the actual requirement.
