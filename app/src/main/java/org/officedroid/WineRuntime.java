package org.officedroid;

import android.content.Context;
import android.os.Build;
import android.system.Os;
import java.io.*;
import java.security.MessageDigest;
import java.util.*;
import java.util.concurrent.TimeUnit;
import java.util.zip.*;
import org.json.JSONObject;

/** Experimental headless Wine path. All Unix code comes from the APK installer. */
public final class WineRuntime {
    private WineRuntime() {}
    public static boolean available(Context context) {
        return new File(context.getApplicationInfo().nativeLibraryDir, "libwine.so").isFile();
    }
    static File inside(File directory, String relative) throws IOException {
        // Android app directories can be reached through /data/user/0 and /data/data.
        // Resolve the root first, but leave the leaf unresolved so stale native links can be replaced.
        File rootDirectory = directory.getCanonicalFile();
        File file = new File(rootDirectory, relative).toPath().normalize().toFile();
        String root = rootDirectory.getPath();
        String parent = file.getParentFile().getCanonicalPath();
        if (new File(relative).isAbsolute() || !file.getAbsolutePath().startsWith(root + File.separator)
                || !(parent.equals(root) || parent.startsWith(root + File.separator))) {
            throw new IOException("Runtime path escapes destination: " + relative);
        }
        return file;
    }
    private static void mkdir(File directory) throws IOException {
        if (!directory.isDirectory() && !directory.mkdirs()) throw new IOException("Cannot create " + directory);
    }
    private static String text(InputStream input) throws IOException {
        try (InputStream source = input; ByteArrayOutputStream output = new ByteArrayOutputStream()) {
            byte[] bytes = new byte[8192];
            int count;
            while ((count = source.read(bytes)) != -1 && output.size() < 65536) output.write(bytes, 0, count);
            return output.toString("UTF-8");
        }
    }
    private static String logTail(File log) throws IOException {
        try (RandomAccessFile input = new RandomAccessFile(log, "r")) {
            int size = (int)Math.min(input.length(), 65536);
            byte[] bytes = new byte[size];
            input.seek(input.length() - size);
            input.readFully(bytes);
            return new String(bytes, java.nio.charset.StandardCharsets.UTF_8);
        }
    }
    public static synchronized File prepare(Context context) throws Exception {
        String abi = Build.SUPPORTED_ABIS[0];
        JSONObject layout = new JSONObject(text(context.getAssets().open("layout-" + abi + ".json")));
        String digest = layout.getString("sha256");
        if (!digest.matches("[0-9a-f]{64}")) throw new IOException("Invalid runtime digest");
        File directory = new File(context.getFilesDir(), "runtime-" + abi + "-" + digest);
        File ready = new File(directory, ".ready");
        String installedDirectory = context.getApplicationInfo().nativeLibraryDir;
        // APK updates change nativeLibraryDir while preserving app-private files.
        if (ready.isFile() && text(new FileInputStream(ready)).equals(installedDirectory)) return directory;
        mkdir(directory);
        MessageDigest sha256 = MessageDigest.getInstance("SHA-256");
        try (InputStream input = context.getAssets().open("runtime-" + abi + ".zip")) {
            byte[] block = new byte[65536];
            int count;
            while ((count = input.read(block)) != -1) sha256.update(block, 0, count);
        }
        StringBuilder actual = new StringBuilder();
        for (byte b : sha256.digest()) actual.append(String.format(Locale.ROOT, "%02x", b & 255));
        if (!digest.equals(actual.toString())) throw new IOException("Runtime checksum mismatch");
        long expanded = 0;
        try (ZipInputStream input = new ZipInputStream(context.getAssets().open("runtime-" + abi + ".zip"))) {
            ZipEntry entry;
            byte[] block = new byte[65536];
            while ((entry = input.getNextEntry()) != null) {
                File destination = inside(directory, entry.getName());
                if (java.nio.file.Files.isSymbolicLink(destination.toPath())) {
                    throw new IOException("Archive entry would overwrite a symbolic link: " + entry.getName());
                }
                if (entry.isDirectory()) { mkdir(destination); continue; }
                mkdir(destination.getParentFile());
                try (FileOutputStream output = new FileOutputStream(destination)) {
                    int count;
                    while ((count = input.read(block)) != -1) {
                        expanded += count;
                        if (expanded > 2L * 1024 * 1024 * 1024) throw new IOException("Runtime exceeds 2 GiB limit");
                        output.write(block, 0, count);
                    }
                }
            }
        }
        JSONObject nativeFiles = layout.getJSONObject("native");
        Iterator<String> paths = nativeFiles.keys();
        File nativeDirectory = new File(context.getApplicationInfo().nativeLibraryDir);
        while (paths.hasNext()) {
            String relative = paths.next();
            File target = inside(nativeDirectory, nativeFiles.getString(relative));
            if (!target.isFile()) throw new IOException("Missing APK native file: " + target.getName());
            File link = inside(directory, relative);
            mkdir(link.getParentFile());
            if ((link.exists() || java.nio.file.Files.isSymbolicLink(link.toPath())) && !link.delete()) {
                throw new IOException("Cannot replace runtime link");
            }
            Os.symlink(target.getAbsolutePath(), link.getAbsolutePath());
        }
        try (FileOutputStream output = new FileOutputStream(ready)) {
            output.write(installedDirectory.getBytes(java.nio.charset.StandardCharsets.UTF_8));
        }
        return directory;
    }
    public static void loadGuiLibraries(Context context) throws Exception {
        // The Android class-loader namespace does not use a later LD_LIBRARY_PATH
        // update. Preload dependencies by their APK-installed paths and SONAMEs.
        String abi = Build.SUPPORTED_ABIS[0];
        JSONObject mapping = new JSONObject(text(context.getAssets().open("layout-" + abi + ".json")))
                .getJSONObject("native");
        File nativeDirectory = new File(context.getApplicationInfo().nativeLibraryDir);
        for (String name : new String[] {"libgmp.so", "libnettle.so", "libhogweed.so", "libgnutls.so", "libfreetype.so"}) {
            System.load(inside(nativeDirectory, mapping.getString(abi + "/lib/" + name)).getAbsolutePath());
        }
    }
    public static Map<String, String> environment(Context context, File directory) throws IOException {
        String abi = Build.SUPPORTED_ABIS[0];
        String machine = abi.equals("arm64-v8a") ? "aarch64" : "x86_64";
        String nativeDirectory = context.getApplicationInfo().nativeLibraryDir;
        File prefix = MainActivity.prefix(context);
        mkdir(prefix);
        File temporary = new File(context.getCacheDir(), "wine");
        mkdir(temporary);
        String dlls = new File(directory, abi + "/lib/wine").getAbsolutePath();
        Map<String, String> env = new HashMap<>();
        env.put("HOME", context.getFilesDir().getAbsolutePath());
        env.put("TMPDIR", temporary.getAbsolutePath());
        env.put("WINEPREFIX", prefix.getAbsolutePath());
        env.put("WINESERVER", nativeDirectory + "/libwineserver.so");
        env.put("WINELOADER", nativeDirectory + "/libwine.so");
        env.put("WINEDLLPATH", dlls);
        env.put("OFFICEDROID_DLL_DIR", dlls);
        env.put("OFFICEDROID_DATA_DIR", new File(directory, "share/wine").getAbsolutePath());
        env.put("LD_LIBRARY_PATH", nativeDirectory + ":" + dlls + "/" + machine + "-unix:"
                + new File(directory, abi + "/lib").getAbsolutePath());
        env.put("LANG", "en_US.UTF-8");
        env.put("WINEDEBUG", "err+all,warn+winhttp,warn+secur32");
        env.put("OFFICEDROID_DEBUG_INIT", "1");
        // Do not prompt to download optional Mono/Gecko during a bounded smoke test.
        env.put("WINEDLLOVERRIDES", "mscoree,mshtml=");
        return env;
    }
    public static synchronized String run(Context context, int seconds, String... arguments) throws Exception {
        if (arguments.length == 0) throw new IllegalArgumentException("A Wine command is required");
        File runtime = prepare(context);
        ArrayList<String> command = new ArrayList<>();
        command.add(context.getApplicationInfo().nativeLibraryDir + "/libwine.so");
        Collections.addAll(command, arguments);
        File log = new File(context.getFilesDir(), "wine-last.log");
        ProcessBuilder builder = new ProcessBuilder(command).directory(context.getFilesDir())
                .redirectErrorStream(true).redirectOutput(log);
        builder.environment().putAll(environment(context, runtime));
        Process process = builder.start();
        if (!process.waitFor(seconds, TimeUnit.SECONDS)) {
            process.destroyForcibly();
            throw new IOException("Wine timeout; " + logTail(log));
        }
        String output = logTail(log);
        android.util.Log.i("OfficeDroidWine", "Command " + arguments[0] + " exited " + process.exitValue() + ": " + output);
        if (process.exitValue() != 0) throw new IOException("Wine exit " + process.exitValue() + ": " + output);
        return output;
    }
    public static void stop(Context context) throws Exception {
        ProcessBuilder builder = new ProcessBuilder(context.getApplicationInfo().nativeLibraryDir + "/libwineserver.so", "-k");
        builder.environment().put("WINEPREFIX", MainActivity.prefix(context).getAbsolutePath());
        builder.environment().put("LD_LIBRARY_PATH", context.getApplicationInfo().nativeLibraryDir);
        Process process = builder.start();
        if (!process.waitFor(15, TimeUnit.SECONDS)) process.destroyForcibly();
    }
}
