package com.example.call_navigator;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.telephony.TelephonyManager;
import android.util.Log;
import android.os.Handler;
import android.os.Looper;
import com.example.call_navigator.PhoneNumberUtils;
import com.example.call_navigator.CallManager;

/**
 * Broadcast receiver that monitors phone state changes
 * Works even when not the default dialer
 */
public class PhoneStateReceiver extends BroadcastReceiver {
    private static final String TAG = "PhoneStateReceiver";
    
    private static String lastState = TelephonyManager.EXTRA_STATE_IDLE;
    private static String lastNumber = "";
    private static boolean isOutgoingCall = false;
    
    public static String getLastKnownNumber() {
        return lastNumber;
    }
    
    @Override
    public void onReceive(Context context, Intent intent) {
        try {
            String action = intent.getAction();
            Log.d(TAG, "Received action: " + action);
            
            if (TelephonyManager.ACTION_PHONE_STATE_CHANGED.equals(action)) {
                handlePhoneStateChange(context, intent);
            } else if (Intent.ACTION_NEW_OUTGOING_CALL.equals(action)) {
                handleOutgoingCall(context, intent);
            }
        } catch (Exception e) {
            Log.e(TAG, "Error in onReceive", e);
        }
    }
    
    private void handlePhoneStateChange(Context context, Intent intent) {
        String state = intent.getStringExtra(TelephonyManager.EXTRA_STATE);
        String incomingNumber = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER);
        
        Log.d(TAG, "Phone state changed: " + state + ", incoming number from intent: " + incomingNumber);
        
        if (state == null) return;
        
        // Handle phone number priority using utility
        String phoneNumber = PhoneNumberUtils.getBestAvailableNumber(
            incomingNumber, 
            null, // We'll get CallService number separately
            lastNumber
        );
        
        // Try to get from CallTrackingInCallService if still Unknown and we're default dialer
        if (phoneNumber.equals("Unknown") && isOurDefaultDialer(context)) {
            try {
                String callServiceNumber = CallTrackingInCallService.getCurrentCallNumber();
                if (PhoneNumberUtils.isValidNumber(callServiceNumber)) {
                    phoneNumber = callServiceNumber;
                }
            } catch (Throwable ignored) {}
        }
        
        // Update last known number if we have a valid one
        if (PhoneNumberUtils.isValidNumber(phoneNumber)) {
            lastNumber = phoneNumber;
        }
        
        Log.d(TAG, "Final phone number for state " + state + ": " + phoneNumber);

        boolean isDefault = isOurDefaultDialer(context);
        
        if (TelephonyManager.EXTRA_STATE_RINGING.equals(state)) {
            // Incoming call - show Truecaller-style overlay with API lookup
            isOutgoingCall = false;
            
            // Use a final variable for lambda
            final String finalPhoneNumber = phoneNumber;
            
            // If number is Unknown and we're default dialer, try delayed retry to get from CallTrackingInCallService
            // This helps with timing issues where CallTrackingInCallService hasn't received the call yet
            if (finalPhoneNumber.equals("Unknown") && isDefault) {
                Handler handler = new Handler(Looper.getMainLooper());
                handler.postDelayed(() -> {
                    try {
                        String retryNumber = CallTrackingInCallService.getCurrentCallNumber();
                        if (PhoneNumberUtils.isValidNumber(retryNumber)) {
                            Log.d(TAG, "Retry successful: got number from CallTrackingInCallService: " + retryNumber);
                            lastNumber = retryNumber;
                            // Update Flutter with the correct number
                            notifyFlutter(context, "CALL_RINGING", retryNumber);
                        } else {
                            Log.w(TAG, "Retry failed: still no valid number from CallTrackingInCallService");
                        }
                    } catch (Throwable e) {
                        Log.e(TAG, "Retry failed with exception", e);
                    }
                }, 500); // Wait 500ms for CallTrackingInCallService to receive the call
            }
            
            String contactName = null;
            if (!finalPhoneNumber.equals("Unknown")) {
                try {
                    contactName = ContactUtils.getContactName(context, finalPhoneNumber);
                    Log.d(TAG, "Contact lookup for " + finalPhoneNumber + ": " + contactName);
                } catch (Throwable e) {
                    Log.e(TAG, "Contact lookup failed", e);
                }
            } else {
                // Log warning about missing phone number for debugging
                Log.w(TAG, "WARNING: Incoming call detected but phone number is Unknown. " +
                          "EXTRA_INCOMING_NUMBER=" + incomingNumber + 
                          ", isDefaultDialer=" + isDefault + 
                          ". This may be due to Android privacy restrictions.");
            }
            
            // Show Truecaller-style overlay for incoming calls (even with Unknown number - API might have it)
            showIncomingCallOverlay(context, finalPhoneNumber, contactName);
            
            if (isDefault) {
                // Check if there's an active call before launching IncomingCallActivity
                // If active call exists, this is call waiting - don't launch IncomingCallActivity
                boolean hasActiveCall = CallTrackingInCallService.hasActiveCall();
                CallManager.CallState managerState = CallManager.getInstance().getCurrentState();
                
                if (hasActiveCall || 
                    managerState == CallManager.CallState.ACTIVE || 
                    managerState == CallManager.CallState.HOLD ||
                    managerState == CallManager.CallState.CALL_WAITING) {
                    // Active call exists - this is call waiting, don't launch IncomingCallActivity
                    Log.d(TAG, "Active call detected (hasActive: " + hasActiveCall + ", state: " + managerState + 
                               "), not launching IncomingCallActivity for call waiting");
                } else {
                    // No active call - regular incoming call, show incoming call UI
                    try {
                        Intent incomingIntent = new Intent(context, IncomingCallActivity.class);
                        // NEW_TASK is required from BroadcastReceiver, but same taskAffinity keeps them in same task
                        // Don't use CLEAR_TOP here as it can interfere with task stack when called from BroadcastReceiver
                        incomingIntent.setFlags(
                            Intent.FLAG_ACTIVITY_NEW_TASK | 
                            Intent.FLAG_ACTIVITY_SINGLE_TOP
                        );
                        incomingIntent.putExtra(IncomingCallActivity.EXTRA_CALL_NUMBER, finalPhoneNumber);
                        if (contactName != null) {
                            incomingIntent.putExtra(IncomingCallActivity.EXTRA_CONTACT_NAME, contactName);
                        }
                        Log.d(TAG, "Attempting to start IncomingCallActivity with number: " + finalPhoneNumber + ", contact: " + contactName);
                        context.startActivity(incomingIntent);
                        Log.d(TAG, "Successfully started IncomingCallActivity");
                    } catch (Exception e) {
                        Log.e(TAG, "Failed to start IncomingCallActivity", e);
                        e.printStackTrace();
                    }
                }
            } else {
                Log.w(TAG, "Not starting IncomingCallActivity - not default dialer (isDefault=" + isDefault + ")");
            }
            notifyFlutter(context, "CALL_RINGING", finalPhoneNumber);
            
        } else if (TelephonyManager.EXTRA_STATE_OFFHOOK.equals(state)) {
            // If default dialer, let InCallService drive UI for active state to avoid duplicates
            if (isDefault) {
                return;
            }
            // Call answered or outgoing call connected
            if (isOutgoingCall) {
                // Not default dialer: don't show our UI
                notifyFlutter(context, "CALL_CONNECTED", lastNumber);
            } else {
                // Not default dialer: don't show our UI
                notifyFlutter(context, "CALL_CONNECTED", phoneNumber);
            }
        } else if (TelephonyManager.EXTRA_STATE_IDLE.equals(state)) {
            // Call ended
            if (!lastState.equals(TelephonyManager.EXTRA_STATE_IDLE)) {
                if (isDefault) {
                    hideCallOverlay(context);
                }
                
                String endedNumber = !lastNumber.isEmpty() ? lastNumber : phoneNumber;
                if (lastState.equals(TelephonyManager.EXTRA_STATE_OFFHOOK)) {
                    notifyFlutter(context, "CALL_ENDED_CONNECTED", endedNumber);
                    sendDisconnectBroadcast(context, endedNumber);
                } else {
                    notifyFlutter(context, "CALL_ENDED_NO_ANSWER", endedNumber);
                    sendDisconnectBroadcast(context, endedNumber);
                }
            }
            isOutgoingCall = false;
            // Don't clear lastNumber immediately, keep it for a bit in case of race conditions
            new Handler(Looper.getMainLooper()).postDelayed(() -> {
                lastNumber = "";
            }, 2000);
        }
        
        lastState = state;
    }
    
    private void handleOutgoingCall(Context context, Intent intent) {
        String phoneNumber = intent.getStringExtra(Intent.EXTRA_PHONE_NUMBER);
        Log.d(TAG, "Outgoing call to: " + phoneNumber);
        
        if (phoneNumber != null) {
            lastNumber = phoneNumber;
            isOutgoingCall = true;
            
            // Delay showing overlay for outgoing calls
            new Handler(Looper.getMainLooper()).postDelayed(() -> {
                if (isOurDefaultDialer(context)) {
                    showCallOverlay(context, phoneNumber, "DIALING");
                }
                notifyFlutter(context, "CALL_DIALING", phoneNumber);
            }, 1000);
        }
    }
    
    private void showCallOverlay(Context context, String phoneNumber, String callState) {
        // Use hybrid approach - choose between native UI and overlay based on context
        try {
            // Check if we should force native UI for this state
            if (AppContextDetector.shouldForceNativeUI(callState, context)) {
                showNativeCallUI(context, phoneNumber, callState);
                return;
            }
            
            // Check if we should use overlay
            if (AppContextDetector.canAndShouldUseOverlay(context, callState)) {
                showCallOverlayService(context, phoneNumber, callState);
                return;
            }
            
            // Default to native UI
            showNativeCallUI(context, phoneNumber, callState);
            
        } catch (Exception e) {
            Log.e(TAG, "Error in showCallOverlay", e);
            // Fallback to overlay service
            showCallOverlayService(context, phoneNumber, callState);
        }
    }
    
    private void showNativeCallUI(Context context, String phoneNumber, String callState) {
        try {
            Intent intent = null;
            
            switch (callState) {
                case "RINGING":
                    intent = new Intent(context, IncomingCallActivity.class);
                    intent.putExtra(IncomingCallActivity.EXTRA_CALL_NUMBER, phoneNumber);
                    // Always try to get contact name for incoming calls
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
                context.startActivity(intent);
                Log.d(TAG, "Launched native UI for state: " + callState + " with number: " + phoneNumber);
            }
            
        } catch (Exception e) {
            Log.e(TAG, "Failed to launch native call UI", e);
            // Fallback to overlay
            showCallOverlayService(context, phoneNumber, callState);
        }
    }
    
    private void showIncomingCallOverlay(Context context, String phoneNumber, String contactName) {
        try {
            Log.d(TAG, "Showing Truecaller-style overlay for incoming call: " + phoneNumber);
            
            Intent intent = new Intent(context, CallOverlayService.class);
            intent.setAction(CallOverlayService.ACTION_SHOW_INCOMING_CALL);
            intent.putExtra(CallOverlayService.EXTRA_PHONE_NUMBER, phoneNumber);
            if (contactName != null) {
                intent.putExtra(CallOverlayService.EXTRA_CONTACT_NAME, contactName);
            }
            context.startService(intent);
            
            Log.d(TAG, "Triggered incoming call overlay with API lookup for: " + phoneNumber);
        } catch (Exception e) {
            Log.e(TAG, "Failed to show incoming call overlay", e);
        }
    }
    
    private void showCallOverlayService(Context context, String phoneNumber, String callState) {
        try {
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
            context.startService(intent);
            Log.d(TAG, "Showed call overlay for state: " + callState + " with number: " + phoneNumber);
        } catch (Exception e) {
            Log.e(TAG, "Failed to show call overlay service", e);
        }
    }
    
    private void hideCallOverlay(Context context) {
        Intent intent = new Intent(context, CallOverlayService.class);
        intent.setAction(CallOverlayService.ACTION_HIDE_CALL);
        context.startService(intent);
    }
    
    private void notifyFlutter(Context context, String state, String phoneNumber) {
        try {
            if (CallTrackingPlugin.channel != null) {
                CallTrackingPlugin.channel.invokeMethod("onCallStateChanged", 
                    java.util.Arrays.asList(state, phoneNumber));
                Log.d(TAG, "Notified Flutter: " + state + " " + phoneNumber);
            }
        } catch (Exception e) {
            Log.e(TAG, "Failed to notify Flutter", e);
        }
    }

    private void sendDisconnectBroadcast(Context context, String number) {
        try {
            Intent i = new Intent(CallTrackingInCallService.ACTION_CALL_DISCONNECTED);
            i.putExtra("phoneNumber", number);
            i.setPackage(context.getPackageName());
            context.sendBroadcast(i);
        } catch (Throwable ignored) {}
    }

    private boolean isOurDefaultDialer(Context context) {
        try {
            android.telecom.TelecomManager tm = (android.telecom.TelecomManager) context.getSystemService(Context.TELECOM_SERVICE);
            String defaultDialer = tm != null ? tm.getDefaultDialerPackage() : null;
            return context.getPackageName().equals(defaultDialer);
        } catch (Throwable t) {
            return false;
        }
    }
}