package com.example.call_navigator;

import android.os.Build;
import android.telecom.Connection;
import android.telecom.ConnectionRequest;
import android.telecom.ConnectionService;
import android.telecom.PhoneAccountHandle;
import android.telecom.StatusHints;
import android.graphics.drawable.Icon;
import android.content.Context;

import androidx.annotation.Nullable;
import androidx.annotation.RequiresApi;

/**
 * Minimal ConnectionService to improve ROLE_DIALER eligibility.
 * Not used for custom calls yet; returns null to defer to system.
 */
@RequiresApi(api = Build.VERSION_CODES.M)
public class MyConnectionService extends ConnectionService {

    @Nullable
    @Override
    public Connection onCreateIncomingConnection(PhoneAccountHandle connectionManagerPhoneAccount, ConnectionRequest request) {
        return null; // not handling incoming ourselves
    }

    @Nullable
    @Override
    public Connection onCreateOutgoingConnection(PhoneAccountHandle connectionManagerPhoneAccount, ConnectionRequest request) {
        return null; // not handling outgoing ourselves
    }
}


