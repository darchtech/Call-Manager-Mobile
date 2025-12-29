package com.example.call_navigator;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import android.content.Intent;
import android.util.Log;
import android.app.role.RoleManager;
import android.content.Context;
import android.os.Build;
import android.telecom.TelecomManager;
import android.Manifest;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Bundle;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import android.content.ComponentName;
import android.telecom.PhoneAccountHandle;
import android.telecom.PhoneAccount;
import android.provider.Settings;
import java.util.HashMap;
import java.util.Map;

public class MainActivity extends FlutterActivity {

    private static final String TAG = "MainActivity";
    private static final String NAV_CHANNEL = "call_tracking_nav";
    private static final String DIALER_CHANNEL = "dialer_role";
    private static final String CALL_CHANNEL = "call_tracking";
    private static final int REQ_ROLE_DIALER = 2001;
    private static final int REQ_CHANGE_DEFAULT = 2002;
    private static final int REQ_CALL_PERMS = 2003;

    private MethodChannel.Result pendingDialerResult;
    private MethodChannel dialerChannel;
    private MethodChannel.Result pendingPermissionResult;

    @Override
    public String getCachedEngineId() {
        // Use the engine we cached in CallNavigatorApp
        return "main_engine";
    }


    @Override
    public boolean shouldDestroyEngineWithHost() {
        // Keep the engine alive even if the Activity is destroyed
        return false;
    }

    @Override
    public io.flutter.embedding.android.RenderMode getRenderMode() {
        // Use TextureView to avoid surface destroy/black flicker
        return io.flutter.embedding.android.RenderMode.texture;
    }

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        // This is not needed anymore since we are using the engine cached in CallNavigatorApp
        // Ensure our custom plugin is registered so InCallService can notify Flutter
        // flutterEngine.getPlugins().add(new CallTrackingPlugin());

        // Navigation channel
        MethodChannel navChannel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), NAV_CHANNEL);
        handleInitialRoute(navChannel);

        // Dialer role channel
        dialerChannel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), DIALER_CHANNEL);
        dialerChannel.setMethodCallHandler((call, result) -> {
                    switch (call.method) {
                        case "isDefaultDialer":
                            result.success(isDefaultDialer());
                            break;
                        case "requestDefaultDialer":
                            requestDefaultDialer(result);
                            break;
                        case "checkDialerEligibility":
                            result.success(checkDialerEligibility());
                            break;
                        case "registerPhoneAccount":
                            registerPhoneAccount();
                            result.success(true);
                            break;
                        case "requestOverlayPermission":
                            requestOverlayPermission();
                            result.success(true);
                            break;
                        case "checkOverlayPermission":
                            result.success(Settings.canDrawOverlays(this));
                            break;
                        default:
                            result.notImplemented();
                    }
                });

        // Call control channel (reuse plugin channel so InCallService can also use it)
        if (CallTrackingPlugin.channel == null) {
            CallTrackingPlugin.channel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CALL_CHANNEL);
        }
        CallTrackingPlugin.channel.setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case "checkPermissions":
                    result.success(checkAndRequestPermissions());
                    break;
                case "startPhoneCall":
                    String number = call.argument("phoneNumber");
                    boolean placed = startPhoneCall(number);
                    result.success(placed);
                    break;
                case "endCall":
                    result.success(CallTrackingInCallService.endCurrentCall());
                    break;
                case "holdCall":
                    result.success(CallTrackingInCallService.holdCurrentCall());
                    break;
                case "unholdCall":
                    result.success(CallTrackingInCallService.unholdCurrentCall());
                    break;
                case "muteCall":
                    Boolean muted = call.argument("muted");
                    result.success(CallTrackingInCallService.setMutedState(muted != null && muted));
                    break;
                case "toggleSpeaker":
                    Boolean on = call.argument("on");
                    result.success(CallTrackingInCallService.setSpeaker(on != null && on));
                    break;
                case "playDTMF":
                    String tone = call.argument("tone");
                    result.success(CallTrackingInCallService.playDtmf(tone));
                    break;
                case "stopDTMF":
                    result.success(CallTrackingInCallService.stopDtmf());
                    break;
                case "getCallState":
                    result.success(CallTrackingInCallService.getCurrentState());
                    break;
                case "requestOverlayPermission":
                    requestOverlayPermission();
                    result.success(true);
                    break;
                case "checkOverlayPermission":
                    result.success(Settings.canDrawOverlays(this));
                    break;
                case "showCallOverlay":
                    String overlayNumber = call.argument("phoneNumber");
                    String overlayState = call.argument("callState");
                    showCallOverlay(overlayNumber, overlayState);
                    result.success(true);
                    break;
                case "hideCallOverlay":
                    hideCallOverlay();
                    result.success(true);
                    break;
                case "updateCallDuration":
                    String duration = call.argument("duration");
                    updateCallOverlayDuration(duration);
                    result.success(true);
                    break;
                case "showNativeCallUI":
                    String nativeCallState = call.argument("callState");
                    String nativePhoneNumber = call.argument("phoneNumber");
                    showNativeCallUI(nativeCallState, nativePhoneNumber);
                    result.success(true);
                    break;
                case "shouldUseNativeUI":
                    String checkCallState = call.argument("callState");
                    boolean useNative = AppContextDetector.shouldUseNativeUI(this);
                    result.success(useNative);
                    break;
                case "enterPostCallMode":
                    // Notify ActiveCallActivity to switch to post-call mode
                    Intent postCallIntent = new Intent(getApplicationContext(), ActiveCallActivity.class);
                    postCallIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
                    postCallIntent.putExtra("postCallMode", true);
                    startActivity(postCallIntent);
                    result.success(true);
                    break;
                case "hasActiveCall":
                    // Robust check from native side using InCallService.getCalls()
                    result.success(CallTrackingInCallService.hasActiveCall());
                    break;
                case "returnToCallScreen":
                    // Return to ActiveCallActivity if there's an active call
                    boolean hasActive = CallTrackingInCallService.hasActiveCall();
                    if (hasActive || CallTrackingInCallService.getCurrentState() != android.telecom.Call.STATE_DISCONNECTED) {
                        String callNumber = CallTrackingInCallService.getActiveCallNumber();
                        Intent callIntent = new Intent(getApplicationContext(), ActiveCallActivity.class);
                        // Note: FLAG_ACTIVITY_NEW_TASK required when launching from non-Activity context
                        // But since we're in MainActivity, we can use CLEAR_TOP | SINGLE_TOP
                        // However, ActiveCallActivity may be in different task, so keep NEW_TASK for safety
                        callIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
                        if (callNumber != null && !callNumber.isEmpty()) {
                            callIntent.putExtra(ActiveCallActivity.EXTRA_CALL_NUMBER, callNumber);
                        }
                        startActivity(callIntent);
                        // Finish current activity to return to call screen
                        finish();
                        result.success(true);
                    } else {
                        result.success(false);
                    }
                    break;
                default:
                    result.notImplemented();
            }
        });
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        // Register phone account to improve dialer eligibility
        registerPhoneAccount();
        
        Log.d(TAG, "MainActivity created. Package: " + getPackageName());
        Log.d(TAG, "Android version: " + Build.VERSION.SDK_INT);
        Log.d(TAG, "Device manufacturer: " + Build.MANUFACTURER);
        Log.d(TAG, "Device model: " + Build.MODEL);

        // Allow showing over lock screen for incoming call UI
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(true);
                setTurnScreenOn(true);
            } else {
                getWindow().addFlags(
                        android.view.WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED |
                        android.view.WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON |
                        android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                );
            }
        } catch (Throwable ignored) {}
    }

    // Handle navigation when app is launched from a notification
    private void handleInitialRoute(MethodChannel navChannel) {
        String initialRoute = getIntent() != null ? getIntent().getStringExtra("navigateRoute") : null;
        if (initialRoute != null && !initialRoute.isEmpty()) {
            Log.d(TAG, "Initial navigateTo=" + initialRoute);
            
            // Check for additional parameters
            String phoneNumber = getIntent().getStringExtra("phoneNumber");
            boolean editMode = getIntent().getBooleanExtra("editMode", false);
            
            if (phoneNumber != null || editMode) {
                // Pass additional parameters to Flutter
                Map<String, Object> params = new HashMap<>();
                params.put("route", initialRoute);
                if (phoneNumber != null) {
                    params.put("phoneNumber", phoneNumber);
                }
                if (editMode) {
                    params.put("editMode", editMode);
                }
                navChannel.invokeMethod("navigateToWithParams", params);
            } else {
                navChannel.invokeMethod("navigateTo", initialRoute);
            }
        }
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);

        FlutterEngine engine = getFlutterEngine();
        if (engine != null) {
            String route = intent.getStringExtra("navigateRoute");
            if (route != null && !route.isEmpty()) {
                Log.d(TAG, "onNewIntent navigateTo=" + route);
                
                // Check for additional parameters
                String phoneNumber = intent.getStringExtra("phoneNumber");
                boolean editMode = intent.getBooleanExtra("editMode", false);
                
                if (phoneNumber != null || editMode) {
                    // Pass additional parameters to Flutter
                    Map<String, Object> params = new HashMap<>();
                    params.put("route", route);
                    if (phoneNumber != null) {
                        params.put("phoneNumber", phoneNumber);
                    }
                    if (editMode) {
                        params.put("editMode", editMode);
                    }
                    new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), NAV_CHANNEL)
                            .invokeMethod("navigateToWithParams", params);
                } else {
                    new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), NAV_CHANNEL)
                            .invokeMethod("navigateTo", route);
                }
            }
        }
    }

    // Check if app is default dialer
    private boolean isDefaultDialer() {
        TelecomManager tm = (TelecomManager) getSystemService(Context.TELECOM_SERVICE);
        String defaultDialer = tm != null ? tm.getDefaultDialerPackage() : null;
        boolean isDefault = getPackageName().equals(defaultDialer);
        Log.d(TAG, "Default dialer package: " + defaultDialer + ", isDefault: " + isDefault);
        return isDefault;
    }

    // Check dialer eligibility and log detailed info
    private String checkDialerEligibility() {
        StringBuilder info = new StringBuilder();
        
        // Check if we're already default
        boolean isDefault = isDefaultDialer();
        info.append("Is default dialer: ").append(isDefault).append("\n");
        
        // Check RoleManager availability (Android Q+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            RoleManager roleManager = (RoleManager) getSystemService(Context.ROLE_SERVICE);
            if (roleManager != null) {
                boolean roleAvailable = roleManager.isRoleAvailable(RoleManager.ROLE_DIALER);
                boolean roleHeld = roleManager.isRoleHeld(RoleManager.ROLE_DIALER);
                info.append("Role available: ").append(roleAvailable).append("\n");
                info.append("Role held: ").append(roleHeld).append("\n");
            } else {
                info.append("RoleManager is null\n");
            }
        } else {
            info.append("Android version < Q, using legacy method\n");
        }
        
        // Check TelecomManager
        TelecomManager tm = (TelecomManager) getSystemService(Context.TELECOM_SERVICE);
        if (tm != null) {
            String currentDefault = tm.getDefaultDialerPackage();
            info.append("Current default dialer: ").append(currentDefault).append("\n");
        }
        
        // Check permissions
        String[] requiredPerms = {
            Manifest.permission.CALL_PHONE,
            Manifest.permission.READ_PHONE_STATE,
            Manifest.permission.READ_CALL_LOG,
            Manifest.permission.WRITE_CALL_LOG,
            Manifest.permission.ANSWER_PHONE_CALLS,
            Manifest.permission.READ_CONTACTS
        };
        
        for (String perm : requiredPerms) {
            boolean granted = hasPermission(perm);
            info.append(perm).append(": ").append(granted).append("\n");
        }
        
        Log.d(TAG, "Dialer eligibility info:\n" + info.toString());
        return info.toString();
    }

    // Register a phone account to improve dialer app eligibility
    private void registerPhoneAccount() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                TelecomManager telecomManager = (TelecomManager) getSystemService(Context.TELECOM_SERVICE);
                if (telecomManager != null) {
                    ComponentName componentName = new ComponentName(this, MyConnectionService.class);
                    PhoneAccountHandle phoneAccountHandle = new PhoneAccountHandle(componentName, "CallNavigatorAccount");
                    
                    PhoneAccount phoneAccount = new PhoneAccount.Builder(phoneAccountHandle, "Call Navigator")
                            .setCapabilities(PhoneAccount.CAPABILITY_CALL_PROVIDER)
                            .build();
                    
                    telecomManager.registerPhoneAccount(phoneAccount);
                    Log.d(TAG, "Phone account registered successfully");
                }
            } catch (Exception e) {
                Log.e(TAG, "Failed to register phone account", e);
            }
        }
    }

    private boolean hasPermission(String permission) {
        return ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED;
    }

    private boolean checkAndRequestPermissions() {
        String[] required = new String[] {
                Manifest.permission.CALL_PHONE,
                Manifest.permission.READ_PHONE_STATE,
                Manifest.permission.READ_CALL_LOG,
                Manifest.permission.WRITE_CALL_LOG,
                Manifest.permission.ANSWER_PHONE_CALLS,
                Manifest.permission.READ_CONTACTS
        };
        java.util.List<String> missing = new java.util.ArrayList<>();
        for (String p : required) {
            if (!hasPermission(p)) missing.add(p);
        }
        if (!missing.isEmpty()) {
            Log.d(TAG, "Requesting permissions: " + missing.toString());
            ActivityCompat.requestPermissions(this, missing.toArray(new String[0]), REQ_CALL_PERMS);
            return false;
        }
        Log.d(TAG, "All permissions granted");
        return true;
    }

    private boolean startPhoneCall(String phoneNumber) {
        if (phoneNumber == null || phoneNumber.trim().isEmpty()) return false;
        if (!checkAndRequestPermissions()) return false;
        try {
            Uri uri = Uri.fromParts("tel", phoneNumber, null);
            TelecomManager tm = (TelecomManager) getSystemService(Context.TELECOM_SERVICE);
            if (tm != null && isDefaultDialer()) {
                tm.placeCall(uri, new Bundle());
                return true;
            } else {
                // Fallback for non-default case
                Intent intent = new Intent(Intent.ACTION_CALL, uri);
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                startActivity(intent);
                return true;
            }
        } catch (Exception e) {
            Log.e(TAG, "startPhoneCall error", e);
            return false;
        }
    }

    // Request default dialer role reachable from Flutter channel
    private void requestDefaultDialer(MethodChannel.Result result) {
        Log.d(TAG, "requestDefaultDialer called");
        
        if (isDefaultDialer()) {
            Log.d(TAG, "Already default dialer");
            result.success(true);
            return;
        }

        // First ensure we have all permissions
        if (!checkAndRequestPermissions()) {
            Log.d(TAG, "Permissions not granted, deferring default dialer request");
            pendingDialerResult = result;
            return;
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // Android Q+ uses RoleManager
                RoleManager roleManager = (RoleManager) getSystemService(Context.ROLE_SERVICE);
                if (roleManager != null) {
                    if (!roleManager.isRoleAvailable(RoleManager.ROLE_DIALER)) {
                        Log.e(TAG, "ROLE_DIALER not available on this device");
                        result.error("ROLE_NOT_AVAILABLE", "Dialer role not available on this device", null);
                        return;
                    }
                    
                    if (roleManager.isRoleHeld(RoleManager.ROLE_DIALER)) {
                        Log.d(TAG, "Role already held");
                        result.success(true);
                        return;
                    }
                    
                    Intent intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_DIALER);
                    if (intent.resolveActivity(getPackageManager()) != null) {
                        Log.d(TAG, "Launching ROLE_DIALER request intent");
                        pendingDialerResult = result;
                        startActivityForResult(intent, REQ_ROLE_DIALER);
                        return;
                    } else {
                        Log.e(TAG, "No activity found to handle role request intent");
                        result.error("NO_ACTIVITY", "No activity found to handle role request", null);
                        return;
                    }
                } else {
                    Log.e(TAG, "RoleManager is null");
                    result.error("ROLE_MANAGER_NULL", "RoleManager not available", null);
                    return;
                }
            } else {
                // Android < Q uses TelecomManager
                Intent intent = new Intent(TelecomManager.ACTION_CHANGE_DEFAULT_DIALER);
                intent.putExtra(TelecomManager.EXTRA_CHANGE_DEFAULT_DIALER_PACKAGE_NAME, getPackageName());
                
                if (intent.resolveActivity(getPackageManager()) != null) {
                    Log.d(TAG, "Launching ACTION_CHANGE_DEFAULT_DIALER intent");
                    pendingDialerResult = result;
                    startActivityForResult(intent, REQ_CHANGE_DEFAULT);
                    return;
                } else {
                    Log.e(TAG, "No activity found to handle default dialer change");
                    result.error("NO_ACTIVITY", "No activity found to handle dialer change", null);
                    return;
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "requestDefaultDialer error", e);
            result.error("DIALER_ROLE_ERROR", e.getMessage(), null);
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        
        Log.d(TAG, "onActivityResult: requestCode=" + requestCode + ", resultCode=" + resultCode);

        if (requestCode == REQ_ROLE_DIALER || requestCode == REQ_CHANGE_DEFAULT) {
            // Give system time to update
            new android.os.Handler().postDelayed(() -> {
                boolean nowDefault = isDefaultDialer();
                Log.d(TAG, "Default dialer request completed. isDefaultDialer=" + nowDefault);
                Log.d(TAG, "Result code was: " + resultCode);

                if (pendingDialerResult != null) {
                    pendingDialerResult.success(nowDefault);
                    pendingDialerResult = null;
                }

                // Notify Flutter
                if (dialerChannel != null) {
                    try {
                        dialerChannel.invokeMethod("onDefaultDialerResult", nowDefault);
                    } catch (Exception ignored) {}
                }
            }, 1000); // Wait 1 second for system to update
        }
    }

    // Overlay permission and control methods
    private void requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            Intent intent = new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION);
            intent.setData(Uri.parse("package:" + getPackageName()));
            startActivity(intent);
        }
    }

    private void showCallOverlay(String phoneNumber, String callState) {
        Intent intent = new Intent(this, CallOverlayService.class);
        intent.setAction(CallOverlayService.ACTION_SHOW_CALL);
        intent.putExtra(CallOverlayService.EXTRA_PHONE_NUMBER, phoneNumber);
        intent.putExtra(CallOverlayService.EXTRA_CALL_STATE, callState);
        startService(intent);
    }

    private void hideCallOverlay() {
        Intent intent = new Intent(this, CallOverlayService.class);
        intent.setAction(CallOverlayService.ACTION_HIDE_CALL);
        startService(intent);
    }

    private void updateCallOverlayDuration(String duration) {
        Intent intent = new Intent(this, CallOverlayService.class);
        intent.setAction(CallOverlayService.ACTION_UPDATE_DURATION);
        intent.putExtra(CallOverlayService.EXTRA_CALL_DURATION, duration);
        startService(intent);
    }

    private void showNativeCallUI(String callState, String phoneNumber) {
        try {
            Intent intent = null;
            
            switch (callState) {
                case "RINGING":
                    intent = new Intent(this, IncomingCallActivity.class);
                    intent.putExtra(IncomingCallActivity.EXTRA_CALL_NUMBER, phoneNumber);
                    break;
                    
                case "DIALING":
                case "CONNECTING":
                    intent = new Intent(this, OutgoingCallActivity.class);
                    intent.putExtra(OutgoingCallActivity.EXTRA_CALL_NUMBER, phoneNumber);
                    intent.putExtra(OutgoingCallActivity.EXTRA_CALL_STATE, callState);
                    break;
                    
                case "CONNECTED":
                case "ACTIVE":
                    intent = new Intent(this, ActiveCallActivity.class);
                    intent.putExtra(ActiveCallActivity.EXTRA_CALL_NUMBER, phoneNumber);
                    break;
            }
            
            if (intent != null) {
                intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | 
                               Intent.FLAG_ACTIVITY_CLEAR_TOP | 
                               Intent.FLAG_ACTIVITY_SINGLE_TOP);
                startActivity(intent);
                Log.d(TAG, "Launched native UI from Flutter for state: " + callState);
            }
            
        } catch (Exception e) {
            Log.e(TAG, "Failed to launch native call UI from Flutter", e);
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        
        Log.d(TAG, "onRequestPermissionsResult: requestCode=" + requestCode);
        
        if (requestCode == REQ_CALL_PERMS) {
            boolean allGranted = true;
            if (grantResults != null) {
                for (int i = 0; i < grantResults.length; i++) {
                    Log.d(TAG, "Permission " + permissions[i] + ": " + 
                          (grantResults[i] == PackageManager.PERMISSION_GRANTED ? "GRANTED" : "DENIED"));
                    if (grantResults[i] != PackageManager.PERMISSION_GRANTED) {
                        allGranted = false;
                    }
                }
            } else {
                allGranted = false;
            }
            
            Log.d(TAG, "All permissions granted: " + allGranted);
            
            // If we have a pending dialer request and permissions are now granted
            if (allGranted && pendingDialerResult != null) {
                Log.d(TAG, "Permissions granted, retrying default dialer request");
                requestDefaultDialer(pendingDialerResult);
                return; // Don't clear pendingDialerResult here, requestDefaultDialer will handle it
            }
            
            if (CallTrackingPlugin.channel != null) {
                try { 
                    CallTrackingPlugin.channel.invokeMethod("onPermissionResult", allGranted); 
                } catch (Exception ignored) {}
            }
        }
    }
}