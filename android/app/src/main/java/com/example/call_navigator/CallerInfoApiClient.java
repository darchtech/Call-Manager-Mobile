package com.example.call_navigator;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.AsyncTask;
import android.util.Log;
import org.json.JSONException;
import org.json.JSONObject;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.concurrent.TimeUnit;

/**
 * API client service for retrieving caller information from server
 * Handles network requests with timeout and error handling
 */
public class CallerInfoApiClient {
    private static final String TAG = "CallerInfoApiClient";
    private static final String API_ENDPOINT = "/v1/caller-info/lookup";
    private static final int TIMEOUT_SECONDS = 7;
    private static final int CONNECT_TIMEOUT_MS = 5000;
    private static final int READ_TIMEOUT_MS = 7000;
    
    public interface CallerInfoCallback {
        void onSuccess(CallerInfo callerInfo);
        void onError(String error);
        void onTimeout();
    }
    
    public static class CallerInfo {
        public String name;
        public String campus;
        public String status;
        public String remark;
        public String phoneNumber;
        public boolean found;
        
        public CallerInfo(String name, String campus, String status, String remark, String phoneNumber, boolean found) {
            this.name = name;
            this.campus = campus;
            this.status = status;
            this.remark = remark;
            this.phoneNumber = phoneNumber;
            this.found = found;
        }
        
        public boolean hasInfo() {
            return found && (name != null || campus != null);
        }
        
        /**
         * Helper method to normalize status for comparison.
         * Handles variations like "un-assigned", "un_assigned", "un assigned", etc.
         */
        private String normalizeStatus(String status) {
            if (status == null) return "";
            return status.toLowerCase().trim().replaceAll("[-_\\s]", "");
        }
        
        public boolean isCompleted() {
            // A lead is considered completed if status is NOT "assigned", "assign", "new", "unassigned", "unassigne", or "unassign"
            // Handles variations: "un-assigned", "un_assigned", "un assigned", "UnAssigned", "un-assigne", "un-assign", etc.
            if (status == null) return false;
            String normalizedStatus = normalizeStatus(status);
            return !normalizedStatus.equals("assigned") && 
                   !normalizedStatus.equals("assign") &&
                   !normalizedStatus.equals("new") && 
                   !normalizedStatus.equals("unassigned") &&
                   !normalizedStatus.equals("unassigne") &&
                   !normalizedStatus.equals("unassign");
        }
        
        public boolean isAssigned() {
            return "assigned".equalsIgnoreCase(status);
        }
        
        public boolean isNew() {
            return "new".equalsIgnoreCase(status);
        }
        
        public boolean isUnassigned() {
            return "unassigned".equalsIgnoreCase(status);
        }
    }
    
    /**
     * Lookup caller information asynchronously
     * @param phoneNumber Phone number to lookup
     * @param baseUrl Base URL of the API server
     * @param callback Callback for results
     */
    public static void lookupCaller(String phoneNumber, String baseUrl, CallerInfoCallback callback) {
        new CallerLookupTask(phoneNumber, baseUrl, callback).execute();
    }
    
    private static class CallerLookupTask extends AsyncTask<Void, Void, CallerLookupResult> {
        private final String phoneNumber;
        private final String baseUrl;
        private final CallerInfoCallback callback;
        
        public CallerLookupTask(String phoneNumber, String baseUrl, CallerInfoCallback callback) {
            this.phoneNumber = phoneNumber;
            this.baseUrl = baseUrl;
            this.callback = callback;
        }
        
        @Override
        protected CallerLookupResult doInBackground(Void... voids) {
            try {
                Log.d(TAG, "Starting caller lookup for: " + phoneNumber);
                
                // Build API URL
                String apiUrl = baseUrl + API_ENDPOINT;
                URL url = new URL(apiUrl);
                
                // Create HTTP connection
                HttpURLConnection connection = (HttpURLConnection) url.openConnection();
                connection.setRequestMethod("POST");
                connection.setRequestProperty("Content-Type", "application/json");
                connection.setRequestProperty("Accept", "application/json");
                connection.setConnectTimeout(CONNECT_TIMEOUT_MS);
                connection.setReadTimeout(READ_TIMEOUT_MS);
                connection.setDoOutput(true);
                
                // Create request body
                JSONObject requestBody = new JSONObject();
                requestBody.put("phone_number", phoneNumber);
                
                // Send request
                try (OutputStream os = connection.getOutputStream()) {
                    byte[] input = requestBody.toString().getBytes("utf-8");
                    os.write(input, 0, input.length);
                }
                
                // Get response
                int responseCode = connection.getResponseCode();
                Log.d(TAG, "API Response Code: " + responseCode);
                
                String responseBody;
                if (responseCode >= 200 && responseCode < 300) {
                    responseBody = readResponse(connection.getInputStream());
                } else {
                    responseBody = readResponse(connection.getErrorStream());
                }
                
                Log.d(TAG, "API Response Body: " + responseBody);
                
                // Parse response
                JSONObject jsonResponse = new JSONObject(responseBody);
                int status = jsonResponse.getInt("status");
                
                if (status == 1) {
                    JSONObject data = jsonResponse.getJSONObject("data");
                    String name = data.optString("name", null);
                    String campus = data.optString("campus", null);
                    String callerStatus = data.optString("status", null);
                    String remark = data.optString("remark", null);
                    boolean found = data.getBoolean("found");
                    
                    CallerInfo callerInfo = new CallerInfo(name, campus, callerStatus, remark, phoneNumber, found);
                    return new CallerLookupResult(callerInfo, null);
                } else {
                    String error = jsonResponse.optString("error", "Unknown API error");
                    return new CallerLookupResult(null, error);
                }
                
            } catch (java.net.SocketTimeoutException e) {
                Log.e(TAG, "API request timeout", e);
                return new CallerLookupResult(null, "TIMEOUT");
            } catch (IOException e) {
                Log.e(TAG, "Network error during API call", e);
                return new CallerLookupResult(null, "Network error: " + e.getMessage());
            } catch (JSONException e) {
                Log.e(TAG, "JSON parsing error", e);
                return new CallerLookupResult(null, "Invalid response format");
            } catch (Exception e) {
                Log.e(TAG, "Unexpected error during API call", e);
                return new CallerLookupResult(null, "Unexpected error: " + e.getMessage());
            }
        }
        
        @Override
        protected void onPostExecute(CallerLookupResult result) {
            if (result.callerInfo != null) {
                callback.onSuccess(result.callerInfo);
            } else if ("TIMEOUT".equals(result.error)) {
                callback.onTimeout();
            } else {
                callback.onError(result.error);
            }
        }
        
        private String readResponse(java.io.InputStream inputStream) throws IOException {
            StringBuilder response = new StringBuilder();
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(inputStream))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    response.append(line);
                }
            }
            return response.toString();
        }
    }
    
    private static class CallerLookupResult {
        public final CallerInfo callerInfo;
        public final String error;
        
        public CallerLookupResult(CallerInfo callerInfo, String error) {
            this.callerInfo = callerInfo;
            this.error = error;
        }
    }
    
    /**
     * Get the base URL from app preferences or use default
     * @param context Application context
     * @return Base URL for API calls
     */
    public static String getBaseUrl(Context context) {
        SharedPreferences prefs = context.getSharedPreferences("app_config", Context.MODE_PRIVATE);
        String baseUrl = prefs.getString("base_url", "https://flyvendo.com/ct");
        // String baseUrl = prefs.getString("base_url", "http://192.168.2.165:8000");
        return baseUrl;
    }
    
    /**
     * Set the base URL in app preferences
     * @param context Application context
     * @param baseUrl Base URL to save
     */
    public static void setBaseUrl(Context context, String baseUrl) {
        SharedPreferences prefs = context.getSharedPreferences("app_config", Context.MODE_PRIVATE);
        SharedPreferences.Editor editor = prefs.edit();
        editor.putString("base_url", baseUrl);
        editor.apply();
    }
}
