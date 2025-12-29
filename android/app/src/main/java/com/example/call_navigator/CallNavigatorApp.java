package com.example.call_navigator;

import android.app.Application;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.FlutterEngineCache;
import io.flutter.plugins.GeneratedPluginRegistrant;
import io.flutter.embedding.engine.dart.DartExecutor;
import com.example.call_navigator.CallTrackingPlugin;

/**
 * Keeps a pre-warmed FlutterEngine alive to eliminate black screen
 * when returning from Recents or switching between native/Flutter.
 */
public class CallNavigatorApp extends Application {
    @Override
    public void onCreate() {
        super.onCreate();

        // Create and pre-warm Flutter engine
        FlutterEngine flutterEngine = new FlutterEngine(this);

        // Register all generated Flutter plugins
        GeneratedPluginRegistrant.registerWith(flutterEngine);
        flutterEngine.getPlugins().add(new CallTrackingPlugin());

        //  Start executing Dart code (modern Flutter)
        flutterEngine.getDartExecutor().executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault()
        );

        // Cache it for reuse by MainActivity
        FlutterEngineCache.getInstance().put("main_engine", flutterEngine);
    }
}
