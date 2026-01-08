package com.example.call_navigator;

import android.app.Activity;
import android.content.Intent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.IntentFilter;
import android.telecom.Call;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.Gravity;
import android.view.View;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;
import com.example.call_navigator.CallManager;

/**
 * Native active call UI for ongoing calls when user is outside the app
 * Provides full call control functionality
 */
public class ActiveCallActivity extends Activity {
    private static final String TAG = "ActiveCallActivity";
    
    public static final String EXTRA_CALL_NUMBER = "extra_call_number";
    public static final String EXTRA_CONTACT_NAME = "extra_contact_name";
    public static final String EXTRA_CALL_DURATION = "extra_call_duration";
    private static final String EXTRA_CALL_STATE = "extra_call_state_internal";
    
    private TextView phoneNumberText;
    private TextView contactNameText;
    private TextView durationText;
    private Button endCallButton;
    private Button muteButton;
    private Button speakerButton;
    private Button holdButton;
    
    // Button rows for hiding during call waiting
    private LinearLayout firstButtonRow;
    private LinearLayout secondButtonRow;
    
    // Call waiting UI elements
    private LinearLayout callWaitingContainer;
    private TextView callWaitingText;
    private TextView callWaitingNameText; // For displaying caller name
    private LinearLayout waitingButtons; // Container for answer/decline buttons
    private Button answerWaitingButton;
    private Button declineWaitingButton;
    
    private Handler durationHandler;
    private Runnable durationRunnable;
    private Handler timeoutHandler;
    private Runnable timeoutRunnable;
    private long callStartTime = 0;
    private boolean isMuted = false;
    private boolean isSpeakerOn = false;
    private boolean isOnHold = false;
    private boolean isPostCallState = false;
    private boolean isCallTimerRunning = false;
    private String currentState = "DIALING";
    private static final long TIMEOUT_DURATION = 300000; // 5 minutes timeout
    private boolean isLeadFound = false;
    private Button editLeadButton;
    private final BroadcastReceiver disconnectReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            try {
                String action = intent.getAction();
                Log.d(TAG, "BroadcastReceiver received action: " + action);
                if (CallTrackingInCallService.ACTION_CALL_DISCONNECTED.equals(action)) {
                    // Before finishing, check if there's still an active call
                    // This prevents destroying the activity when waiting call is declined
                    boolean hasActiveCall = CallTrackingInCallService.hasActiveCall();
                    CallManager.CallState managerState = CallManager.getInstance().getCurrentState();
                    
                    if (hasActiveCall || 
                        managerState == CallManager.CallState.ACTIVE || 
                        managerState == CallManager.CallState.HOLD) {
                        // Active call still exists - don't finish the activity
                        Log.d(TAG, "Active call still exists (hasActive: " + hasActiveCall + 
                                   ", state: " + managerState + "), not finishing ActiveCallActivity");
                        // Ensure call waiting UI is hidden if the waiting call rang out
                        runOnUiThread(() -> {
                            try { hideCallWaiting(); } catch (Throwable ignored) {}
                        });
                        return;
                    }
                    
                    Log.d(TAG, "Received disconnect broadcast, finishing ActiveCallActivity");
                    // Use runOnUiThread to ensure UI thread safety
                    runOnUiThread(() -> {
                        try {
                            finish();
                        } catch (Exception e) {
                            Log.e(TAG, "Error finishing activity", e);
                        }
                    });
                }
            } catch (Throwable e) {
                Log.e(TAG, "Error in disconnect receiver", e);
            }
        }
    };
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        // Check for post-call mode
        boolean postCallMode = getIntent().getBooleanExtra("postCallMode", false);
        if (postCallMode) {
            isPostCallState = true;
        }
        
        // Configure for call screen behavior
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(true);
                setTurnScreenOn(true);
            } else {
                getWindow().addFlags(
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED |
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON |
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                );
            }
        } catch (Throwable ignored) {}
        
        createUI();
        updateCallInfo();
        
        // Check if lead exists in database
        checkLeadInDatabase();
        
        // Only start timers if not in post-call mode
        if (!isPostCallState) {
            // Call timer will start when call connects (ACTIVE state)
            // startDurationTimer(); // Removed - now starts on call connection
            startTimeoutTimer();
        }
        
        // Register for call state changes
        CallManager.getInstance().addListener(this::onCallStateChanged);
        try {
            IntentFilter f = new IntentFilter(CallTrackingInCallService.ACTION_CALL_DISCONNECTED);
            registerReceiver(disconnectReceiver, f);
        } catch (Throwable ignored) {}
        
        Log.d(TAG, "ActiveCallActivity created" + (isPostCallState ? " in post-call mode" : ""));
    }
    
    private void createUI() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(Color.parseColor("#13151A"));
        root.setGravity(Gravity.CENTER_HORIZONTAL);
        int padH = (int)(32 * getResources().getDisplayMetrics().density);
        int padV = (int)(48 * getResources().getDisplayMetrics().density);
        root.setPadding(padH, padV, padH, padV);
        
        // Contact name (if available)
        contactNameText = new TextView(this);
        contactNameText.setTextColor(Color.WHITE);
        contactNameText.setTextSize(26);
        contactNameText.setGravity(Gravity.CENTER);
        contactNameText.setText("");
        contactNameText.setVisibility(View.GONE);
        LinearLayout.LayoutParams nameParams = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, 
            LinearLayout.LayoutParams.WRAP_CONTENT
        );
        nameParams.setMargins(0, 0, 0, 10);
        root.addView(contactNameText, nameParams);
        
        // Phone number display
        phoneNumberText = new TextView(this);
        phoneNumberText.setTextColor(Color.parseColor("#9AA3B2"));
        phoneNumberText.setTextSize(18);
        phoneNumberText.setGravity(Gravity.CENTER);
        phoneNumberText.setText("Unknown");
        LinearLayout.LayoutParams numberParams = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, 
            LinearLayout.LayoutParams.WRAP_CONTENT
        );
        numberParams.setMargins(0, 0, 0, 30);
        root.addView(phoneNumberText, numberParams);
        
        // Duration display
        durationText = new TextView(this);
        durationText.setTextColor(Color.parseColor("#4CAF50"));
        durationText.setTextSize(16);
        durationText.setGravity(Gravity.CENTER);
        durationText.setText("00:00");
        LinearLayout.LayoutParams durationParams = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, 
            LinearLayout.LayoutParams.WRAP_CONTENT
        );
        durationParams.setMargins(0, 0, 0, 50);
        root.addView(durationText, durationParams);
        
        // First row of buttons
        firstButtonRow = new LinearLayout(this);
        firstButtonRow.setOrientation(LinearLayout.HORIZONTAL);
        firstButtonRow.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams firstRowParams = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, 
            LinearLayout.LayoutParams.WRAP_CONTENT
        );
        firstRowParams.setMargins(0, 20, 0, 20);
        
        // Mute button
        muteButton = createCallButton("Mute", Color.parseColor("#2E6CF6"));
        muteButton.setOnClickListener(v -> toggleMute());
        firstButtonRow.addView(muteButton);
        
        // Speaker button
        speakerButton = createCallButton("Speaker", Color.parseColor("#00BCD4"));
        speakerButton.setOnClickListener(v -> toggleSpeaker());
        firstButtonRow.addView(speakerButton);
        
        // Hold button
        holdButton = createCallButton("Hold", Color.parseColor("#FF9800"));
        holdButton.setOnClickListener(v -> toggleHold());
        firstButtonRow.addView(holdButton);
        
        root.addView(firstButtonRow, firstRowParams);
        
        // Second row of buttons
        secondButtonRow = new LinearLayout(this);
        secondButtonRow.setOrientation(LinearLayout.HORIZONTAL);
        secondButtonRow.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams secondRowParams = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, 
            LinearLayout.LayoutParams.WRAP_CONTENT
        );
        secondRowParams.setMargins(0, 0, 0, 30);
        
        
        // Edit Lead button (initially hidden, will be shown if lead is found)
        editLeadButton = createCallButton("Edit Lead", Color.parseColor("#8B5CF6"));
        editLeadButton.setOnClickListener(v -> editLead());
        editLeadButton.setVisibility(View.GONE); // Hide by default
        secondButtonRow.addView(editLeadButton);
        
        root.addView(secondButtonRow, secondRowParams);
        
        // End call button (full width)
        endCallButton = createCallButton("End Call", Color.parseColor("#EF4444"));
        LinearLayout.LayoutParams endCallParams = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, 
            (int)(56 * getResources().getDisplayMetrics().density)
        );
        endCallParams.setMargins(20, 20, 20, 0);
        endCallButton.setLayoutParams(endCallParams);
        endCallButton.setOnClickListener(v -> endCall());
        
        // Set button text based on post-call state
        if (isPostCallState) {
            endCallButton.setText("Close");
        }
        
        root.addView(endCallButton, endCallParams);
        
        // Create call waiting container (initially hidden)
        createCallWaitingUI(root);
        
        setContentView(root);
    }
    
    private void createCallWaitingUI(LinearLayout root) {
        // Call waiting container
        callWaitingContainer = new LinearLayout(this);
        callWaitingContainer.setOrientation(LinearLayout.VERTICAL);
        callWaitingContainer.setBackgroundColor(Color.parseColor("#2A2F3A"));
        callWaitingContainer.setPadding(
            (int)(16 * getResources().getDisplayMetrics().density),
            (int)(16 * getResources().getDisplayMetrics().density),
            (int)(16 * getResources().getDisplayMetrics().density),
            (int)(16 * getResources().getDisplayMetrics().density)
        );
        callWaitingContainer.setVisibility(View.GONE);
        
        // Call waiting text (phone number)
        callWaitingText = new TextView(this);
        callWaitingText.setTextColor(Color.WHITE);
        callWaitingText.setTextSize(16);
        callWaitingText.setGravity(Gravity.CENTER);
        callWaitingText.setText("Call Waiting");
        
        // Call waiting name text (initially hidden)
        callWaitingNameText = new TextView(this);
        callWaitingNameText.setTextColor(Color.parseColor("#9AA3B2"));
        callWaitingNameText.setTextSize(14);
        callWaitingNameText.setGravity(Gravity.CENTER);
        callWaitingNameText.setText("");
        callWaitingNameText.setVisibility(View.GONE);
        LinearLayout.LayoutParams nameParams = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        );
        nameParams.setMargins(0, (int)(4 * getResources().getDisplayMetrics().density), 0, 0);
        
        // Call waiting buttons (initially hidden)
        waitingButtons = new LinearLayout(this);
        waitingButtons.setOrientation(LinearLayout.HORIZONTAL);
        waitingButtons.setGravity(Gravity.CENTER);
        waitingButtons.setVisibility(View.GONE); // Hide buttons by default
        
        // Answer waiting call button
        answerWaitingButton = createCallButton("Answer", Color.parseColor("#4CAF50"));
        answerWaitingButton.setOnClickListener(v -> answerWaitingCall());
        
        // Decline waiting call button
        declineWaitingButton = createCallButton("Decline", Color.parseColor("#F44336"));
        declineWaitingButton.setOnClickListener(v -> declineWaitingCall());
        
        LinearLayout.LayoutParams waitingBtnParams = new LinearLayout.LayoutParams(
            0, (int)(48 * getResources().getDisplayMetrics().density), 1f
        );
        waitingBtnParams.setMargins(
            (int)(8 * getResources().getDisplayMetrics().density), 0,
            (int)(8 * getResources().getDisplayMetrics().density), 0
        );
        
        waitingButtons.addView(declineWaitingButton, waitingBtnParams);
        waitingButtons.addView(answerWaitingButton, waitingBtnParams);
        
        callWaitingContainer.addView(callWaitingText);
        callWaitingContainer.addView(callWaitingNameText, nameParams);
        callWaitingContainer.addView(waitingButtons);
        
        // Add to root layout
        LinearLayout.LayoutParams waitingParams = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        );
        waitingParams.setMargins(20, 20, 20, 0);
        root.addView(callWaitingContainer, waitingParams);
    }
    
    private Button createCallButton(String text, int color) {
        Button button = new Button(this);
        button.setText(text);
        button.setTextColor(Color.WHITE);
        button.setTextSize(14);
        
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(color);
        bg.setCornerRadius(22);
        button.setBackground(bg);
        
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
            0, (int)(56 * getResources().getDisplayMetrics().density), 1f
        );
        params.setMargins((int)(8 * getResources().getDisplayMetrics().density), 0, (int)(8 * getResources().getDisplayMetrics().density), 0);
        button.setLayoutParams(params);
        
        return button;
    }
    
    private void updateCallInfo() {
        Intent intent = getIntent();
        if (intent != null) {
            String phoneNumber = intent.getStringExtra(EXTRA_CALL_NUMBER);
            String contactName = intent.getStringExtra(EXTRA_CONTACT_NAME);
            String duration = intent.getStringExtra(EXTRA_CALL_DURATION);
            String passedState = intent.getStringExtra(EXTRA_CALL_STATE);
            if (passedState != null) currentState = passedState;
            
            if (phoneNumber != null && !phoneNumber.isEmpty()) {
                phoneNumberText.setText(phoneNumber);
            }
            
            if (contactName != null && !contactName.isEmpty()) {
                contactNameText.setText(contactName);
                contactNameText.setVisibility(View.VISIBLE);
                phoneNumberText.setTextSize(18); // Make number smaller when name is shown
            }
            
            if (duration != null && !duration.isEmpty()) {
                durationText.setText(duration);
            }

            // Reflect state in UI
            if ("DIALING".equals(currentState) || "CONNECTING".equals(currentState)) {
                durationText.setText("Calling...");
                durationText.setTextColor(Color.parseColor("#FF9800"));
            } else {
                durationText.setTextColor(Color.parseColor("#4CAF50"));
            }
        }
    }
    
    private void toggleMute() {
        try {
            isMuted = !isMuted;
            boolean success = CallTrackingInCallService.setMutedState(isMuted);
            if (success) {
                muteButton.setText(isMuted ? "Unmute" : "Mute");
                muteButton.setBackground(createButtonBackground(
                    isMuted ? Color.parseColor("#FF5722") : Color.parseColor("#2196F3")
                ));
            }
        } catch (Exception e) {
            Log.e(TAG, "Mute toggle failed", e);
        }
    }
    
    private void toggleSpeaker() {
        try {
            isSpeakerOn = !isSpeakerOn;
            boolean success = CallTrackingInCallService.setSpeaker(isSpeakerOn);
            if (success) {
                speakerButton.setText(isSpeakerOn ? "Earpiece" : "Speaker");
                speakerButton.setBackground(createButtonBackground(
                    isSpeakerOn ? Color.parseColor("#FF5722") : Color.parseColor("#00BCD4")
                ));
            }
        } catch (Exception e) {
            Log.e(TAG, "Speaker toggle failed", e);
        }
    }
    
    private void toggleHold() {
        try {
            isOnHold = !isOnHold;
            boolean success = isOnHold ? 
                CallTrackingInCallService.holdCurrentCall() : 
                CallTrackingInCallService.unholdCurrentCall();
            if (success) {
                holdButton.setText(isOnHold ? "Unhold" : "Hold");
                holdButton.setBackground(createButtonBackground(
                    isOnHold ? Color.parseColor("#FF5722") : Color.parseColor("#FF9800")
                ));
                
                if (isOnHold) {
                    stopDurationTimer();
                    durationText.setText("On Hold");
                    durationText.setTextColor(Color.parseColor("#FF9800"));
                } else {
                    startDurationTimer();
                    durationText.setTextColor(Color.parseColor("#4CAF50"));
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "Hold toggle failed", e);
        }
    }
    
    
    private void endCall() {
        if (isPostCallState) {
            // Just close UI — do NOT end call
            finish();
            return;
        }
        // Only end call if still active
        try {
            CallTrackingInCallService.endCurrentCall();
            finish();
        } catch (Exception e) {
            Log.e(TAG, "End call failed", e);
            finish();
        }
    }
    
    private GradientDrawable createButtonBackground(int color) {
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(color);
        bg.setCornerRadius(25);
        return bg;
    }
    
    private void startDurationTimer() {
        if (callStartTime == 0) {
            callStartTime = System.currentTimeMillis();
        }
        
        if (durationHandler != null && durationRunnable != null) {
            stopDurationTimer();
        }
        
        durationHandler = new Handler(Looper.getMainLooper());
        durationRunnable = new Runnable() {
            @Override
            public void run() {
                if (callStartTime > 0 && !isOnHold) {
                    long elapsed = System.currentTimeMillis() - callStartTime;
                    int seconds = (int) (elapsed / 1000);
                    int minutes = seconds / 60;
                    seconds = seconds % 60;
                    
                    String duration = String.format("%02d:%02d", minutes, seconds);
                    durationText.setText(duration);
                    
                    durationHandler.postDelayed(this, 1000);
                }
            }
        };
        durationHandler.post(durationRunnable);
    }
    
    private void stopDurationTimer() {
        if (durationHandler != null && durationRunnable != null) {
            durationHandler.removeCallbacks(durationRunnable);
        }
        isCallTimerRunning = false; // Reset flag for next call
    }
    
    private void startTimeoutTimer() {
        if (timeoutHandler != null && timeoutRunnable != null) {
            stopTimeoutTimer();
        }
        
        timeoutHandler = new Handler(Looper.getMainLooper());
        timeoutRunnable = new Runnable() {
            @Override
            public void run() {
                Log.d(TAG, "Activity timeout reached, finishing ActiveCallActivity");
                try {
                    finish();
                } catch (Exception e) {
                    Log.e(TAG, "Error finishing activity on timeout", e);
                }
            }
        };
        timeoutHandler.postDelayed(timeoutRunnable, TIMEOUT_DURATION);
    }
    
    private void stopTimeoutTimer() {
        if (timeoutHandler != null && timeoutRunnable != null) {
            timeoutHandler.removeCallbacks(timeoutRunnable);
        }
    }
    
    @Override
    protected void onDestroy() {
        stopDurationTimer();
        stopTimeoutTimer();
        Log.d(TAG, "ActiveCallActivity destroyed");
        try { 
            unregisterReceiver(disconnectReceiver); 
        } catch (Throwable ignored) {}
        try {
            CallManager.getInstance().removeListener(this::onCallStateChanged);
        } catch (Throwable ignored) {}
        super.onDestroy();
    }
    
    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        
        // Check if we should finish this activity
        if (intent.getBooleanExtra("finish", false)) {
            Log.d(TAG, "Received finish intent, closing ActiveCallActivity");
            finish();
            return;
        }
        
        // Check for post-call mode
        boolean postCallMode = intent.getBooleanExtra("postCallMode", false);
        if (postCallMode) {
            isPostCallState = true;
            runOnUiThread(() -> {
                if (endCallButton != null) {
                    endCallButton.setText("Close");
                    // Optional: change color to neutral
                }
            });
        }
        
        updateCallInfo();
    }
    
    @Override
    protected void onResume() {
        super.onResume();
        // Check if call is still active when activity resumes
        // Use robust detection to check for active calls
        boolean hasActiveCall = CallTrackingInCallService.hasActiveCall();
        CallManager.CallState managerState = CallManager.getInstance().getCurrentState();
        
        if (!hasActiveCall && 
            managerState != CallManager.CallState.ACTIVE && 
            managerState != CallManager.CallState.HOLD &&
            CallTrackingInCallService.getCurrentState() == Call.STATE_DISCONNECTED) {
            Log.d(TAG, "Call is disconnected, finishing activity");
            finish();
        }
    }
    
    @Override
    protected void onPause() {
        super.onPause();
        // Check call state when pausing
        // Use robust detection to check for active calls
        boolean hasActiveCall = CallTrackingInCallService.hasActiveCall();
        CallManager.CallState managerState = CallManager.getInstance().getCurrentState();
        
        if (!hasActiveCall && 
            managerState != CallManager.CallState.ACTIVE && 
            managerState != CallManager.CallState.HOLD &&
            CallTrackingInCallService.getCurrentState() == Call.STATE_DISCONNECTED) {
            Log.d(TAG, "Call is disconnected during pause, finishing activity");
            finish();
        }
    }
    
    @Override
    public void onBackPressed() {
        // Don't allow back button to close the call screen
        // User must use End Call button
    }
    
    // Call state change handler
    private void onCallStateChanged(CallManager.CallState state, String phoneNumber, String waitingNumber) {
        runOnUiThread(() -> {
            Log.d(TAG, "Call state changed: " + state + ", phone: " + phoneNumber + ", waiting: " + waitingNumber);
            
            switch (state) {
                case CALL_WAITING:
                    showCallWaiting(waitingNumber);
                    break;
                case ACTIVE:
                    hideCallWaiting();
                    // Start timer only when call actually connects
                    if (!isCallTimerRunning) {
                        startDurationTimer();
                        isCallTimerRunning = true;
                        Log.d(TAG, "Call timer started - call connected");
                    }
                    break;
                case IDLE:
                    // Before finishing, double-check if there's still an active call
                    // This prevents destroying activity when waiting call is declined
                    boolean hasActiveCall = CallTrackingInCallService.hasActiveCall();
                    if (!hasActiveCall) {
                        Log.d(TAG, "No active call, finishing activity");
                        finish();
                    } else {
                        Log.d(TAG, "Active call still exists despite IDLE state, not finishing");
                    }
                    break;
                default:
                    break;
            }
        });
    }
    
    private void showCallWaiting(String waitingNumber) {
        if (callWaitingContainer != null) {
            callWaitingText.setText("Call Waiting: " + waitingNumber);
            callWaitingContainer.setVisibility(View.VISIBLE);
            Log.d(TAG, "Showing call waiting for: " + waitingNumber);
            
            // Hide name initially
            if (callWaitingNameText != null) {
                callWaitingNameText.setVisibility(View.GONE);
                callWaitingNameText.setText("");
            }
            
            // Lookup caller info to get name
            lookupCallWaitingName(waitingNumber);
        }
        // Hide accept/reject buttons in call waiting section
        if (waitingButtons != null) {
            waitingButtons.setVisibility(View.GONE);
        }
        // Keep regular buttons (mute, speaker, hold, edit lead) visible
    }
    
    private void lookupCallWaitingName(String phoneNumber) {
        try {
            if (phoneNumber == null || phoneNumber.isEmpty()) {
                return;
            }
            
            // Get base URL from preferences
            String baseUrl = CallerInfoApiClient.getBaseUrl(this);
            
            Log.d(TAG, "Looking up caller name for waiting call: " + phoneNumber);
            
            // Lookup caller information
            CallerInfoApiClient.lookupCaller(phoneNumber, baseUrl, new CallerInfoApiClient.CallerInfoCallback() {
                @Override
                public void onSuccess(CallerInfoApiClient.CallerInfo callerInfo) {
                    runOnUiThread(() -> {
                        if (callWaitingNameText != null && callerInfo != null && callerInfo.name != null && !callerInfo.name.isEmpty()) {
                            callWaitingNameText.setText(callerInfo.name);
                            callWaitingNameText.setVisibility(View.VISIBLE);
                            Log.d(TAG, "Displaying caller name in call waiting: " + callerInfo.name);
                        }
                    });
                }
                
                @Override
                public void onError(String error) {
                    Log.d(TAG, "Could not get caller name for waiting call: " + error);
                    // Don't show name if lookup fails
                }
                
                @Override
                public void onTimeout() {
                    Log.d(TAG, "Timeout getting caller name for waiting call");
                    // Don't show name if timeout
                }
            });
        } catch (Exception e) {
            Log.e(TAG, "Failed to lookup caller name for waiting call", e);
        }
    }
    
    private void hideCallWaiting() {
        if (callWaitingContainer != null) {
            callWaitingContainer.setVisibility(View.GONE);
            Log.d(TAG, "Hiding call waiting");
        }
        // Hide name text
        if (callWaitingNameText != null) {
            callWaitingNameText.setVisibility(View.GONE);
            callWaitingNameText.setText("");
        }
        // Hide accept/reject buttons when call waiting is dismissed
        if (waitingButtons != null) {
            waitingButtons.setVisibility(View.GONE);
        }
    }
    
    private void answerWaitingCall() {
        try {
            CallManager.getInstance().answerWaitingCall();
            Log.d(TAG, "Answered waiting call");
        } catch (Exception e) {
            Log.e(TAG, "Failed to answer waiting call", e);
        }
    }
    
    private void declineWaitingCall() {
        try {
            CallManager.getInstance().declineWaitingCall();
            Log.d(TAG, "Declined waiting call");
        } catch (Exception e) {
            Log.e(TAG, "Failed to decline waiting call", e);
        }
    }
    
    private void checkLeadInDatabase() {
        try {
            String phoneNumber = getIntent().getStringExtra(EXTRA_CALL_NUMBER);
            if (phoneNumber == null || phoneNumber.isEmpty()) {
                Log.w(TAG, "No phone number available for lead lookup");
                updateEditLeadButtonVisibility(false);
                return;
            }
            
            // Get base URL from preferences
            String baseUrl = CallerInfoApiClient.getBaseUrl(this);
            
            Log.d(TAG, "Checking if lead exists in database for: " + phoneNumber);
            
            // Lookup caller information
            CallerInfoApiClient.lookupCaller(phoneNumber, baseUrl, new CallerInfoApiClient.CallerInfoCallback() {
                @Override
                public void onSuccess(CallerInfoApiClient.CallerInfo callerInfo) {
                    Log.d(TAG, "Lead lookup result - found: " + callerInfo.found);
                    runOnUiThread(() -> {
                        isLeadFound = callerInfo.found;
                        updateEditLeadButtonVisibility(callerInfo.found);
                    });
                }
                
                @Override
                public void onError(String error) {
                    Log.e(TAG, "Error checking lead in database: " + error);
                    runOnUiThread(() -> {
                        isLeadFound = false;
                        updateEditLeadButtonVisibility(false);
                    });
                }
                
                @Override
                public void onTimeout() {
                    Log.w(TAG, "Timeout checking lead in database");
                    runOnUiThread(() -> {
                        isLeadFound = false;
                        updateEditLeadButtonVisibility(false);
                    });
                }
            });
        } catch (Exception e) {
            Log.e(TAG, "Failed to check lead in database", e);
            updateEditLeadButtonVisibility(false);
        }
    }
    
    private void updateEditLeadButtonVisibility(boolean show) {
        if (editLeadButton != null) {
            editLeadButton.setVisibility(show ? View.VISIBLE : View.GONE);
            Log.d(TAG, "Edit Lead button visibility: " + (show ? "VISIBLE" : "GONE"));
        }
    }
    
    private void editLead() {
        try {
            // Get the current call number
            String phoneNumber = getIntent().getStringExtra(EXTRA_CALL_NUMBER);
            if (phoneNumber == null || phoneNumber.isEmpty()) {
                Log.w(TAG, "No phone number available for lead editing");
                return;
            }
            
            Log.d(TAG, "Opening lead details for: " + phoneNumber);
            
            // Launch MainActivity with navigation to lead detail screen
            // Note: No FLAG_ACTIVITY_NEW_TASK needed when launching from Activity
            // singleTask launch mode ensures only one instance exists
            Intent intent = new Intent(this, MainActivity.class);
            intent.setFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
            intent.putExtra("navigateRoute", "/leadDetail");
            intent.putExtra("phoneNumber", phoneNumber);
            intent.putExtra("editMode", true); // Enable edit mode
            startActivity(intent);
            
            Log.d(TAG, "Launched lead detail screen for editing: " + phoneNumber);
        } catch (Exception e) {
            Log.e(TAG, "Failed to open lead details", e);
        }
    }
}
