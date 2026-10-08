package org.officedroid;

import static org.junit.Assert.*;
import static org.junit.Assume.assumeTrue;
import android.content.Context;
import androidx.test.platform.app.InstrumentationRegistry;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import java.io.File;
import org.junit.Test;
import org.junit.runner.RunWith;

@RunWith(AndroidJUnit4.class)
public class WineRuntimeTest {
    @Test public void wineVersionRunsInApplicationSandbox() throws Exception {
        Context context = InstrumentationRegistry.getInstrumentation().getTargetContext();
        assumeTrue("Wine is excluded from the diagnostic-only APK", WineRuntime.available(context));
        assertTrue(WineRuntime.run(context, 30, "--version").contains("wine-11.0"));
    }
    @Test public void windowsHttpsValidatesMicrosoftCertificate() throws Exception {
        Context context = InstrumentationRegistry.getInstrumentation().getTargetContext();
        assumeTrue("Wine is excluded from the diagnostic-only APK", WineRuntime.available(context));
        File runtime = WineRuntime.prepare(context);
        try {
            String output = WineRuntime.run(context, 90, new File(runtime, "https-probe.exe").getAbsolutePath());
            assertTrue("HTTPS probe did not report certificate validation success: " + output, output.contains("TLS_OK"));
        } finally {
            WineRuntime.stop(context);
        }
    }
    private void checkNetworkEnumeration(String executable) throws Exception {
        Context context = InstrumentationRegistry.getInstrumentation().getTargetContext();
        assumeTrue("Wine is excluded from the diagnostic-only APK", WineRuntime.available(context));
        File runtime = WineRuntime.prepare(context);
        try {
            String output = WineRuntime.run(context, 60, new File(runtime, executable).getAbsolutePath());
            assertTrue("Network enumeration must return real interfaces and addresses: " + output,
                    output.contains("NETWORK_ENUM_OK"));
        } finally {
            WineRuntime.stop(context);
        }
    }
    @Test public void nativeWindowsNetworkEnumeration() throws Exception {
        checkNetworkEnumeration("network-probe.exe");
    }
    @Test public void wow64WindowsNetworkEnumeration() throws Exception {
        checkNetworkEnumeration("network-probe-wow64.exe");
    }
    @Test public void x64WindowsNetworkEnumeration() throws Exception {
        checkNetworkEnumeration("network-probe-x64.exe");
    }
    private void checkRpcAuthentication(String executable) throws Exception {
        Context context = InstrumentationRegistry.getInstrumentation().getTargetContext();
        assumeTrue("Wine is excluded from the diagnostic-only APK", WineRuntime.available(context));
        File runtime = WineRuntime.prepare(context);
        try {
            String output = WineRuntime.run(context, 60, new File(runtime, executable).getAbsolutePath());
            assertTrue("App-V requires Kerberos, Negotiate and NTLM registration: " + output,
                    output.contains("RPC_AUTH_OK"));
        } finally {
            WineRuntime.stop(context);
        }
    }
    @Test public void nativeWindowsRpcAuthentication() throws Exception {
        checkRpcAuthentication("rpc-auth-probe.exe");
    }
    @Test public void wow64WindowsRpcAuthentication() throws Exception {
        checkRpcAuthentication("rpc-auth-probe-wow64.exe");
    }
    @Test public void x64WindowsRpcAuthentication() throws Exception {
        checkRpcAuthentication("rpc-auth-probe-x64.exe");
    }
    @Test public void wineBootAndWindowsCommand() throws Exception {
        Context context = InstrumentationRegistry.getInstrumentation().getTargetContext();
        assumeTrue("Wine is excluded from the diagnostic-only APK", WineRuntime.available(context));
        try {
            WineRuntime.run(context, 120, "wineboot", "--init");
            File output = new File(MainActivity.prefix(context), "drive_c/officedroid-smoke.txt");
            if (output.exists()) assertTrue(output.delete());
            WineRuntime.run(context, 60, "cmd", "/c", "echo OFFICEDROID>C:\\officedroid-smoke.txt");
            assertTrue("The Windows command must actually write a file", output.isFile());
            assertTrue(new String(java.nio.file.Files.readAllBytes(output.toPath()), java.nio.charset.StandardCharsets.UTF_8).contains("OFFICEDROID"));
            File wow64Output = new File(MainActivity.prefix(context), "drive_c/officedroid-wow64.txt");
            if (wow64Output.exists()) assertTrue(wow64Output.delete());
            WineRuntime.run(context, 60, "C:\\windows\\syswow64\\cmd.exe", "/c", "echo WOW64>C:\\officedroid-wow64.txt");
            assertTrue("The 32-bit command must run before trying the i386 Office installer", wow64Output.isFile());
            assertTrue(new String(java.nio.file.Files.readAllBytes(wow64Output.toPath()), java.nio.charset.StandardCharsets.UTF_8).contains("WOW64"));
        } finally {
            WineRuntime.stop(context);
        }
        // Wineserver saves every 30 seconds and on shutdown, not at wineboot exit.
        File registry = new File(MainActivity.prefix(context), "system.reg");
        assertTrue("The shared prefix registry must persist after shutdown", registry.isFile());
        assertTrue("The saved registry must contain data", registry.length() > 0);
    }
}
