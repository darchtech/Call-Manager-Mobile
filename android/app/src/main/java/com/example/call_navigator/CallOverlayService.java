package com.example.call_navigator;

import android.app.Service;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.os.Build;
import android.os.IBinder;
import android.provider.Settings;
import android.telecom.TelecomManager;
import android.util.Log;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.content.Context;
import android.graphics.drawable.GradientDrawable;
import android.os.Handler;
import android.os.Looper;
import android.view.animation.AlphaAnimation;
import android.view.animation.Animation;
import android.widget.ProgressBar;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.ShapeDrawable;
import android.graphics.drawable.shapes.OvalShape;
import android.graphics.Paint;

/**
 * Enhanced overlay service with Truecaller-style UI and caller information lookup
 * Shows floating call window with server-side caller information
 */
public class CallOverlayService extends Service {
    private static final String TAG = "CallOverlayService";
    
    public static final String ACTION_SHOW_CALL = "SHOW_CALL";
    public static final String ACTION_HIDE_CALL = "HIDE_CALL";
    public static final String ACTION_UPDATE_DURATION = "UPDATE_DURATION";
    public static final String ACTION_SHOW_INCOMING_CALL = "SHOW_INCOMING_CALL";
    public static final String EXTRA_PHONE_NUMBER = "phone_number";
    public static final String EXTRA_CALL_DURATION = "call_duration";
    public static final String EXTRA_CALL_STATE = "call_state";
    public static final String EXTRA_CONTACT_NAME = "contact_name";
    public static final String EXTRA_IS_INCOMING = "is_incoming";
    
    private WindowManager windowManager;
    private View callOverlay;
    private TextView phoneNumberText;
    private TextView contactNameText;
    private TextView campusText;
    private TextView statusText;
    private TextView remarkText;
    private TextView durationText;
    private TextView fetchingText;
    private Button endCallButton;
    private Button muteButton;
    private Button speakerButton;
    private Button acceptButton;
    private Button rejectButton;
    private ProgressBar loadingSpinner;
    private LinearLayout callerInfoContainer;
    private LinearLayout callControlsContainer;
    
    private boolean isShowing = false;
    private boolean isIncomingCall = false;
    private String currentPhoneNumber = "";
    private String currentState = "";
    private Handler mainHandler;
    private Runnable timeoutRunnable;
    private Runnable autoDismissRunnable;
    private static final long AUTO_DISMISS_TIMEOUT = 30000; // 30 seconds
    private boolean isCallerInfoFetched = false;

    @Override
    public void onCreate() {
        super.onCreate();
        windowManager = (WindowManager) getSystemService(WINDOW_SERVICE);
        mainHandler = new Handler(Looper.getMainLooper());
        createCallOverlay();
        Log.d(TAG, "CallOverlayService created");
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent != null && intent.getAction() != null) {
            String action = intent.getAction();
            Log.d(TAG, "onStartCommand: " + action);
            
            switch (action) {
                case ACTION_SHOW_CALL:
                    String phoneNumber = intent.getStringExtra(EXTRA_PHONE_NUMBER);
                    String contactName = intent.getStringExtra(EXTRA_CONTACT_NAME);
                    String callState = intent.getStringExtra(EXTRA_CALL_STATE);
                    boolean isIncoming = intent.getBooleanExtra(EXTRA_IS_INCOMING, false);
                    showCallOverlay(phoneNumber, callState, contactName, isIncoming);
                    break;
                case ACTION_SHOW_INCOMING_CALL:
                    String incomingNumber = intent.getStringExtra(EXTRA_PHONE_NUMBER);
                    showIncomingCallOverlay(incomingNumber);
                    break;
                case ACTION_HIDE_CALL:
                    hideCallOverlay();
                    break;
                case ACTION_UPDATE_DURATION:
                    String duration = intent.getStringExtra(EXTRA_CALL_DURATION);
                    updateCallDuration(duration);
                    break;
            }
        }
        return START_STICKY;
    }

    private void createCallOverlay() {
        // Create the main overlay container
        callOverlay = new LinearLayout(this);
        LinearLayout mainLayout = (LinearLayout) callOverlay;
        mainLayout.setOrientation(LinearLayout.VERTICAL);
        mainLayout.setPadding(40, 40, 40, 40);
        
        // Set Truecaller-style background with gradient
        GradientDrawable background = new GradientDrawable();
        background.setColors(new int[]{
            Color.parseColor("#1A1A1A"),
            Color.parseColor("#2D2D2D")
        });
        background.setCornerRadius(25);
        background.setStroke(2, Color.parseColor("#404040"));
        mainLayout.setBackground(background);
        
        // Create close button container (top-right)
        LinearLayout closeButtonContainer = new LinearLayout(this);
        closeButtonContainer.setOrientation(LinearLayout.HORIZONTAL);
        closeButtonContainer.setGravity(Gravity.END);
        closeButtonContainer.setLayoutParams(new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ));
        
        // Create close button
        Button closeButton = new Button(this);
        closeButton.setText("×");
        closeButton.setTextSize(24);
        closeButton.setTextColor(Color.WHITE);
        closeButton.setBackgroundColor(Color.TRANSPARENT);
        closeButton.setPadding(20, 10, 20, 10);
        closeButton.setOnClickListener(v -> {
            Log.d(TAG, "Close button clicked - hiding overlay");
            cancelAutoDismiss();
            hideCallOverlay();
        });
        
        closeButtonContainer.addView(closeButton);
        mainLayout.addView(closeButtonContainer);
        
        // Create app branding header
        LinearLayout appHeaderContainer = new LinearLayout(this);
        appHeaderContainer.setOrientation(LinearLayout.HORIZONTAL);
        appHeaderContainer.setGravity(Gravity.CENTER);
        appHeaderContainer.setLayoutParams(new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ));
        
        // App name
        TextView appNameText = new TextView(this);
        appNameText.setText("Leads Management App");
        appNameText.setTextColor(Color.parseColor("#B0B0B0"));
        appNameText.setTextSize(12);
        appNameText.setGravity(Gravity.CENTER);
        appNameText.setTypeface(null, android.graphics.Typeface.BOLD);
        
        // Move icon
        TextView moveIcon = new TextView(this);
        moveIcon.setText("⋮⋮");
        moveIcon.setTextColor(Color.parseColor("#B0B0B0"));
        moveIcon.setTextSize(16);
        moveIcon.setGravity(Gravity.CENTER);
        moveIcon.setPadding(20, 0, 0, 0);
        
        appHeaderContainer.addView(appNameText);
        appHeaderContainer.addView(moveIcon);
        mainLayout.addView(appHeaderContainer);
        
        // Create caller info container
        callerInfoContainer = new LinearLayout(this);
        callerInfoContainer.setOrientation(LinearLayout.VERTICAL);
        callerInfoContainer.setGravity(Gravity.CENTER);
        
        // Contact name (primary)
        contactNameText = new TextView(this);
        contactNameText.setTextColor(Color.WHITE);
        contactNameText.setTextSize(26);
        contactNameText.setGravity(Gravity.CENTER);
        contactNameText.setTypeface(null, android.graphics.Typeface.BOLD);
        contactNameText.setText("");
        callerInfoContainer.addView(contactNameText);
        
        // Campus name (secondary)
        campusText = new TextView(this);
        campusText.setTextColor(Color.parseColor("#B0B0B0"));
        campusText.setTextSize(18);
        campusText.setGravity(Gravity.CENTER);
        campusText.setText("");
        callerInfoContainer.addView(campusText);

        // Phone number display
        phoneNumberText = new TextView(this);
        phoneNumberText.setTextColor(Color.parseColor("#808080"));
        phoneNumberText.setTextSize(20);
        phoneNumberText.setGravity(Gravity.CENTER);
        phoneNumberText.setText("Unknown");
        callerInfoContainer.addView(phoneNumberText);
        
        // Status display (verified/unverified/blocked)
        statusText = new TextView(this);
        statusText.setTextColor(Color.parseColor("#FFC107"));
        statusText.setTextSize(14);
        statusText.setGravity(Gravity.CENTER);
        statusText.setText("");
        statusText.setVisibility(View.GONE);
        callerInfoContainer.addView(statusText);
        
        // Remark display
        remarkText = new TextView(this);
        remarkText.setTextColor(Color.parseColor("#9E9E9E"));
        remarkText.setTextSize(14);
        remarkText.setGravity(Gravity.CENTER);
        remarkText.setText("");
        remarkText.setVisibility(View.GONE);
        callerInfoContainer.addView(remarkText);
        
        // Fetching status text
        fetchingText = new TextView(this);
        fetchingText.setTextColor(Color.parseColor("#4CAF50"));
        fetchingText.setTextSize(16);
        fetchingText.setGravity(Gravity.CENTER);
        fetchingText.setText("Fetching caller information...");
        fetchingText.setVisibility(View.GONE);
        callerInfoContainer.addView(fetchingText);
        
        // Loading spinner
        loadingSpinner = new ProgressBar(this);
        loadingSpinner.setIndeterminate(true);
        loadingSpinner.setVisibility(View.GONE);
        callerInfoContainer.addView(loadingSpinner);
        
        mainLayout.addView(callerInfoContainer);
        
        // Call status
        statusText = new TextView(this);
        statusText.setTextColor(Color.GREEN);
        statusText.setTextSize(14);
        statusText.setGravity(Gravity.CENTER);
        statusText.setText("Calling...");
        mainLayout.addView(statusText);
        
        // Duration display (for active calls)
        durationText = new TextView(this);
        durationText.setTextColor(Color.WHITE);
        durationText.setTextSize(16);
        durationText.setGravity(Gravity.CENTER);
        durationText.setText("00:00");
        durationText.setVisibility(View.GONE);
        mainLayout.addView(durationText);
        
        // Create call controls container
        callControlsContainer = new LinearLayout(this);
        callControlsContainer.setOrientation(LinearLayout.HORIZONTAL);
        callControlsContainer.setGravity(Gravity.CENTER);
        
        // Accept button (for incoming calls)
        acceptButton = createCallButton("Accept", Color.parseColor("#4CAF50"));
        acceptButton.setOnClickListener(v -> {
            try {
                cancelAutoDismiss();
                CallTrackingInCallService.answerCurrentCall(this);
                hideCallOverlay();
            } catch (Exception e) {
                Log.e(TAG, "Accept call failed", e);
            }
        });
        acceptButton.setVisibility(View.GONE);
        callControlsContainer.addView(acceptButton);
        
        // Reject button (for incoming calls)
        rejectButton = createCallButton("Reject", Color.parseColor("#F44336"));
        rejectButton.setOnClickListener(v -> {
            try {
                cancelAutoDismiss();
                CallTrackingInCallService.rejectCurrentCall(this);
                hideCallOverlay();
            } catch (Exception e) {
                Log.e(TAG, "Reject call failed", e);
            }
        });
        rejectButton.setVisibility(View.GONE);
        callControlsContainer.addView(rejectButton);
        
        // Mute button (for active calls)
        muteButton = createCallButton("Mute", Color.parseColor("#2196F3"));
        muteButton.setOnClickListener(v -> {
            try {
                CallTrackingInCallService.setMutedState(true);
            } catch (Exception e) {
                Log.e(TAG, "Mute failed", e);
            }
        });
        muteButton.setVisibility(View.GONE);
        callControlsContainer.addView(muteButton);
        
        // Speaker button (for active calls)
        speakerButton = createCallButton("Speaker", Color.parseColor("#FF9800"));
        speakerButton.setOnClickListener(v -> {
            try {
                CallTrackingInCallService.setSpeaker(true);
            } catch (Exception e) {
                Log.e(TAG, "Speaker failed", e);
            }
        });
        speakerButton.setVisibility(View.GONE);
        callControlsContainer.addView(speakerButton);
        
        // End call button (for active calls)
        endCallButton = createCallButton("End", Color.parseColor("#F44336"));
        endCallButton.setOnClickListener(v -> {
            try {
                CallTrackingInCallService.endCurrentCall();
                hideCallOverlay();
            } catch (Exception e) {
                Log.e(TAG, "End call failed", e);
                // Fallback - try to end via TelecomManager
                TelecomManager tm = (TelecomManager) getSystemService(Context.TELECOM_SERVICE);
                if (tm != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    tm.endCall();
                }
            }
        });
        endCallButton.setVisibility(View.GONE);
        callControlsContainer.addView(endCallButton);
        
        mainLayout.addView(callControlsContainer);
        
        // Make the overlay draggable
        makeOverlayDraggable();
    }
    
    // Avatar creation method removed - no longer using profile circles
    
    private Button createCallButton(String text, int color) {
        Button button = new Button(this);
        button.setText(text);
        button.setTextColor(Color.WHITE);
        button.setTextSize(12);
        
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(color);
        bg.setCornerRadius(15);
        button.setBackground(bg);
        
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
            120, 80);
        params.setMargins(5, 10, 5, 5);
        button.setLayoutParams(params);
        
        return button;
    }
    
    private void makeOverlayDraggable() {
        callOverlay.setOnTouchListener(new View.OnTouchListener() {
            private int initialX, initialY;
            private float initialTouchX, initialTouchY;

            @Override
            public boolean onTouch(View v, MotionEvent event) {
                switch (event.getAction()) {
                    case MotionEvent.ACTION_DOWN:
                        initialX = ((WindowManager.LayoutParams) callOverlay.getLayoutParams()).x;
                        initialY = ((WindowManager.LayoutParams) callOverlay.getLayoutParams()).y;
                        initialTouchX = event.getRawX();
                        initialTouchY = event.getRawY();
                        return true;
                    case MotionEvent.ACTION_MOVE:
                        WindowManager.LayoutParams params = (WindowManager.LayoutParams) callOverlay.getLayoutParams();
                        params.x = initialX + (int) (event.getRawX() - initialTouchX);
                        params.y = initialY + (int) (event.getRawY() - initialTouchY);
                        windowManager.updateViewLayout(callOverlay, params);
                        return true;
                }
                return false;
            }
        });
    }

    private void showCallOverlay(String phoneNumber, String callState, String contactName, boolean isIncoming) {
        if (!Settings.canDrawOverlays(this)) {
            Log.e(TAG, "Overlay permission not granted");
            return;
        }
        
        if (isShowing) {
            updateCallInfo(phoneNumber, callState, contactName, isIncoming);
            return;
        }

        try {
            WindowManager.LayoutParams params = new WindowManager.LayoutParams(
                (int) (getResources().getDisplayMetrics().widthPixels * 0.85), // 85% of screen width
                WindowManager.LayoutParams.WRAP_CONTENT,
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.O ?
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY :
                    WindowManager.LayoutParams.TYPE_PHONE,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE |
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT
            );
            
            params.gravity = Gravity.TOP | Gravity.CENTER_HORIZONTAL;
            params.x = 0; // Centered horizontally
            params.y = 100;
            
            windowManager.addView(callOverlay, params);
            isShowing = true;
            isIncomingCall = isIncoming;
            
            updateCallInfo(phoneNumber, callState, contactName, isIncoming);
            Log.d(TAG, "Call overlay shown for: " + phoneNumber);
            
        } catch (Exception e) {
            Log.e(TAG, "Failed to show overlay", e);
        }
    }
    
    private void showIncomingCallOverlay(String phoneNumber) {
        Log.d(TAG, "Showing incoming call overlay for: " + phoneNumber);
        
        // Show overlay immediately with phone number
        showCallOverlay(phoneNumber, "RINGING", null, true);
        
        // Start fetching caller information
        fetchCallerInformation(phoneNumber);
        
        // Set up auto-dismiss timeout
        setupAutoDismiss();
    }
    
    private void fetchCallerInformation(String phoneNumber) {
        Log.d(TAG, "Fetching caller information for: " + phoneNumber);
        
        // Show loading state
        showLoadingState();
        
        // Note: No need to set up timeout here as CallerInfoApiClient handles its own timeout
        
        // Make API call
        String baseUrl = CallerInfoApiClient.getBaseUrl(this);
        CallerInfoApiClient.lookupCaller(phoneNumber, baseUrl, new CallerInfoApiClient.CallerInfoCallback() {
            @Override
            public void onSuccess(CallerInfoApiClient.CallerInfo callerInfo) {
                mainHandler.post(() -> {
                    Log.d(TAG, "Caller info received: " + callerInfo.name + " - " + callerInfo.campus);
                    updateCallerInfo(callerInfo);
                    hideLoadingState();
                    isCallerInfoFetched = true;
                });
            }
            
            @Override
            public void onError(String error) {
                mainHandler.post(() -> {
                    Log.e(TAG, "Caller info error: " + error);
                    hideLoadingState();
                    showErrorState();
                });
            }
            
            @Override
            public void onTimeout() {
                mainHandler.post(() -> {
                    Log.w(TAG, "Caller info timeout");
                    hideLoadingState();
                    showTimeoutState();
                });
            }
        });
    }
    
    private void showLoadingState() {
        fetchingText.setVisibility(View.VISIBLE);
        loadingSpinner.setVisibility(View.VISIBLE);
        
        // Animate the fetching text
        AlphaAnimation animation = new AlphaAnimation(0.5f, 1.0f);
        animation.setDuration(1000);
        animation.setRepeatCount(Animation.INFINITE);
        animation.setRepeatMode(Animation.REVERSE);
        fetchingText.startAnimation(animation);
    }
    
    private void hideLoadingState() {
        fetchingText.setVisibility(View.GONE);
        loadingSpinner.setVisibility(View.GONE);
        fetchingText.clearAnimation();
    }
    
    private void updateCallerInfo(CallerInfoApiClient.CallerInfo callerInfo) {
        if (callerInfo.hasInfo()) {
            if (callerInfo.name != null && !callerInfo.name.isEmpty()) {
                contactNameText.setText(callerInfo.name);
                contactNameText.setVisibility(View.VISIBLE);
            }
            
            if (callerInfo.campus != null && !callerInfo.campus.isEmpty()) {
                campusText.setText(callerInfo.campus);
                campusText.setVisibility(View.VISIBLE);
            }
            
            // Update status display
            if (callerInfo.status != null && !callerInfo.status.isEmpty()) {
                statusText.setText(callerInfo.status.toUpperCase());
                statusText.setVisibility(View.VISIBLE);
                
                // Set status color based on lead status
                if (callerInfo.isCompleted()) {
                    statusText.setTextColor(Color.parseColor("#4CAF50")); // Green for completed
                } else if (callerInfo.isAssigned()) {
                    statusText.setTextColor(Color.parseColor("#2196F3")); // Blue for assigned
                } else if (callerInfo.isNew()) {
                    statusText.setTextColor(Color.parseColor("#FF9800")); // Orange for new
                } else if (callerInfo.isUnassigned()) {
                    statusText.setTextColor(Color.parseColor("#9E9E9E")); // Gray for unassigned
                } else {
                    statusText.setTextColor(Color.parseColor("#607D8B")); // Default color for other statuses
                }
            }
            
            // Update remark display
            if (callerInfo.remark != null && !callerInfo.remark.isEmpty()) {
                remarkText.setText(callerInfo.remark);
                remarkText.setVisibility(View.VISIBLE);
            }
            
            // Avatar removed - caller info displayed without profile circle
        } else {
            // No caller info found
            contactNameText.setText("Unknown Caller");
            contactNameText.setVisibility(View.VISIBLE);
            campusText.setVisibility(View.GONE);
            statusText.setVisibility(View.GONE);
            remarkText.setVisibility(View.GONE);
        }
    }
    
    // Avatar update method removed - no longer using profile circles
    
    private String getInitials(String name) {
        if (name == null || name.isEmpty()) return "?";
        
        String[] parts = name.trim().split("\\s+");
        if (parts.length == 1) {
            return parts[0].substring(0, 1).toUpperCase();
        } else {
            return (parts[0].substring(0, 1) + parts[parts.length - 1].substring(0, 1)).toUpperCase();
        }
    }
    
    private void setupTimeout() {
        timeoutRunnable = () -> {
            Log.w(TAG, "Caller info fetch timeout");
            hideLoadingState();
            showTimeoutState();
        };
        mainHandler.postDelayed(timeoutRunnable, 10000); // Increased to 10 seconds to allow API client timeout to handle it
    }
    
    private void cancelTimeout() {
        if (timeoutRunnable != null) {
            mainHandler.removeCallbacks(timeoutRunnable);
            timeoutRunnable = null;
        }
    }
    
    private void showErrorState() {
        fetchingText.setText("Unable to fetch caller information");
        fetchingText.setTextColor(Color.parseColor("#F44336"));
        fetchingText.setVisibility(View.VISIBLE);
    }
    
    private void showTimeoutState() {
        fetchingText.setText("Caller information unavailable");
        fetchingText.setTextColor(Color.parseColor("#FF9800"));
        fetchingText.setVisibility(View.VISIBLE);
    }
    
    private void updateCallInfo(String phoneNumber, String callState, String contactName, boolean isIncoming) {
        if (phoneNumber != null && !phoneNumber.isEmpty()) {
            currentPhoneNumber = phoneNumber;
            phoneNumberText.setText(phoneNumber);
        }
        
        // Only show contact name if it's not from API (to avoid conflicts)
        if (contactName != null && !contactName.isEmpty() && !isCallerInfoFetched) {
            contactNameText.setText(contactName);
            contactNameText.setVisibility(View.VISIBLE);
        }
        
        if (callState != null) {
            currentState = callState;
            isIncomingCall = isIncoming;
            
            // Update UI based on call state and type
            updateCallControls(callState, isIncoming);
            
            switch (callState) {
                case "DIALING":
                    statusText.setText("Calling...");
                    statusText.setTextColor(Color.parseColor("#FF9800"));
                    durationText.setVisibility(View.GONE);
                    break;
                case "CONNECTED":
                case "ACTIVE":
                    statusText.setText("Connected");
                    statusText.setTextColor(Color.parseColor("#4CAF50"));
                    durationText.setVisibility(View.VISIBLE);
                    break;
                case "RINGING":
                    statusText.setText("Incoming Call");
                    statusText.setTextColor(Color.parseColor("#2196F3"));
                    durationText.setVisibility(View.GONE);
                    break;
                default:
                    statusText.setText("In Call");
                    statusText.setTextColor(Color.WHITE);
                    durationText.setVisibility(View.VISIBLE);
                    break;
            }
        }
    }
    
    private void updateCallControls(String callState, boolean isIncoming) {
        // Hide all buttons first
        acceptButton.setVisibility(View.GONE);
        rejectButton.setVisibility(View.GONE);
        muteButton.setVisibility(View.GONE);
        speakerButton.setVisibility(View.GONE);
        endCallButton.setVisibility(View.GONE);
        
        if (isIncoming && "RINGING".equals(callState)) {
            // Incoming call - no buttons shown (removed accept/reject buttons)
            // Users can use the native call UI or system dialer
        } else if ("CONNECTED".equals(callState) || "ACTIVE".equals(callState)) {
            // Show call control buttons for active calls
            muteButton.setVisibility(View.VISIBLE);
            speakerButton.setVisibility(View.VISIBLE);
            endCallButton.setVisibility(View.VISIBLE);
        }
    }
    
    private void updateCallDuration(String duration) {
        if (isShowing && duration != null) {
            durationText.setText(duration);
        }
    }

    private void hideCallOverlay() {
        if (isShowing && callOverlay != null) {
            try {
                // Cancel any pending timeouts
                cancelTimeout();
                cancelAutoDismiss();
                
                // Clear animations
                fetchingText.clearAnimation();
                
                // Reset state
                isShowing = false;
                isIncomingCall = false;
                isCallerInfoFetched = false;
                
                // Hide loading states
                hideLoadingState();
                
                // Remove overlay
                windowManager.removeView(callOverlay);
                Log.d(TAG, "Call overlay hidden");
            } catch (Exception e) {
                Log.e(TAG, "Failed to hide overlay", e);
            }
        }
    }

    @Override
    public void onDestroy() {
        hideCallOverlay();
        Log.d(TAG, "CallOverlayService destroyed");
        super.onDestroy();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
    
    private void setupAutoDismiss() {
        autoDismissRunnable = () -> {
            Log.w(TAG, "Overlay auto-dismiss timeout - hiding overlay");
            hideCallOverlay();
        };
        mainHandler.postDelayed(autoDismissRunnable, AUTO_DISMISS_TIMEOUT);
        Log.d(TAG, "Auto-dismiss timeout set for " + (AUTO_DISMISS_TIMEOUT / 1000) + " seconds");
    }
    
    private void cancelAutoDismiss() {
        if (autoDismissRunnable != null) {
            mainHandler.removeCallbacks(autoDismissRunnable);
            autoDismissRunnable = null;
            Log.d(TAG, "Auto-dismiss timeout cancelled");
        }
    }
    
}
