package com.example.call_navigator;

import android.content.Context;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodChannel;

/**
 * Simple plugin to hold a MethodChannel reference for InCallService to notify Flutter.
 */
public class CallTrackingPlugin implements FlutterPlugin {
    public static MethodChannel channel; // static so InCallService can access
    private Context context;

    @Override
    public void onAttachedToEngine(FlutterPluginBinding flutterPluginBinding) {
        context = flutterPluginBinding.getApplicationContext();
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "call_tracking");
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        if (channel != null) {
            channel.setMethodCallHandler(null);
            channel = null;
        }
    }
}
