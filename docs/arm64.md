# ARM64 execution

The active target is ARM64 Android using standard GitHub-hosted runners. Cross-builds
run on Linux x86_64 because the official Android NDK host toolchain requires it.
The application runs native AArch64/Bionic Wine and the Android JNI graphical driver.

`scripts/build-wine.sh arm64-v8a` enables ARM64EC, aarch64 and i386 PE modules.
`scripts/build-fex.sh` builds unchanged FEX at
`fa556167d5a64ec7adb5503c2aa15b169c292cac` with pinned submodules and bylaws
LLVM-MinGW 20250920. FEX's PE DLLs translate Windows i386 and AMD64 code inside
Wine; no Linux rootfs, Termux or PRoot is part of the app. Wine's registry selects
both translators. The native and x86/x64 network/RPC probes are mandatory on ARM64.

Both FEX DLLs, ARM64EC Wine, APK packaging, host checks and lint pass locally.
Cached native-only Wine import archives initially lacked ARM64EC entries. The build
now regenerates PE archives when architectures/toolchain identity changes. Android
runtime and Office execution have not yet passed.

Standard Ubuntu ARM has no KVM; standard ARM macOS rejects Hypervisor VM creation.
The official ARM Mac emulator still enters HVF even with TCG requested. The Linux
SDK's AArch64 engine reaches ADB but Android 16 Zygote repeatedly crashes in ART,
even with CPU max and one TCG thread. Android 15 TCG also fails, with lmkd SIGSEGVs.

Native Android 15 ARM64 container boot **passes** on the standard ARM runner in
run 37771594555: `arm64-v8a`, API 35, boot completed in 15.6 seconds and a visible
home screen. Android 16 container boot fails in graphics/shared-memory startup.
The Wine workflow therefore tests its cross-built APK on the Android 15 container.
This records SELinux **Disabled** and cannot validate stock-device enforcement;
the container is CI infrastructure only, not part of the Android application.
Wine processes and Office editing have not passed on ARM64 yet.

See [testing.md](testing.md) for actual runs and failures. Linux ARM host tests,
compilation and Android boot are not substitutes for the three Office editing gates.
