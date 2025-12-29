package com.example.call_navigator;

import android.text.TextUtils;
import java.util.regex.Pattern;

/**
 * Utility class for phone number validation and selection
 */
public class PhoneNumberUtils {
    
    // Pattern to match valid phone numbers (basic validation)
    private static final Pattern PHONE_PATTERN = Pattern.compile("^[+]?[0-9\\s\\-\\(\\)]{7,}$");
    
    /**
     * Get the best available phone number from multiple sources
     * Priority: intentNumber > callServiceNumber > receiverNumber
     */
    public static String getBestAvailableNumber(String intentNumber, String callServiceNumber, String receiverNumber) {
        // Check intent number first (highest priority)
        if (isValidNumber(intentNumber)) {
            return intentNumber;
        }
        
        // Check call service number
        if (isValidNumber(callServiceNumber)) {
            return callServiceNumber;
        }
        
        // Check receiver number
        if (isValidNumber(receiverNumber)) {
            return receiverNumber;
        }
        
        // If all are invalid, return "Unknown"
        return "Unknown";
    }
    
    /**
     * Check if a phone number is valid and not empty
     */
    public static boolean isValidNumber(String number) {
        if (TextUtils.isEmpty(number)) {
            return false;
        }
        
        // Check if it's "Unknown"
        if ("Unknown".equalsIgnoreCase(number.trim())) {
            return false;
        }
        
        // Basic pattern matching for phone numbers
        return PHONE_PATTERN.matcher(number.trim()).matches();
    }
    
    /**
     * Clean and normalize a phone number
     */
    public static String cleanNumber(String number) {
        if (TextUtils.isEmpty(number)) {
            return "Unknown";
        }
        
        String cleaned = number.trim();
        if ("Unknown".equalsIgnoreCase(cleaned)) {
            return "Unknown";
        }
        
        // Remove common formatting characters but keep + for international numbers
        cleaned = cleaned.replaceAll("[\\s\\-\\(\\)]", "");
        
        return cleaned;
    }
}
