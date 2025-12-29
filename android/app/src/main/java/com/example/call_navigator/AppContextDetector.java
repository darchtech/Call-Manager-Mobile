package com.example.call_navigator;

import android.app.ActivityManager;
import android.app.usage.UsageEvents;
import android.app.usage.UsageStatsManager;
import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.os.Build;
import android.util.Log;

import java.util.List;

/**
 * Helper class to detect if user is currently in the app or outside
 * Used to determine whether to show native UI or overlay
 */
public class AppContextDetector {
    private static final String TAG = "AppContextDetector";
    
    /**
     * Determines if the user is currently in our app or outside
     * @param context Application context
     * @return true if user should see native UI (outside app), false if should see overlay (in app)
     */
    public static boolean shouldUseNativeUI(Context context) {
        try {
            // Method 1: Check if our app is in foreground
            if (isAppInForeground(context)) {
                Log.d(TAG, "App is in foreground - using overlay");
                return false; // Use overlay when in app
            }
            
            // Method 2: Check what app is currently in foreground
            String foregroundApp = getForegroundApp(context);
            if (foregroundApp != null) {
                boolean isSystemApp = isSystemApp(context, foregroundApp);
                boolean isLauncher = isLauncherApp(context, foregroundApp);
                
                Log.d(TAG, "Foreground app: " + foregroundApp + ", isSystem: " + isSystemApp + ", isLauncher: " + isLauncher);
                
                // Use native UI if:
                // 1. User is on launcher/home screen
                // 2. User is using a system app (dialer, contacts, etc.)
                // 3. User is on lock screen (no foreground app)
                if (isLauncher || isSystemApp || foregroundApp.equals(context.getPackageName())) {
                    Log.d(TAG, "Using native UI");
                    return true;
                }
            }
            
            // Default: if we can't determine context or user is in another app, use overlay
            Log.d(TAG, "Using overlay as default");
            return false;
            
        } catch (Exception e) {
            Log.e(TAG, "Error detecting app context", e);
            // Fallback to native UI for better user experience
            return true;
        }
    }
    
    /**
     * Check if our app is currently in the foreground
     */
    private static boolean isAppInForeground(Context context) {
        try {
            ActivityManager activityManager = (ActivityManager) context.getSystemService(Context.ACTIVITY_SERVICE);
            if (activityManager == null) return false;
            
            List<ActivityManager.RunningAppProcessInfo> processes = activityManager.getRunningAppProcesses();
            if (processes != null) {
                String packageName = context.getPackageName();
                for (ActivityManager.RunningAppProcessInfo processInfo : processes) {
                    if (processInfo.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND) {
                        for (String activeProcess : processInfo.pkgList) {
                            if (activeProcess.equals(packageName)) {
                                return true;
                            }
                        }
                    }
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "Error checking if app is in foreground", e);
        }
        return false;
    }
    
    /**
     * Get the package name of the app currently in foreground
     */
    private static String getForegroundApp(Context context) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                // Modern method using UsageStatsManager
                UsageStatsManager usageStatsManager = (UsageStatsManager) context.getSystemService(Context.USAGE_STATS_SERVICE);
                if (usageStatsManager != null) {
                    long currentTime = System.currentTimeMillis();
                    UsageEvents usageEvents = usageStatsManager.queryEvents(currentTime - 10000, currentTime);
                    
                    UsageEvents.Event event = new UsageEvents.Event();
                    String foregroundApp = null;
                    while (usageEvents.hasNextEvent()) {
                        usageEvents.getNextEvent(event);
                        if (event.getEventType() == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                            foregroundApp = event.getPackageName();
                        }
                    }
                    return foregroundApp;
                }
            }
            
            // Fallback method using ActivityManager
            ActivityManager activityManager = (ActivityManager) context.getSystemService(Context.ACTIVITY_SERVICE);
            if (activityManager != null) {
                List<ActivityManager.RunningAppProcessInfo> processes = activityManager.getRunningAppProcesses();
                if (processes != null && !processes.isEmpty()) {
                    for (ActivityManager.RunningAppProcessInfo processInfo : processes) {
                        if (processInfo.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND) {
                            if (processInfo.pkgList != null && processInfo.pkgList.length > 0) {
                                return processInfo.pkgList[0];
                            }
                        }
                    }
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "Error getting foreground app", e);
        }
        return null;
    }
    
    /**
     * Check if the given package is a system app
     */
    private static boolean isSystemApp(Context context, String packageName) {
        try {
            PackageManager packageManager = context.getPackageManager();
            ApplicationInfo appInfo = packageManager.getApplicationInfo(packageName, 0);
            return (appInfo.flags & ApplicationInfo.FLAG_SYSTEM) != 0;
        } catch (Exception e) {
            Log.e(TAG, "Error checking if app is system app: " + packageName, e);
            return false;
        }
    }
    
    /**
     * Check if the given package is a launcher app
     */
    private static boolean isLauncherApp(Context context, String packageName) {
        try {
            // Common launcher package patterns
            return packageName.contains("launcher") || 
                   packageName.contains("home") ||
                   packageName.equals("com.android.launcher3") ||
                   packageName.equals("com.google.android.launcher") ||
                   packageName.equals("com.samsung.android.app.launcher") ||
                   packageName.equals("com.miui.home") ||
                   packageName.equals("com.huawei.android.launcher") ||
                   packageName.equals("com.oppo.launcher");
        } catch (Exception e) {
            Log.e(TAG, "Error checking if app is launcher: " + packageName, e);
            return false;
        }
    }
    
    /**
     * Force native UI for specific scenarios
     */
    public static boolean shouldForceNativeUI(String callState, Context context) {
        // Always use native UI for incoming calls (better UX)
        if ("RINGING".equals(callState)) {
            Log.d(TAG, "Forcing native UI for incoming call");
            return true;
        }
        
        // Use native UI when making outgoing calls from our app
        if ("DIALING".equals(callState) || "CONNECTING".equals(callState)) {
            if (isAppInForeground(context)) {
                Log.d(TAG, "Using native UI for outgoing call from our app");
                return true;
            }
        }
        
        return false;
    }
    
    /**
     * Check if overlay permission is available and should be used
     */
    public static boolean canAndShouldUseOverlay(Context context, String callState) {
        try {
            // Check if overlay permission is granted
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (!android.provider.Settings.canDrawOverlays(context)) {
                    Log.d(TAG, "Overlay permission not granted - using native UI");
                    return false;
                }
            }
            
            // Don't use overlay for incoming calls
            if ("RINGING".equals(callState)) {
                return false;
            }
            
            // Check if user is in another app (not ours, not launcher)
            String foregroundApp = getForegroundApp(context);
            if (foregroundApp != null && 
                !foregroundApp.equals(context.getPackageName()) &&
                !isLauncherApp(context, foregroundApp)) {
                
                Log.d(TAG, "User in another app (" + foregroundApp + ") - using overlay");
                return true;
            }
            
            return false;
        } catch (Exception e) {
            Log.e(TAG, "Error checking overlay usage", e);
            return false;
        }
    }
}
