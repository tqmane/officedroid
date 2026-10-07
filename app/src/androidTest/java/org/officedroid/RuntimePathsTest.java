package org.officedroid;

import static org.junit.Assert.*;
import android.system.Os;
import androidx.test.platform.app.InstrumentationRegistry;
import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import org.junit.Test;

public class RuntimePathsTest {
    @Test public void aliasedRootAllowsFilesButRejectsEscapes() throws Exception {
        File temporary = Files.createTempDirectory(InstrumentationRegistry.getInstrumentation()
                .getTargetContext().getCacheDir().toPath(), "runtime-paths").toFile();
        File root = new File(temporary, "root");
        File alias = new File(temporary, "alias");
        File outside = new File(temporary, "outside");
        File link = new File(root, "native.so");
        File parentLink = new File(root, "parent");
        try {
            assertTrue(root.mkdir());
            assertTrue(outside.mkdir());
            Os.symlink(root.getPath(), alias.getPath());
            assertEquals(new File(root.getCanonicalFile(), "file"), WineRuntime.inside(alias, "file"));
            Os.symlink(outside.getPath(), parentLink.getPath());
            for (String path : new String[]{"../outside/file", outside.getPath(), "parent/file", "."}) {
                try {
                    WineRuntime.inside(alias, path);
                    fail("Accepted an escaping path: " + path);
                } catch (IOException expected) { /* Must reject paths outside the runtime. */ }
            }
            Os.symlink(new File(outside, "old-apk-library").getPath(), link.getPath());
            assertEquals(new File(root.getCanonicalFile(), "native.so"), WineRuntime.inside(alias, "native.so"));
        } finally {
            Files.deleteIfExists(link.toPath());
            Files.deleteIfExists(parentLink.toPath());
            Files.deleteIfExists(alias.toPath());
            Files.deleteIfExists(root.toPath());
            Files.deleteIfExists(outside.toPath());
            Files.deleteIfExists(temporary.toPath());
        }
    }
}
