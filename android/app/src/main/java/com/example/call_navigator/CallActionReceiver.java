package com.example.call_navigator;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.telecom.Call;
import android.util.Log;

public class CallActionReceiver extends BroadcastReceiver {
    private static final String TAG = "CallActionReceiver";

    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null || intent.getAction() == null) return;
        String action = intent.getAction();
        Log.d(TAG, "Received action: " + action);
        try {
            if (CallTrackingInCallService.ACTION_TOGGLE_SPEAKER.equals(action)) {
                boolean toSpeaker = intent.getBooleanExtra("toSpeaker", true);
                CallTrackingInCallService.setSpeaker(toSpeaker);
                // Update sticky notification label
                try {
                    String number = null;
                    int state = CallTrackingInCallService.getCurrentState();
                    if (state == Call.STATE_ACTIVE || state == Call.STATE_CONNECTING || state == Call.STATE_DIALING) {
                        CallTrackingInCallService.class.getDeclaredMethod("updateActiveCallNotification", String.class)
                                .setAccessible(true);
                        CallTrackingInCallService.class.getDeclaredMethod("updateActiveCallNotification", String.class)
                                .invoke(null, number);
                    }
                } catch (Throwable ignored) {}
            } else if (CallTrackingInCallService.ACTION_END_CALL.equals(action)) {
                CallTrackingInCallService.endCurrentCall();
            }
        } catch (Throwable t) {
            Log.e(TAG, "Error handling action", t);
        }
    }
}


