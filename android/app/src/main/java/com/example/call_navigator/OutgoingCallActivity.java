package com.example.call_navigator;

import android.app.Activity;
import android.content.Intent;
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

/**
 * Native outgoing call UI that appears when making calls outside the app
 * Shows call progress and provides end call functionality
 */
public class OutgoingCallActivity extends Activity {
    private static final String TAG = "OutgoingCallActivity";
    
    public static final String EXTRA_CALL_NUMBER = "extra_call_number";
    public static final String EXTRA_CALL_STATE = "extra_call_state";
    
    private TextView phoneNumberText;
    private TextView statusText;
    private TextView durationText;
    private Button endCallButton;
    private Button muteButton;
    private Button speakerButton;
    private Handler durationHandler;
    private Runnable durationRunnable;
    private long callStartTime = 0;
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
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
        
        Log.d(TAG, "OutgoingCallActivity created");
    }
    
    private void createUI() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(Color.parseColor("#1E1E1E"));
        root.setGravity(Gravity.CENTER);
        root.setPadding(40, 60, 40, 60);
        
        // Phone number display
        phoneNumberText = new TextView(this);
        phoneNumberText.setTextColor(Color.WHITE);
        phoneNumberText.setTextSize(24);
        phoneNumberText.setGravity(Gravity.CENTER);
        phoneNumberText.setText("Unknown");
        LinearLayout.LayoutParams numberParams = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, 
            LinearLayout.LayoutParams.WRAP_CONTENT
        );
        numberParams.setMargins(0, 0, 0, 20);
        root.addView(phoneNumberText, numberParams);
        
        // Call status
        statusText = new TextView(this);
        statusText.setTextColor(Color.parseColor("#4CAF50"));
        statusText.setTextSize(18);
        statusText.setGravity(Gravity.CENTER);
        statusText.setText("Calling...");
        LinearLayout.LayoutParams statusParams = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, 
            LinearLayout.LayoutParams.WRAP_CONTENT
        );
        statusParams.setMargins(0, 0, 0, 30);
        root.addView(statusText, statusParams);
        
        // Duration display
        durationText = new TextView(this);
        durationText.setTextColor(Color.WHITE);
        durationText.setTextSize(20);
        durationText.setGravity(Gravity.CENTER);
        durationText.setText("00:00");
        LinearLayout.LayoutParams durationParams = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, 
            LinearLayout.LayoutParams.WRAP_CONTENT
        );
        durationParams.setMargins(0, 0, 0, 50);
        root.addView(durationText, durationParams);
        
        // Button container
        LinearLayout buttonContainer = new LinearLayout(this);
        buttonContainer.setOrientation(LinearLayout.HORIZONTAL);
        buttonContainer.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams containerParams = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, 
            LinearLayout.LayoutParams.WRAP_CONTENT
        );
        containerParams.setMargins(0, 20, 0, 0);
        
        // Mute button
        muteButton = createCallButton("Mute", Color.parseColor("#2196F3"));
        muteButton.setOnClickListener(v -> {
            try {
                boolean success = CallTrackingInCallService.setMutedState(true);
                if (success) {
                    muteButton.setText("Unmute");
                    muteButton.setOnClickListener(vv -> {
                        CallTrackingInCallService.setMutedState(false);
                        muteButton.setText("Mute");
                        muteButton.setOnClickListener(this::muteButtonClick);
                    });
                }
            } catch (Exception e) {
                Log.e(TAG, "Mute failed", e);
            }
        });
        buttonContainer.addView(muteButton);
        
        // Speaker button
        speakerButton = createCallButton("Speaker", Color.parseColor("#00BCD4"));
        speakerButton.setOnClickListener(v -> {
            try {
                boolean success = CallTrackingInCallService.setSpeaker(true);
                if (success) {
                    speakerButton.setText("Earpiece");
                    speakerButton.setOnClickListener(vv -> {
                        CallTrackingInCallService.setSpeaker(false);
                        speakerButton.setText("Speaker");
                        speakerButton.setOnClickListener(this::speakerButtonClick);
                    });
                }
            } catch (Exception e) {
                Log.e(TAG, "Speaker failed", e);
            }
        });
        buttonContainer.addView(speakerButton);
        
        // End call button
        endCallButton = createCallButton("End Call", Color.parseColor("#F44336"));
        endCallButton.setOnClickListener(v -> {
            try {
                CallTrackingInCallService.endCurrentCall();
                finish();
            } catch (Exception e) {
                Log.e(TAG, "End call failed", e);
                finish();
            }
        });
        buttonContainer.addView(endCallButton);
        
        root.addView(buttonContainer, containerParams);
        setContentView(root);
    }
    
    private void muteButtonClick(View v) {
        // Original mute action - this method reference is used above
    }
    
    private void speakerButtonClick(View v) {
        // Original speaker action - this method reference is used above
    }
    
    private Button createCallButton(String text, int color) {
        Button button = new Button(this);
        button.setText(text);
        button.setTextColor(Color.WHITE);
        button.setTextSize(14);
        
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(color);
        bg.setCornerRadius(25);
        button.setBackground(bg);
        
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
            0, 140, 1f
        );
        params.setMargins(10, 0, 10, 0);
        button.setLayoutParams(params);
        
        return button;
    }
    
    private void updateCallInfo() {
        Intent intent = getIntent();
        if (intent != null) {
            String phoneNumber = intent.getStringExtra(EXTRA_CALL_NUMBER);
            String callState = intent.getStringExtra(EXTRA_CALL_STATE);
            
            if (phoneNumber != null && !phoneNumber.isEmpty()) {
                phoneNumberText.setText(phoneNumber);
            }
            
            if (callState != null) {
                updateCallState(callState);
            }
        }
    }
    
    public void updateCallState(String state) {
        if (state == null) return;
        
        switch (state) {
            case "DIALING":
            case "CONNECTING":
                statusText.setText("Calling...");
                statusText.setTextColor(Color.parseColor("#FF9800"));
                break;
            case "RINGING":
                statusText.setText("Ringing...");
                statusText.setTextColor(Color.parseColor("#2196F3"));
                break;
            case "CONNECTED":
            case "ACTIVE":
                statusText.setText("Connected");
                statusText.setTextColor(Color.parseColor("#4CAF50"));
                startDurationTimer();
                break;
            case "DISCONNECTED":
            case "ENDED":
                statusText.setText("Call Ended");
                statusText.setTextColor(Color.parseColor("#F44336"));
                stopDurationTimer();
                // Auto close after 2 seconds
                new Handler(Looper.getMainLooper()).postDelayed(this::finish, 2000);
                break;
            default:
                statusText.setText("In Call");
                statusText.setTextColor(Color.WHITE);
                break;
        }
        
        Log.d(TAG, "Call state updated: " + state);
    }
    
    private void startDurationTimer() {
        if (callStartTime == 0) {
            callStartTime = System.currentTimeMillis();
        }
        
        durationHandler = new Handler(Looper.getMainLooper());
        durationRunnable = new Runnable() {
            @Override
            public void run() {
                if (callStartTime > 0) {
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
    }
    
    @Override
    protected void onDestroy() {
        stopDurationTimer();
        Log.d(TAG, "OutgoingCallActivity destroyed");
        super.onDestroy();
    }
    
    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        updateCallInfo();
    }
}
