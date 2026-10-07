# Architecture and current implementation

The selected first experiment is upstream Wine 11.0 compiled against Android
bionic, using `wineandroid.drv`. The Android build host is x86_64; this does not
restrict the application ABI. Native ELF probes are built for both x86_64 and
ARM64. Linux-native process tests additionally run on both host architectures.

The application owns one `files/prefix` location. Separate Word, Excel and
PowerPoint Activities declare separate task affinities. They currently show
diagnostics; they do not launch Windows executables yet. MIME intent filters
receive document intents, but document importing and write-back are deliberately
unavailable until the runtime can consume them. An incoming URI must never be
passed directly to a Windows command line or treated as a filesystem path.

The runtime experiment is independent of the UI: first prove Android native
execution, then Wine initialization, wineboot, a minimal Win32 executable, then
GUI/input, then an official Office installer. Each stage needs its own observable
result. A successful native probe cannot establish Wine or Office functionality.

The optional Wine APK invokes the installed Wine loader as a native subprocess.
Wine's Unix DLLs remain in Android's immutable native library directory; private
ZIP assets contain Windows PE code and data. A verified layout maps private
symlinks to installed native files. No application code is downloaded from an
untrusted server. There is no bundled Linux distribution. The experimental
headless API supports bounded commands and wineserver shutdown; it does not
yet manage a shared graphical session's lifecycle.

For future Wine integration, use a dedicated Android `:wine` process for the JNI
Activity, with the launcher/manager in the main process. Wine owns thread and
signal state; loading it in the manager process would couple crashes to the UI.
All Office processes must use the same prefix and wineserver. A lifecycle service
and shutdown grace period require actual child-process monitoring, and are not
implemented by the diagnostic app.

No glibc fallback has been selected. Evaluate it only against a measured bionic
blocker, including its loader, graphics, input, licensing and Android sandbox
costs. Never use a Linux distribution dependency as the final application model.
