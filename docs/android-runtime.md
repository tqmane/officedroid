# Android execution constraints

The diagnostic executable is built as PIE, named `libodprobe.so`, packaged in
`lib/<abi>/`, and extracted by Android's package manager. `ProcessBuilder` invokes
its absolute path under `ApplicationInfo.nativeLibraryDir`. It needs no root,
Termux, PRoot or executable file in writable app storage.

The probe checks file round-trip in one shared private directory, anonymous
RW→RX mapping and fork/wait. It reports UID, page size and machine architecture.
The process must exit successfully; merely finding a PID is not a passing test.

Target SDK 36 imposes modern executable-memory, app-data execution, linker
namespace and background restrictions. A Wine integration needs to handle:

1. JNI initialization and signal ownership in a dedicated process.
2. Loader/server executables installed by the package manager; ELF dependencies
   and SONAMEs that match the packaged files.
3. Writable PE/prefix files separated from immutable Unix executable code.
4. 4 KB and 16 KB memory-page devices, not just linker alignment.
5. An Activity/Surface lifecycle, input and audio callbacks in wineandroid.
6. Child lifetime, foreground/background transitions and user-visible service
   notification when needed. A process spawn is not a lifecycle manager.

INTERNET enables Wine networking; ACCESS_NETWORK_STATE reads the active network's
DNS servers and search domains through Android LinkProperties. Wine's DNS queries
use Bionic's resolver, preserving Android's network selection. There is no external-storage,
microphone, root or system-modification requirement. Document provider access must
use per-URI grants. No access to a supplied URI is currently attempted.
