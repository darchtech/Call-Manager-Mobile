package com.example.call_navigator;

import android.content.Context;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.net.Uri;
import android.provider.ContactsContract;

public final class ContactUtils {
    private ContactUtils() {}

    public static String getContactName(Context context, String phoneNumber) {
        if (phoneNumber == null || phoneNumber.isEmpty()) return null;
        try {
            if (context.checkSelfPermission(android.Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) {
                return null;
            }
        } catch (Throwable ignored) {}

        Cursor cursor = null;
        try {
            Uri uri = Uri.withAppendedPath(ContactsContract.PhoneLookup.CONTENT_FILTER_URI, Uri.encode(phoneNumber));
            String[] projection = new String[] { ContactsContract.PhoneLookup.DISPLAY_NAME };
            cursor = context.getContentResolver().query(uri, projection, null, null, null);
            if (cursor != null && cursor.moveToFirst()) {
                int idx = cursor.getColumnIndex(ContactsContract.PhoneLookup.DISPLAY_NAME);
                if (idx >= 0) {
                    String name = cursor.getString(idx);
                    if (name != null && !name.trim().isEmpty()) return name;
                }
            }
        } catch (Throwable ignored) {
        } finally {
            if (cursor != null) try { cursor.close(); } catch (Throwable ignored) {}
        }
        return null;
    }
}


