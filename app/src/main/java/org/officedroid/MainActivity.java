package org.officedroid;

import android.app.Activity;
import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import java.io.File;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.Executors;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.TimeUnit;

/** Launcher and observable native-process probe; Office readiness is never inferred from an APK build. */
public class MainActivity extends Activity {
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private TextView status;
    protected String officeName() { return "OfficeDroid"; }
    public static File prefix(android.content.Context context) {
        return new File(context.getFilesDir(), "prefix");
    }

    @Override public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        LinearLayout column = new LinearLayout(this);
        column.setOrientation(LinearLayout.VERTICAL);
        column.setPadding(32, 32, 32, 32);
        ScrollView scroll = new ScrollView(this);
        scroll.addView(column);
        setContentView(scroll);
        TextView title = new TextView(this);
        title.setText(officeName());
        title.setTextSize(28);
        column.addView(title);
        status = new TextView(this);
        status.setTextSize(18);
        status.setText("Android " + Build.VERSION.RELEASE + " / " + String.join(", ", Build.SUPPORTED_ABIS)
            + "\nShared prefix: " + prefix(this)
            + "\nScreen: " + getResources().getDisplayMetrics().widthPixels + "×"
            + getResources().getDisplayMetrics().heightPixels
            + " / " + getResources().getDisplayMetrics().densityDpi + " dpi"
            + "\nOffice is not installed. This development build tests native execution.\n");
        column.addView(status);
        addButton(column, "Run native diagnostics", this::diagnose);
        if (WineRuntime.available(this)) addButton(column, "Open Windows editor", () ->
            startActivity(new Intent(this, org.winehq.wine.WineActivity.class)));
        if (WineRuntime.available(this)) addButton(column, "Check Wine version", () -> worker.submit(() -> {
            String result;
            try { result = WineRuntime.run(this, 30, "--version"); }
            catch (Exception e) { result = "Wine failed: " + e; }
            final String output = result;
            runOnUiThread(() -> { if (!isFinishing()) status.append("\n" + output); });
        }));
        addButton(column, "Word", () -> startActivity(new Intent(this, WordActivity.class)));
        addButton(column, "Excel", () -> startActivity(new Intent(this, ExcelActivity.class)));
        addButton(column, "PowerPoint", () -> startActivity(new Intent(this, PowerPointActivity.class)));
        if (getIntent().getData() != null) {
            status.append("\nDocument received; opening and write-back require the Wine runtime. The original is unchanged.\n");
        }
        diagnose();
    }

    private void addButton(LinearLayout column, String text, Runnable action) {
        Button button = new Button(this);
        button.setText(text);
        button.setOnClickListener(view -> action.run());
        column.addView(button);
    }

    public static String probe(android.content.Context context) throws Exception {
        File directory = prefix(context);
        if (!directory.isDirectory() && !directory.mkdirs()) throw new java.io.IOException("Cannot create prefix");
        Process process = new ProcessBuilder(new File(context.getApplicationInfo().nativeLibraryDir,
            "libodprobe.so").getAbsolutePath(), directory.getAbsolutePath()).redirectErrorStream(true).start();
        if (!process.waitFor(15, TimeUnit.SECONDS)) {
            process.destroyForcibly();
            throw new java.io.IOException("Native probe timed out");
        }
        String output;
        try (java.io.InputStream input = process.getInputStream()) {
            java.io.ByteArrayOutputStream buffer = new java.io.ByteArrayOutputStream();
            byte[] block = new byte[1024];
            int count;
            while ((count = input.read(block)) != -1) buffer.write(block, 0, count);
            output = buffer.toString(StandardCharsets.UTF_8.name());
        }
        if (process.exitValue() != 0) throw new java.io.IOException("Native probe exit " + process.exitValue() + ": " + output);
        return output;
    }

    private void diagnose() {
        worker.submit(() -> {
            String result;
            try { result = probe(this); } catch (Exception e) { result = "Native diagnostics failed: " + e; }
            final String output = result;
            android.util.Log.i("OfficeDroid", output);
            runOnUiThread(() -> { if (!isFinishing()) status.append("\n" + output); });
        });
    }
    @Override protected void onDestroy() { worker.shutdownNow(); super.onDestroy(); }
}
