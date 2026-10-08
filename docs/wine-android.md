# Wine Android baseline

Pinned source: [Wine 11.0](https://github.com/wine-mirror/wine/tree/db11d0fe6a169c457e23d007e20404643d067aa8).
Inspected `configure.ac`, `dlls/wineandroid.drv`, `dlls/ntdll/unix/loader.c`,
`loader/main.c` and `dlls/ntdll/unix/virtual.c`.

- `linux-android` configuration selects `wineandroid.drv`, PIE and GLES.
- Cross-compilation requires host Wine tools; build `__tooldeps__` first.
- Native Unix code uses NDK clang; Windows PE code needs a separate PE toolchain.
  LLVM-MinGW supports both x86_64 and aarch64 PE targets.
- Upstream `WineActivity` creates a Java thread, loads `ntdll.so` and enters
  `wine_init` through JNI. The driver supplies Activity/Surface, pointer, keyboard
  and desktop callbacks. It is not a standalone X11 server.
- Upstream APK configuration uses AGP 2.2.1, SDK 25, jcenter and old asset
  executable installation. Reusing that build unchanged would not target Android 16.
- Ntdll derives loader/data paths from its real path, and Wine children exec the
  loader/server. Modern APK packaging needs a consistent installed-library layout
  and path adaptation, not only a Java `System.load` call.
- PE image mapping includes fallback copying after `EPERM`/`EACCES`. On Android
  16, a read-only file mapping can succeed while a later executable `mprotect`
  fails for private app data. The Android patch selects Wine's existing anonymous
  copy path for PE images before this occurs; it does not change SELinux policy.

`scripts/build-wine.sh` isolates host tools, target output and staged installation.
The previous native-only x86_64 and aarch64 builds completed with NDK r28c and
LLVM-MinGW 20250709. The active ARM64 build adds ARM64EC and i386 Windows modules,
using pinned bylaws LLVM-MinGW 20250920 and unchanged FEX at
`fa556167d5a64ec7adb5503c2aa15b169c292cac`. `scripts/build-fex.sh` compiles both
`libwow64fex.dll` and `libarm64ecfex.dll`; patch 0027 selects them in Wine's
ARM64 registry defaults. Patch 0028 backports Wine's real `RtlWow64SuspendThread`
forwarder required by FEX. Its upstream local-thread refinement remains a known
limitation. The ELF side and graphical driver remain native Android/Bionic.
ARM64EC compilation, packaging and APK/lint checks pass locally. A native-only
cache initially retained import archives without ARM64EC symbols; the build now
regenerates PE archives when enabled architectures/toolchains change. Android
execution is still being validated.
`scripts/package-wine.py` produces optional APK inputs, verifies each ELF's ABI,
and keeps native executable code in Android-installed libraries. Wine PE/data
files are checksummed ZIP assets. `WineRuntime` extracts those into private
storage and links native files to the current APK installation. It refreshes
links after an APK update. The `files/prefix` location is shared across launchers.

The numbered patches in `patches/wine/` are the entire Wine delta: a bionic
header fix; explicit native DLL/data/loader paths; correction of stale Android
driver declarations/callback signatures; removal of unused broken driver code
and the obsolete upstream APK build; and exported JVM state for the driver.
Additional Android patches select the explicit APK wineserver path before
attempting conventional Unix paths, locate its NLS data in private assets, and
copy private PE images into anonymous mappings. Bionic's `posix_spawn` can return
success followed by child exit 127 for a missing executable, so a fallback based
only on its return value did not work here.
An opt-in `OFFICEDROID_DEBUG_INIT` trace records initialization checkpoints before
normal Wine logging is ready. The Android experiment enables it for diagnosis.
The JNI `WineActivity`/Surface bridge is integrated into a dedicated Android
process. It preloads native dependencies in the app class-loader namespace and
starts Explorer by its absolute Windows path to preserve the JVM connection.
Patches 0012 and 0014 repair desktop initialization order and Android device
requests. The bridge is still under device validation. Instrumentation exercises
the standalone loader, wineboot, 64/32-bit Windows commands and WinHTTP certificate
validation; GUI tests separately require rendered input, saving and reopening.
See [testing.md](testing.md) for observed failures and the current verification state.

Autoconf/Automake/Meson are not prerequisites for this pinned source: Wine ships
`configure` and uses its own Makefile generator. Install Autoconf only if changing
`configure.ac`; Meson becomes relevant if adopting a dependency that uses it.

Desktop ALSA, PulseAudio, X11, Wayland, CUPS, udev and GStreamer are excluded from
the Android baseline. FreeType 2.13.3 is built for the host tools and both Android
targets. GnuTLS 3.8.13, Nettle 3.10.2 and GMP 6.3.0 are cross-built by
`scripts/build-tls.sh`; Wine configuration requires GnuTLS. Patch 0013 adds
Android's current Conscrypt certificate directory. Remaining optional libraries
stay visible in configure logs. Successful compilation does not establish Office
rendering, HTTPS behavior, media or Vulkan support.

`scripts/build-kerberos.sh` builds pinned MIT Kerberos 1.22.2 for both Android
ABIs. Wine configuration requires its Kerberos and GSSAPI libraries: Office's
App-V server registers Kerberos before Negotiate and NTLM. The Android patch
uses the public resolver API and ConnectivityManager's search domain, since
Bionic does not expose `_res`. Shared libraries use builtin cryptography;
KDC daemons, CLI clients and the OpenSSL-dependent PKINIT plugin are excluded.
The app preloads the libraries by APK paths and uses its private cache for
Kerberos tickets. This supplies real providers; it does not supply credentials
or bypass Office authentication or licensing.
