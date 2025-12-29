package com.example.call_navigator;

import android.telecom.Call;
import android.util.Log;
import java.util.ArrayList;
import java.util.List;

/**
 * Centralized call state management to prevent activity stacking issues.
 * Manages all call states and notifies UI components appropriately.
 */
public class CallManager {
    private static final String TAG = "CallManager";
    private static CallManager instance;
    
    public enum CallState {
        IDLE,
        INCOMING,
        ACTIVE,
        HOLD,
        CALL_WAITING
    }
    
    private CallState currentState = CallState.IDLE;
    private Call currentCall;
    private Call waitingCall;
    private String currentCallNumber;
    private String waitingCallNumber;
    private List<CallStateListener> listeners = new ArrayList<>();
    
    private CallManager() {}
    
    public static synchronized CallManager getInstance() {
        if (instance == null) {
            instance = new CallManager();
        }
        return instance;
    }
    
    public interface CallStateListener {
        void onCallStateChanged(CallState state, String phoneNumber, String waitingNumber);
    }
    
    public void addListener(CallStateListener listener) {
        if (!listeners.contains(listener)) {
            listeners.add(listener);
        }
    }
    
    public void removeListener(CallStateListener listener) {
        listeners.remove(listener);
    }
    
    private void notifyListeners() {
        for (CallStateListener listener : listeners) {
            try {
                listener.onCallStateChanged(currentState, currentCallNumber, waitingCallNumber);
            } catch (Exception e) {
                Log.e(TAG, "Error notifying listener", e);
            }
        }
    }
    
    public void onIncomingCall(Call call, String phoneNumber) {
        Log.d(TAG, "onIncomingCall: " + phoneNumber + ", currentState: " + currentState);
        
        if (currentState == CallState.ACTIVE) {
            // Call waiting scenario - don't launch new activity
            waitingCall = call;
            waitingCallNumber = phoneNumber;
            currentState = CallState.CALL_WAITING;
            Log.d(TAG, "Call waiting: " + phoneNumber + " while on active call: " + currentCallNumber);
        } else {
            // Regular incoming call
            currentCall = call;
            currentCallNumber = phoneNumber;
            currentState = CallState.INCOMING;
            Log.d(TAG, "Regular incoming call: " + phoneNumber);
        }
        notifyListeners();
    }
    
    public void onCallAnswered() {
        Log.d(TAG, "onCallAnswered, currentState: " + currentState);
        currentState = CallState.ACTIVE;
        notifyListeners();
    }
    
    public void onCallEnded() {
        Log.d(TAG, "onCallEnded, currentState: " + currentState);
        
        if (waitingCall != null) {
            // Switch to waiting call
            currentCall = waitingCall;
            currentCallNumber = waitingCallNumber;
            waitingCall = null;
            waitingCallNumber = null;
            currentState = CallState.ACTIVE;
            Log.d(TAG, "Switched to waiting call: " + currentCallNumber);
        } else {
            // No waiting call, go to idle
            currentCall = null;
            currentCallNumber = null;
            currentState = CallState.IDLE;
            Log.d(TAG, "No waiting call, going to IDLE");
        }
        notifyListeners();
    }
    
    public void onCallHold() {
        if (currentState == CallState.ACTIVE) {
            currentState = CallState.HOLD;
            notifyListeners();
        }
    }
    
    public void onCallUnhold() {
        if (currentState == CallState.HOLD) {
            currentState = CallState.ACTIVE;
            notifyListeners();
        }
    }
    
    public void answerWaitingCall() {
        if (currentState == CallState.CALL_WAITING && waitingCall != null) {
            // Hold current call and answer waiting call
            try {
                if (currentCall != null) {
                    currentCall.hold();
                }
                waitingCall.answer(android.telecom.VideoProfile.STATE_AUDIO_ONLY);
                
                // Switch to waiting call
                currentCall = waitingCall;
                currentCallNumber = waitingCallNumber;
                waitingCall = null;
                waitingCallNumber = null;
                currentState = CallState.ACTIVE;
                
                Log.d(TAG, "Answered waiting call: " + currentCallNumber);
                notifyListeners();
            } catch (Exception e) {
                Log.e(TAG, "Failed to answer waiting call", e);
            }
        }
    }
    
    public void declineWaitingCall() {
        if (currentState == CallState.CALL_WAITING && waitingCall != null) {
            try {
                waitingCall.disconnect();
                waitingCall = null;
                waitingCallNumber = null;
                currentState = CallState.ACTIVE;
                
                Log.d(TAG, "Declined waiting call, back to active call");
                notifyListeners();
            } catch (Exception e) {
                Log.e(TAG, "Failed to decline waiting call", e);
            }
        }
    }
    
    // Getters
    public CallState getCurrentState() {
        return currentState;
    }
    
    public Call getCurrentCall() {
        return currentCall;
    }
    
    public Call getWaitingCall() {
        return waitingCall;
    }
    
    public String getCurrentCallNumber() {
        return currentCallNumber;
    }
    
    public String getWaitingCallNumber() {
        return waitingCallNumber;
    }
    
    public boolean isCallWaiting() {
        return currentState == CallState.CALL_WAITING;
    }
    
    public boolean hasActiveCall() {
        return currentState == CallState.ACTIVE || currentState == CallState.HOLD;
    }
    
    public boolean hasIncomingCall() {
        return currentState == CallState.INCOMING;
    }
}
