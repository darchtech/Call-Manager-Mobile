package com.example.call_navigator;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.PowerManager;
import android.telecom.Call;
import android.telecom.InCallService;
import android.telecom.CallAudioState;
import android.util.Log;
import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;
import com.example.call_navigator.PhoneNumberUtils;
import java.util.Arrays;
import java.util.List;

/**
 * Tracks call state using Telecom API for accurate ACTIVE (answered) state.
 * Requires default dialer role.
 */
public class CallTrackingInCallService extends InCallService {
    private static final String TAG = "CallTrackingInCallService";
    private static final String CHANNEL_ID = "call_tracking_channel";
    private boolean hasEverBeenActive = false;
    private int lastTelecomState = Call.STATE_DISCONNECTED;
    private boolean wasOutgoing = false;
    private boolean sawRinging = false;
    private static Call currentCall;
    private static CallTrackingInCallService instance;
    public static final String ACTION_CALL_DISCONNECTED = "com.example.call_navigator.ACTION_CALL_DISCONNECTED";
    public static final String ACTION_TOGGLE_SPEAKER = "com.example.call_navigator.ACTION_TOGGLE_SPEAKER";
    public static final String ACTION_END_CALL = "com.example.call_navigator.ACTION_END_CALL";
    private static final int NOTIF_ACTIVE_CALL_ID = 4001;
    private static boolean currentSpeakerOn = false;

    @Override
    public void onCallAdded(Call call) {
        super.onCallAdded(call);
        logDebug("onCallAdded: " + call);
        // Use CallManager to handle call state properly
        String number = getCallNumber(call);
        logDebug("New call added - Number: " + number + ", State: " + call.getState());
        // Register callback for this call
        call.registerCallback(callCallback);
        // Let CallManager decide how to handle this call
        if (call.getState() == Call.STATE_RINGING) {
            // Incoming call - if an active call exists, treat this as call waiting and
            // do NOT overwrite currentCall pointer (keep it on the controllable active call)
            CallManager.CallState managerState = CallManager.getInstance().getCurrentState();
            boolean activeExists = hasActiveCall();
            if (managerState == CallManager.CallState.ACTIVE ||
                managerState == CallManager.CallState.CALL_WAITING ||
                managerState == CallManager.CallState.HOLD ||
                activeExists) {
                // Call waiting scenario - preserve currentCall; just notify CallManager
                CallManager.getInstance().onIncomingCall(call, number);
            } else {
                // Regular incoming - make it the current controllable call
                currentCall = call;
                CallManager.getInstance().onIncomingCall(call, number);
            }
        } else if (call.getState() == Call.STATE_DIALING || call.getState() == Call.STATE_CONNECTING) {
            // Outgoing call
            currentCall = call;
            hasEverBeenActive = false;
            wasOutgoing = true;
            sawRinging = false;
            logDebug("Flags reset for outgoing call: wasOutgoing=true, sawRinging=false");
            notifyFlutter("CALL_DIALING", number);
        } else if (call.getState() == Call.STATE_ACTIVE) {
            // Active call
            currentCall = call;
            hasEverBeenActive = true;
            CallManager.getInstance().onCallAnswered();
            notifyFlutter("CALL_ACTIVE", number);
        }
    }

    @Override
    public void onCallRemoved(Call call) {
        super.onCallRemoved(call);
        logDebug("onCallRemoved: " + call);
        try { call.unregisterCallback(callCallback); } catch (Throwable ignored) {}
        
        // Check if this is the waiting call being removed (not the active call)
        CallManager manager = CallManager.getInstance();
        Call waitingCall = manager.getWaitingCall();
        
        if (waitingCall == call) {
            // Waiting call was removed - don't call onCallEnded() or reset flags
            // The active call is still ongoing
            logDebug("Waiting call removed, preserving active call context");
            return;
        }
        
        // This is the active call being removed
        hasEverBeenActive = false;
        if (currentCall == call) { 
            currentCall = null; 
            logDebug("Cleared currentCall reference");
        }
        // Only notify CallManager if active call is removed
        CallManager.getInstance().onCallEnded();
    }

    private final Call.Callback callCallback = new Call.Callback() {
        @Override
        public void onStateChanged(Call call, int state) {
            super.onStateChanged(call, state);
            logDebug("Telecom onStateChanged: state=" + state);
            String number = getCurrentCallNumber();
            logDebug("Current call number: " + number);
            lastTelecomState = state;
            switch (state) {
                case Call.STATE_DIALING:
                case Call.STATE_CONNECTING:
                    notifyFlutter("CALL_DIALING", number);
                    handleCallStateUI("DIALING", number);
                    break;
                case Call.STATE_RINGING:
                    notifyFlutter("CALL_RINGING", number);
                    sawRinging = true;
                    logDebug("CALL_RINGING observed: sawRinging=true");
                    // Check if we should show incoming call UI or handle as call waiting
                    CallManager.CallState managerState = CallManager.getInstance().getCurrentState();
                    // Also check if there's an active call using robust detection
                    boolean hasActive = hasActiveCall();
                    
                    if (managerState == CallManager.CallState.CALL_WAITING || 
                        managerState == CallManager.CallState.ACTIVE || 
                        managerState == CallManager.CallState.HOLD ||
                        hasActive) {
                        // Call waiting or active call exists - don't launch new activity, let ActiveCallActivity handle it
                        logDebug("Active call detected (state: " + managerState + ", hasActive: " + hasActive + "), not launching IncomingCallActivity");
                        notifyFlutter("CALL_WAITING_INCOMING", number);
                    } else {
                        // Regular incoming call - show incoming call UI
                        try { 
                            ensureScreenOn();
                            // Immediately show incoming UI with contact info
                            Context context = getApplicationContext();
                            String contactName = null;
                            if (!number.equals("Unknown")) {
                                contactName = ContactUtils.getContactName(context, number);
                            }
                            Intent incomingIntent = new Intent(context, IncomingCallActivity.class);
                            incomingIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
                            incomingIntent.putExtra(IncomingCallActivity.EXTRA_CALL_NUMBER, number);
                            if (contactName != null) {
                                incomingIntent.putExtra(IncomingCallActivity.EXTRA_CONTACT_NAME, contactName);
                            }
                            startActivity(incomingIntent);
                            logDebug("Started IncomingCallActivity for number: " + number + ", contact: " + contactName);
                        } catch (Throwable e) {
                            logDebug("Failed to start incoming activity: " + e.getMessage());
                        }
                    }
                    handleCallStateUI("RINGING", number);
                    break;
                case Call.STATE_ACTIVE:
                    notifyFlutter("CALL_CONNECTED", number);
                    hasEverBeenActive = true;
                    CallManager.getInstance().onCallAnswered();
                    handleCallStateUI("CONNECTED", number);
                    try { showActiveCallNotification(number); } catch (Throwable ignored) {}
                    break;
                case Call.STATE_DISCONNECTED:
                    // Check if this is the waiting call being disconnected (not the active call)
                    CallManager manager = CallManager.getInstance();
                    Call waitingCall = manager.getWaitingCall();
                    
                    if (waitingCall == call) {
                        // Waiting call disconnected - don't send disconnect broadcast or close activity
                        // The active call is still ongoing
                        logDebug("Waiting call disconnected, preserving active call. Not sending disconnect broadcast.");
                        // Promote state back to ACTIVE for listeners/UI
                        try { CallManager.getInstance().onCallAnswered(); } catch (Throwable ignored) {}
                        // Just notify Flutter about the declined call, but don't end call tracking
                        notifyFlutter("CALL_DECLINED_BY_CALLEE", number);
                        return; // Exit early, don't process as active call disconnect
                    }
                    
                    // This is the active call being disconnected
                    // Determine precise disconnect cause to distinguish caller-cancel vs callee-decline vs busy/timeout
                    int causeCode = android.telecom.DisconnectCause.UNKNOWN;
                    try {
                        if (call != null && call.getDetails() != null && call.getDetails().getDisconnectCause() != null) {
                            causeCode = call.getDetails().getDisconnectCause().getCode();
                        }
                    } catch (Throwable ignored) {}
                    String outcome;
                    switch (causeCode) {
                        case android.telecom.DisconnectCause.LOCAL:
                            // We (this device) hung up
                            if (hasEverBeenActive) {
                                // Call was connected, we ended it
                                outcome = wasOutgoing ? "CALL_ENDED_BY_CALLER" : "CALL_ENDED_BY_CALLEE";
                                logDebug("LOCAL + active => " + outcome + " (wasOutgoing=" + wasOutgoing + ")");
                            } else {
                                // Call never connected, we cancelled/declined
                                if (wasOutgoing) {
                                    // Outgoing call - we cancelled
                                    if (sawRinging) {
                                        outcome = "CALL_NO_ANSWER"; // User gave up while ringing
                                        logDebug("LOCAL + outgoing + sawRinging + never active => CALL_NO_ANSWER");
                                    } else {
                                        outcome = "CALL_CANCELLED_BY_CALLER"; // Cancelled before ringing
                                        logDebug("LOCAL + outgoing + no ringing + never active => CALL_CANCELLED_BY_CALLER");
                                    }
                                } else {
                                    // Incoming call - we rejected it
                                    outcome = "CALL_DECLINED_BY_CALLEE";
                                    logDebug("LOCAL + incoming + never active => CALL_DECLINED_BY_CALLEE");
                                }
                            }
                            break;
                        case android.telecom.DisconnectCause.REMOTE:
                        case android.telecom.DisconnectCause.REJECTED:
                            // Remote party hung up or declined
                            if (hasEverBeenActive) {
                                // Call was connected, remote ended it
                                outcome = wasOutgoing ? "CALL_ENDED_BY_CALLEE" : "CALL_ENDED_BY_CALLER";
                                logDebug("REMOTE/REJECTED + active => " + outcome + " (wasOutgoing=" + wasOutgoing + ")");
                            } else {
                                // Call never connected, remote declined/cancelled
                                if (wasOutgoing) {
                                    // Outgoing call - they declined
                                    outcome = "CALL_DECLINED_BY_CALLEE";
                                    logDebug("REMOTE/REJECTED + outgoing + never active => CALL_DECLINED_BY_CALLEE");
                                } else {
                                    // Incoming call - they cancelled before we answered
                                    outcome = "CALL_NO_ANSWER";
                                    logDebug("REMOTE/REJECTED + incoming + never active => CALL_NO_ANSWER");
                                }
                            }
                            break;
                        case android.telecom.DisconnectCause.BUSY:
                            outcome = "CALL_BUSY";
                            logDebug("BUSY => CALL_BUSY");
                            break;
                        case android.telecom.DisconnectCause.MISSED:
                            outcome = "CALL_NO_ANSWER";
                            logDebug("MISSED => CALL_NO_ANSWER");
                            break;
                        default:
                            // Fallback: use hasEverBeenActive to determine if call was connected
                            if (hasEverBeenActive) {
                                // Call was connected, determine who ended it based on wasOutgoing
                                outcome = wasOutgoing ? "CALL_ENDED_BY_CALLER" : "CALL_ENDED_BY_CALLEE";
                                logDebug("DEFAULT + active => " + outcome + " (wasOutgoing=" + wasOutgoing + ")");
                            } else {
                                // Call never connected, determine who cancelled
                                outcome = wasOutgoing ? "CALL_CANCELLED_BY_CALLER" : "CALL_DECLINED_BY_CALLER";
                                logDebug("DEFAULT + never active => " + outcome + " (wasOutgoing=" + wasOutgoing + ")");
                            }
                            break;
                    }
                    logDebug("Disconnect decision: causeCode=" + causeCode +
                             ", outcome=" + outcome +
                             ", flags { hasEverBeenActive=" + hasEverBeenActive +
                             ", wasOutgoing=" + wasOutgoing +
                             ", sawRinging=" + sawRinging +
                             " }");
                    notifyFlutter(outcome, number);
                    CallManager.getInstance().onCallEnded();
                    sendDisconnectBroadcast(number);
                    hasEverBeenActive = false;
                    wasOutgoing = false;
                    sawRinging = false;
                    try { hideActiveCallNotification(); } catch (Throwable ignored) {}
                    // Force close ActiveCallActivity if it's running
                    try {
                        Intent closeActivity = new Intent(getApplicationContext(), ActiveCallActivity.class);
                        closeActivity.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
                        closeActivity.putExtra("finish", true);
                        getApplicationContext().startActivity(closeActivity);
                        Log.d(TAG, "Attempted to close ActiveCallActivity");
                    } catch (Throwable e) {
                        Log.e(TAG, "Failed to close ActiveCallActivity", e);
                    }
                    // Don't navigate here, let Flutter handle it
                    break;
                default:
                    break;
            }
        }
    };

    // Helper method to get current call number with fallbacks
    public static String getCurrentCallNumber() {
        String telecomNumber = null;
        try {
            if (currentCall != null && currentCall.getDetails() != null) {
                android.net.Uri handle = currentCall.getDetails().getHandle();
                if (handle != null) {
                    telecomNumber = handle.getSchemeSpecificPart();
                }
            }
        } catch (Throwable ignored) {}
        // Use PhoneNumberUtils to get the best available number
        String receiverNumber = PhoneStateReceiver.getLastKnownNumber();
        return PhoneNumberUtils.getBestAvailableNumber(telecomNumber, null, receiverNumber);
    }

    private void sendDisconnectBroadcast(String number) {
        try {
            Intent i = new Intent(ACTION_CALL_DISCONNECTED);
            i.putExtra("phoneNumber", number);
            i.setPackage(getPackageName());
            getApplicationContext().sendBroadcast(i);
            Log.d(TAG, "Sent disconnect broadcast for number: " + number);
        } catch (Throwable e) {
            Log.e(TAG, "Failed to send disconnect broadcast", e);
        }
    }

    /**
     * Handle call state UI - decide between native Activities and overlay based on context
     */
    private void handleCallStateUI(String callState, String phoneNumber) {
        try {
            Context context = getApplicationContext();
            // Check if we should force native UI for this state
            if (AppContextDetector.shouldForceNativeUI(callState, context)) {
                launchNativeCallUI(callState, phoneNumber);
                return;
            }
            // Check if we should use overlay
            if (AppContextDetector.canAndShouldUseOverlay(context, callState)) {
                showCallOverlay(phoneNumber, callState);
                return;
            }
            // Default to native UI
            launchNativeCallUI(callState, phoneNumber);
        } catch (Exception e) {
            logDebug("Error handling call state UI: " + e.getMessage());
            // Fallback to native UI
            launchNativeCallUI(callState, phoneNumber);
        }
    }

    /**
     * Launch appropriate native call UI based on call state
     */
    private void launchNativeCallUI(String callState, String phoneNumber) {
        try {
            Context context = getApplicationContext();
            Intent intent = null;
            switch (callState) {
                case "RINGING":
                    intent = new Intent(context, IncomingCallActivity.class);
                    intent.putExtra(IncomingCallActivity.EXTRA_CALL_NUMBER, phoneNumber);
                    if (!phoneNumber.equals("Unknown")) {
                        try {
                            String contactName = ContactUtils.getContactName(context, phoneNumber);
                            if (contactName != null) {
                                intent.putExtra(IncomingCallActivity.EXTRA_CONTACT_NAME, contactName);
                            }
                        } catch (Throwable ignored) {}
                    }
                    break;
                case "DIALING":
                case "CONNECTING":
                    intent = new Intent(context, ActiveCallActivity.class);
                    intent.putExtra(ActiveCallActivity.EXTRA_CALL_NUMBER, phoneNumber);
                    intent.putExtra(ActiveCallActivity.EXTRA_CALL_DURATION, "00:00");
                    break;
                case "CONNECTED":
                case "ACTIVE":
                    intent = new Intent(context, ActiveCallActivity.class);
                    intent.putExtra(ActiveCallActivity.EXTRA_CALL_NUMBER, phoneNumber);
                    intent.putExtra(ActiveCallActivity.EXTRA_CALL_DURATION, "00:00");
                    if (!phoneNumber.equals("Unknown")) {
                        try {
                            String contactName = ContactUtils.getContactName(context, phoneNumber);
                            if (contactName != null) {
                                intent.putExtra(ActiveCallActivity.EXTRA_CONTACT_NAME, contactName);
                            }
                        } catch (Throwable ignored) {}
                    }
                    break;
            }
            if (intent != null) {
                intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | 
                               Intent.FLAG_ACTIVITY_CLEAR_TOP | 
                               Intent.FLAG_ACTIVITY_SINGLE_TOP);
                startActivity(intent);
                logDebug("Launched native UI for state: " + callState + " with number: " + phoneNumber);
            }
        } catch (Exception e) {
            logDebug("Failed to launch native call UI: " + e.getMessage());
            // Fallback to existing notification method
            if ("RINGING".equals(callState)) {
                showIncomingFullScreenNotification(phoneNumber);
            }
        }
    }

    /**
     * Show call overlay for when user is in another app
     */
    private void showCallOverlay(String phoneNumber, String callState) {
        try {
            Context context = getApplicationContext();
            Intent intent = new Intent(context, CallOverlayService.class);
            intent.setAction(CallOverlayService.ACTION_SHOW_CALL);
            intent.putExtra(CallOverlayService.EXTRA_PHONE_NUMBER, phoneNumber);
            intent.putExtra(CallOverlayService.EXTRA_CALL_STATE, callState);
            if (!phoneNumber.equals("Unknown")) {
                try {
                    String contactName = ContactUtils.getContactName(context, phoneNumber);
                    if (contactName != null) {
                        intent.putExtra(CallOverlayService.EXTRA_CONTACT_NAME, contactName);
                    }
                } catch (Throwable ignored) {}
            }
            startService(intent);
            logDebug("Showed call overlay for state: " + callState + " with number: " + phoneNumber);
        } catch (Exception e) {
            logDebug("Failed to show call overlay: " + e.getMessage());
        }
    }

    private void launchIncomingUI(String number) {
        try {
            Context context = getApplicationContext();
            Intent i = new Intent(context, IncomingCallActivity.class);
            i.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
            i.putExtra(IncomingCallActivity.EXTRA_CALL_NUMBER, number);
            startActivity(i);
        } catch (Throwable t) {
            logDebug("Failed to start IncomingCallActivity: " + t.getMessage());
            showNavigateNotification("Incoming call", "/call");
        }
    }

    // Static helpers used by IncomingCallActivity
    public static void answerCurrentCall(Context ctx) {
        try {
            CallManager manager = CallManager.getInstance();
            
            // Handle call waiting scenario
            if (manager.isCallWaiting()) {
                manager.answerWaitingCall();
                return;
            }
            
            // Handle regular incoming call - try CallManager first, then fallback to static currentCall
            Call call = manager.getCurrentCall();
            if (call != null && call.getState() == Call.STATE_RINGING) {
                call.answer(android.telecom.VideoProfile.STATE_AUDIO_ONLY);
                logDebug("Answered call via CallManager: " + call);
            } else if (currentCall != null && currentCall.getState() == Call.STATE_RINGING) {
                currentCall.answer(android.telecom.VideoProfile.STATE_AUDIO_ONLY);
                logDebug("Answered call via static currentCall: " + currentCall);
            } else {
                logDebug("No ringing call found to answer");
            }
        } catch (Throwable e) {
            logDebug("Failed to answer call: " + e.getMessage());
        }
    }

    public static void rejectCurrentCall(Context ctx) {
        try {
            CallManager manager = CallManager.getInstance();
            
            // Handle call waiting scenario
            if (manager.isCallWaiting()) {
                manager.declineWaitingCall();
                return;
            }
            
            // Handle regular incoming call - try CallManager first, then fallback to static currentCall
            Call call = manager.getCurrentCall();
            if (call != null && call.getState() == Call.STATE_RINGING) {
                call.disconnect();
                logDebug("Rejected call via CallManager: " + call);
            } else if (currentCall != null && currentCall.getState() == Call.STATE_RINGING) {
                currentCall.disconnect();
                logDebug("Rejected call via static currentCall: " + currentCall);
            } else {
                logDebug("No ringing call found to reject");
            }
        } catch (Throwable e) {
            logDebug("Failed to reject call: " + e.getMessage());
        }
    }

    private void notifyFlutter(String state, String number) {
        if (CallTrackingPlugin.channel != null) {
            CallTrackingPlugin.channel.invokeMethod("onCallStateChanged", Arrays.asList(state, number));
        }
    }

    private void ensureChannel(Context context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                    CHANNEL_ID,
                    "Incoming/Active Calls",
                    NotificationManager.IMPORTANCE_HIGH
            );
            NotificationManager nm = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
            nm.createNotificationChannel(channel);
        }
    }

    private void bringAppToFront(String route, String titleForFallbackNotification) {
        try {
            Context context = getApplicationContext();
            Intent intent = new Intent(context, MainActivity.class);
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
            intent.putExtra("navigateRoute", route);
            startActivity(intent);
            return;
        } catch (Throwable t) {
            logDebug("startActivity fallback to notification: " + t.getMessage());
        }
        showNavigateNotification(titleForFallbackNotification, route);
    }

    private void showNavigateNotification(String title, String route) {
        Context context = getApplicationContext();
        ensureChannel(context);
        // Prefer launching the dedicated IncomingCallActivity for full-screen behavior
        Intent intent = new Intent(context, IncomingCallActivity.class);
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        // Pass number if we still have an active call
        try {
            String number = getCurrentCallNumber();
            if (!number.equals("Unknown")) {
                intent.putExtra(IncomingCallActivity.EXTRA_CALL_NUMBER, number);
            }
        } catch (Throwable ignored) {}
        PendingIntent pi = PendingIntent.getActivity(
                context, 201, intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );
        Notification notification = new NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_menu_call)
                .setContentTitle(title)
                .setContentText("Opening app...")
                .setContentIntent(pi)
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setFullScreenIntent(pi, true)
                .build();
        NotificationManagerCompat.from(context).notify(2003, notification);
    }

    private void showIncomingFullScreenNotification(String number) {
        Context context = getApplicationContext();
        ensureChannel(context);
        Intent i = new Intent(context, IncomingCallActivity.class);
        i.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        if (number != null) i.putExtra(IncomingCallActivity.EXTRA_CALL_NUMBER, number);
        PendingIntent pi = PendingIntent.getActivity(
                context, 301, i,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );
        Notification notification = new NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_menu_call)
                .setContentTitle("Incoming call")
                .setContentText(number != null ? number : "Unknown")
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setOngoing(true)
                .setFullScreenIntent(pi, true)
                .build();
        NotificationManagerCompat.from(context).notify(3001, notification);
    }

    private PendingIntent pendingActivityIntentForActiveCall(String number) {
        Context context = getApplicationContext();
        Intent i = new Intent(context, ActiveCallActivity.class);
        i.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        i.putExtra(ActiveCallActivity.EXTRA_CALL_NUMBER, number);
        return PendingIntent.getActivity(context, 7001, i, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    private PendingIntent pendingActionToggleSpeaker(boolean toSpeaker) {
        Context context = getApplicationContext();
        Intent i = new Intent(ACTION_TOGGLE_SPEAKER);
        i.setPackage(getPackageName());
        i.putExtra("toSpeaker", toSpeaker);
        return PendingIntent.getBroadcast(context, 7002, i, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    private PendingIntent pendingActionEndCall() {
        Context context = getApplicationContext();
        Intent i = new Intent(ACTION_END_CALL);
        i.setPackage(getPackageName());
        return PendingIntent.getBroadcast(context, 7003, i, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    private void showActiveCallNotification(String number) {
        Context context = getApplicationContext();
        ensureChannel(context);
        String title = "Call in progress";
        String content = number != null && !number.isEmpty() ? number : "Unknown";
        NotificationCompat.Action speakerAction = new NotificationCompat.Action(
                android.R.drawable.ic_lock_silent_mode_off,
                currentSpeakerOn ? "Earpiece" : "Speaker",
                pendingActionToggleSpeaker(!currentSpeakerOn)
        );
        NotificationCompat.Action endAction = new NotificationCompat.Action(
                android.R.drawable.ic_menu_close_clear_cancel,
                "End",
                pendingActionEndCall()
        );
        Notification notification = new NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_menu_call)
                .setContentTitle(title)
                .setContentText(content)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setContentIntent(pendingActivityIntentForActiveCall(number))
                .addAction(speakerAction)
                .addAction(endAction)
                .build();
        NotificationManagerCompat.from(context).notify(NOTIF_ACTIVE_CALL_ID, notification);
    }

    private void updateActiveCallNotification(String number) {
        showActiveCallNotification(number);
    }

    private void hideActiveCallNotification() {
        NotificationManagerCompat.from(getApplicationContext()).cancel(NOTIF_ACTIVE_CALL_ID);
    }

    private void ensureScreenOn() {
        Context context = getApplicationContext();
        PowerManager pm = (PowerManager) context.getSystemService(Context.POWER_SERVICE);
        if (pm == null) return;
        PowerManager.WakeLock wl = pm.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK | PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "call_navigator:incoming_call_wakelock");
        wl.setReferenceCounted(false);
        wl.acquire(5000); // wake for 5 seconds
    }

    private static void logDebug(String msg) {
        Log.d("InCallService", msg);
        // Also forward logs to Flutter so they appear in the Flutter console
        try {
            if (CallTrackingPlugin.channel != null) {
                CallTrackingPlugin.channel.invokeMethod("debugLog", msg);
            }
        } catch (Throwable ignored) {}
    }

    @Override
    public void onCreate() {
        super.onCreate();
        instance = this;
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        if (instance == this) instance = null;
    }

    // ===== Outgoing/active call controls exposed to MainActivity =====
    public static boolean endCurrentCall() {
        // Prefer ending the actual ACTIVE/HOLDING call from the system list
        try {
            Call active = findActiveOrHeldCall();
            if (active != null) {
                active.disconnect();
                return true;
            }
        } catch (Throwable t) {
            Log.d(TAG, "Failed to end active/held call via system list: " + t.getMessage());
        }
        // Fallback to static reference
        try {
            if (currentCall != null && currentCall.getState() != Call.STATE_DISCONNECTED) {
                currentCall.disconnect();
                return true;
            }
        } catch (Throwable ignored) {}
        Log.d(TAG, "No active call found to end");
        return false;
    }

    public static boolean holdCurrentCall() {
        try { if (currentCall != null) { currentCall.hold(); return true; } } catch (Throwable ignored) {}
        return false;
    }

    public static boolean unholdCurrentCall() {
        try { if (currentCall != null) { currentCall.unhold(); return true; } } catch (Throwable ignored) {}
        return false;
    }

    public static boolean playDtmf(String tone) {
        try {
            if (currentCall != null && tone != null && !tone.isEmpty()) {
                currentCall.playDtmfTone(tone.charAt(0));
                return true;
            }
        } catch (Throwable ignored) {}
        return false;
    }

    public static boolean stopDtmf() {
        try { if (currentCall != null) { currentCall.stopDtmfTone(); return true; } } catch (Throwable ignored) {}
        return false;
    }

    public static boolean setMutedState(boolean muted) {
        try {
            if (instance != null) {
                instance.setMuted(muted);
                return true;
            }
        } catch (Throwable ignored) {}
        return false;
    }

    public static boolean setSpeaker(boolean on) {
        try {
            if (instance != null) {
                int route = on ? CallAudioState.ROUTE_SPEAKER : CallAudioState.ROUTE_EARPIECE;
                instance.setAudioRoute(route);
                return true;
            }
        } catch (Throwable ignored) {}
        return false;
    }

    public static int getCurrentState() {
        // Robust: derive from system calls first
        try {
            if (instance != null) {
                List<Call> calls = instance.getCalls();
                if (calls != null) {
                    // Priority order: ACTIVE, HOLDING, DIALING/CONNECTING, RINGING
                    for (Call c : calls) {
                        if (c.getState() == Call.STATE_ACTIVE) return Call.STATE_ACTIVE;
                    }
                    for (Call c : calls) {
                        if (c.getState() == Call.STATE_HOLDING) return Call.STATE_HOLDING;
                    }
                    for (Call c : calls) {
                        if (c.getState() == Call.STATE_DIALING || c.getState() == Call.STATE_CONNECTING) return Call.STATE_CONNECTING;
                    }
                    for (Call c : calls) {
                        if (c.getState() == Call.STATE_RINGING) return Call.STATE_RINGING;
                    }
                }
            }
        } catch (Throwable ignored) {}
        // Fallback to static pointer
        try { return currentCall != null ? currentCall.getState() : Call.STATE_DISCONNECTED; } catch (Throwable ignored) {}
        return Call.STATE_DISCONNECTED;
    }

    /**
     * Check if there's an active call in the system
     * Uses getCalls() to get all calls and check for ACTIVE/HOLDING states
     * This is the robust way to detect active calls, like system dialer
     */
    public static boolean hasActiveCall() {
        try {
            if (instance != null) {
                List<Call> calls = instance.getCalls();
                if (calls != null && !calls.isEmpty()) {
                    for (Call call : calls) {
                        int state = call.getState();
                        if (state == Call.STATE_ACTIVE || state == Call.STATE_HOLDING) {
                            return true; // Found an active or held call
                        }
                    }
                }
            }
        } catch (Throwable e) {
            Log.e(TAG, "Error checking for active calls", e);
        }
        return false;
    }

    private static Call findActiveOrHeldCall() {
        try {
            if (instance != null) {
                List<Call> calls = instance.getCalls();
                if (calls == null) return null;
                for (Call c : calls) {
                    if (c.getState() == Call.STATE_ACTIVE) return c;
                }
                for (Call c : calls) {
                    if (c.getState() == Call.STATE_HOLDING) return c;
                }
            }
        } catch (Throwable ignored) {}
        return null;
    }

    public static String getActiveCallNumber() {
        // Prefer the system-active call number
        try {
            Call active = findActiveOrHeldCall();
            if (active != null && active.getDetails() != null && active.getDetails().getHandle() != null) {
                return active.getDetails().getHandle().getSchemeSpecificPart();
            }
        } catch (Throwable ignored) {}
        // Fallback
        return getCurrentCallNumber();
    }

    private String getCallNumber(Call call) {
        String telecomNumber = null;
        try {
            if (call != null && call.getDetails() != null) {
                android.net.Uri handle = call.getDetails().getHandle();
                if (handle != null) {
                    telecomNumber = handle.getSchemeSpecificPart();
                }
            }
        } catch (Throwable ignored) {}
        // Use PhoneNumberUtils to get the best available number
        String receiverNumber = PhoneStateReceiver.getLastKnownNumber();
        return PhoneNumberUtils.getBestAvailableNumber(telecomNumber, null, receiverNumber);
    }
}