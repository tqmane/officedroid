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
- PE image mapping includes fallback copying after `EPERM`/`EACCES`. Actual
  Android SELinux and seccomp behavior still needs a device test.

`scripts/build-wine.sh` isolates host tools, target output and staged installation.
It does not silently package unvalidated Wine binaries into the diagnostic APK.
Autoconf/Automake/Meson are not prerequisites for this pinned source: Wine ships
`configure` and uses its own Makefile generator. Install Autoconf only if changing
`configure.ac`; Meson becomes relevant if adopting a dependency that uses it.

Desktop ALSA, PulseAudio, X11, Wayland, CUPS, udev and GStreamer are excluded from
the Android baseline. Missing target FreeType/GnuTLS and other optional libraries
must remain visible in configure logs; a baseline build does not promise Office
font rendering, TLS, media or Vulkan support.
