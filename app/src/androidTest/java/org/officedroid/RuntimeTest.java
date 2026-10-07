package org.officedroid;

import static org.junit.Assert.*;
import android.content.Context;
import android.content.Intent;
import androidx.test.platform.app.InstrumentationRegistry;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import org.json.JSONObject;
import org.junit.Test;
import org.junit.runner.RunWith;

@RunWith(AndroidJUnit4.class)
public class RuntimeTest {
    @Test public void nativeProcessRunsInApplicationSandbox() throws Exception {
        Context context = InstrumentationRegistry.getInstrumentation().getTargetContext();
        JSONObject report = new JSONObject(MainActivity.probe(context));
        assertTrue(report.getBoolean("ok"));
        assertTrue(report.getBoolean("filesystem"));
        assertTrue(report.getBoolean("fork"));
        assertTrue(report.getBoolean("anonymous_rx"));
        assertTrue(report.getLong("uid") >= 10000);
    }
    @Test public void launchersAreSeparateAndShareOnePrefix() {
        Context context = InstrumentationRegistry.getInstrumentation().getTargetContext();
        for (Class<?> activity : new Class<?>[]{WordActivity.class, ExcelActivity.class, PowerPointActivity.class}) {
            Intent intent = new Intent(context, activity).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            android.app.Activity running = InstrumentationRegistry.getInstrumentation().startActivitySync(intent);
            assertEquals(MainActivity.prefix(context), MainActivity.prefix(running));
            InstrumentationRegistry.getInstrumentation().runOnMainSync(running::finish);
        }
    }
    @Test public void screenIsTabletLandscape() {
        android.util.DisplayMetrics screen = InstrumentationRegistry.getInstrumentation().getTargetContext().getResources().getDisplayMetrics();
        assertTrue("Landscape required", screen.widthPixels > screen.heightPixels);
        assertTrue("Tablet working area required", screen.heightPixels / screen.density >= 600);
    }
}
