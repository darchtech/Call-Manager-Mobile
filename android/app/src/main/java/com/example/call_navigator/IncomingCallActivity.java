package com.example.call_navigator;

import android.app.Activity;
import android.app.NotificationChannel;
import android.app.NotificationManager;
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
import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;
import com.example.call_navigator.PhoneNumberUtils;

/**
 * Enhanced full-screen incoming call UI that appears over the lock screen.
 * Provides Accept and Reject buttons with contact information.
 */
public class IncomingCallActivity extends Activity {
    private static final String TAG = "IncomingCallActivity";

    public static final String EXTRA_CALL_NUMBER = "extra_call_number";
    public static final String EXTRA_CONTACT_NAME = "extra_contact_name";
    public static final String EXTRA_CONTACT_PHOTO = "extra_contact_photo";
    
    // Auto-dismiss timeout
    private Handler timeoutHandler;
    private Runnable timeoutRunnable;
    private static final long INCOMING_CALL_TIMEOUT = 30000; // 30 seconds
    private static final String MISSED_CALL_CHANNEL_ID = "missed_call_channel";
    private static final int MISSED_CALL_NOTIFICATION_ID = 5001;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

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

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(Color.parseColor("#13151A"));
        root.setGravity(Gravity.CENTER_HORIZONTAL);
        int pad = (int) (24 * getResources().getDisplayMetrics().density);
        root.setPadding(pad, pad, pad, pad);

        // Get call information with improved fallback logic
        Intent intent = getIntent();
        String intentNumber = null;
        String contactName = null;
        
        // Step 1: Try to get from intent extras
        if (intent != null) {
            intentNumber = intent.getStringExtra(EXTRA_CALL_NUMBER);
            contactName = intent.getStringExtra(EXTRA_CONTACT_NAME);
        }
        
        // Step 2: Get from InCallService
        String callServiceNumber = null;
        try {
            callServiceNumber = CallTrackingInCallService.getCurrentCallNumber();
        } catch (Throwable ignored) {}
        
        // Step 3: Get from PhoneStateReceiver
        String receiverNumber = PhoneStateReceiver.getLastKnownNumber();
        
        // Step 4: Use utility to get best available number
        String number = PhoneNumberUtils.getBestAvailableNumber(intentNumber, callServiceNumber, receiverNumber);
        
        Log.d(TAG, "Final number for incoming call: " + number + 
                   " (from intent: " + intentNumber + 
                   ", callService: " + callServiceNumber + 
                   ", receiver: " + receiverNumber + ")");
        
        // Get contact name if we don't have it and number is not Unknown
        if ((contactName == null || contactName.isEmpty()) && !number.equals("Unknown")) {
            try {
                contactName = ContactUtils.getContactName(this, number);
                Log.d(TAG, "Contact lookup for " + number + " returned: " + contactName);
            } catch (Throwable e) {
                Log.e(TAG, "Contact lookup failed for " + number, e);
            }
        }
        
        // Top avatar circle
        View avatar = new View(this);
        GradientDrawable avatarBg = new GradientDrawable();
        avatarBg.setColor(Color.parseColor("#2A2F3A"));
        avatarBg.setCornerRadius(2000);
        avatar.setBackground(avatarBg);
        LinearLayout.LayoutParams avatarParams = new LinearLayout.LayoutParams(
            (int)(96 * getResources().getDisplayMetrics().density),
            (int)(96 * getResources().getDisplayMetrics().density)
        );
        avatarParams.setMargins(0, 0, 0, (int)(24 * getResources().getDisplayMetrics().density));
        root.addView(avatar, avatarParams);

        // Primary display text (contact name or number)
        TextView nameView = new TextView(this);
        String primaryText = (contactName != null && !contactName.isEmpty()) ? contactName : number;
        nameView.setText(primaryText);
        nameView.setTextColor(Color.WHITE);
        nameView.setTextSize(26);
        nameView.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams nameParams = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        );
        nameParams.setMargins(0, 0, 0, (int)(6 * getResources().getDisplayMetrics().density));
        root.addView(nameView, nameParams);

        // Secondary display text (show number if we have contact name, or "Incoming Call" if only number)
        TextView subView = new TextView(this);
        if (contactName != null && !contactName.isEmpty() && !number.equals("Unknown")) {
            // Show number below contact name
            subView.setText(number);
            subView.setTextColor(Color.parseColor("#9AA3B2"));
            subView.setTextSize(18);
            subView.setGravity(Gravity.CENTER);
        } else if (!number.equals("Unknown")) {
            // Show "Incoming Call" below number
            subView.setText("Incoming Call");
            subView.setTextColor(Color.parseColor("#9AA3B2"));
            subView.setTextSize(16);
            subView.setGravity(Gravity.CENTER);
        } else {
            // For unknown numbers, just show "Incoming Call"
            subView.setText("Incoming Call");
            subView.setTextColor(Color.parseColor("#9AA3B2"));
            subView.setTextSize(16);
            subView.setGravity(Gravity.CENTER);
        }
        
        LinearLayout.LayoutParams subParams = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        );
        subParams.setMargins(0, 0, 0, (int)(56 * getResources().getDisplayMetrics().density));
        root.addView(subView, subParams);

        // Button container
        LinearLayout buttons = new LinearLayout(this);
        buttons.setOrientation(LinearLayout.HORIZONTAL);
        buttons.setGravity(Gravity.CENTER);

        // Accept button (large circular)
        Button accept = createIncomingButton("Accept", Color.parseColor("#4CAF50"));
        final String finalNumber = number; // Make number final for lambda
        final String finalContactName = contactName; // Make contactName final for lambda
        accept.setOnClickListener(v -> {
            try {
                cancelTimeout();
                CallTrackingInCallService.answerCurrentCall(IncomingCallActivity.this);
                Log.d(TAG, "Call accepted for number: " + finalNumber);
                
                // Launch ActiveCallActivity
                Intent activeCallIntent = new Intent(this, ActiveCallActivity.class);
                activeCallIntent.putExtra(ActiveCallActivity.EXTRA_CALL_NUMBER, finalNumber);
                if (finalContactName != null && !finalContactName.isEmpty()) {
                    activeCallIntent.putExtra(ActiveCallActivity.EXTRA_CONTACT_NAME, finalContactName);
                }
                activeCallIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
                startActivity(activeCallIntent);
                
                finish();
            } catch (Exception e) {
                Log.e(TAG, "Failed to accept call", e);
                finish();
            }
        });

        // Reject button (large circular)
        Button reject = createIncomingButton("Reject", Color.parseColor("#F44336"));
        reject.setOnClickListener(v -> {
            try {
                cancelTimeout();
                CallTrackingInCallService.rejectCurrentCall(IncomingCallActivity.this);
                Log.d(TAG, "Call rejected for number: " + finalNumber);
                finish();
            } catch (Exception e) {
                Log.e(TAG, "Failed to reject call", e);
                finish();
            }
        });

        LinearLayout.LayoutParams btnParams = new LinearLayout.LayoutParams(0, (int)(72 * getResources().getDisplayMetrics().density), 1f);
        btnParams.setMargins((int)(16 * getResources().getDisplayMetrics().density), 0, (int)(16 * getResources().getDisplayMetrics().density), 0);

        buttons.addView(reject, btnParams);
        buttons.addView(accept, btnParams);

        LinearLayout.LayoutParams buttonContainerParams = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, 
            LinearLayout.LayoutParams.WRAP_CONTENT
        );
        buttonContainerParams.setMargins(0, 20, 0, 0);
        root.addView(buttons, buttonContainerParams);

        setContentView(root);
        
        // Set up auto-dismiss timeout
        setupTimeout();
        
        Log.d(TAG, "IncomingCallActivity created - Number: " + number + ", Contact: " + contactName + ", Primary: " + primaryText);
    }
    
    private Button createIncomingButton(String text, int color) {
        Button button = new Button(this);
        button.setText(text);
        button.setTextColor(Color.WHITE);
        button.setTextSize(18);
        
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(color);
        bg.setCornerRadius(2000);
        button.setBackground(bg);
        
        return button;
    }
    
    private void setupTimeout() {
        timeoutHandler = new Handler(Looper.getMainLooper());
        timeoutRunnable = () -> {
            Log.w(TAG, "Incoming call timeout - auto dismissing");
            showMissedCallNotification();
            finish();
        };
        timeoutHandler.postDelayed(timeoutRunnable, INCOMING_CALL_TIMEOUT);
        Log.d(TAG, "Auto-dismiss timeout set for " + (INCOMING_CALL_TIMEOUT / 1000) + " seconds");
    }
    
    private void cancelTimeout() {
        if (timeoutHandler != null && timeoutRunnable != null) {
            timeoutHandler.removeCallbacks(timeoutRunnable);
            timeoutRunnable = null;
            Log.d(TAG, "Auto-dismiss timeout cancelled");
        }
    }
    
    private void showMissedCallNotification() {
        try {
            createNotificationChannel();
            
            Intent intent = getIntent();
            String phoneNumber = intent != null ? intent.getStringExtra(EXTRA_CALL_NUMBER) : "Unknown";
            String contactName = intent != null ? intent.getStringExtra(EXTRA_CONTACT_NAME) : null;
            
            String displayName = (contactName != null && !contactName.isEmpty()) ? contactName : phoneNumber;
            
            NotificationCompat.Builder builder = new NotificationCompat.Builder(this, MISSED_CALL_CHANNEL_ID)
                    .setSmallIcon(android.R.drawable.ic_menu_call)
                    .setContentTitle("Missed Call")
                    .setContentText("Missed call from " + displayName)
                    .setPriority(NotificationCompat.PRIORITY_HIGH)
                    .setAutoCancel(true)
                    .setDefaults(NotificationCompat.DEFAULT_SOUND | NotificationCompat.DEFAULT_VIBRATE);
            
            NotificationManagerCompat notificationManager = NotificationManagerCompat.from(this);
            notificationManager.notify(MISSED_CALL_NOTIFICATION_ID, builder.build());
            
            Log.d(TAG, "Missed call notification shown for: " + displayName);
        } catch (Exception e) {
            Log.e(TAG, "Failed to show missed call notification", e);
        }
    }
    
    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                    MISSED_CALL_CHANNEL_ID,
                    "Missed Calls",
                    NotificationManager.IMPORTANCE_HIGH
            );
            channel.setDescription("Notifications for missed calls");
            channel.enableVibration(true);
            channel.setVibrationPattern(new long[]{0, 1000, 500, 1000});
            
            NotificationManager notificationManager = getSystemService(NotificationManager.class);
            if (notificationManager != null) {
                notificationManager.createNotificationChannel(channel);
            }
        }
    }
    
    @Override
    protected void onDestroy() {
        super.onDestroy();
        cancelTimeout();
    }
}