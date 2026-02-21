[4 tools called]

# 🚀 **Complete Firebase Setup Guide for Call Tracker**

Based on your project structure, here's the complete setup process for Firebase services:

## 📱 **1. MOBILE APP (Flutter) - Firebase Setup**

### **Current Status**: Partially configured
- ✅ Firebase dependencies installed
- ✅ FCM service implemented
- ❌ Missing SHA certificates
- ❌ google-services.json may need updates

### **Step 1: Add SHA Certificates to Firebase Console**

**Your Android app package**: `com.example.call_navigator`

1. **Get SHA-1 fingerprint**:
```bash
# For debug (development)
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# For release (production) - you'll need your keystore
keytool -list -v -keystore path/to/your/keystore.jks -alias your_key_alias
```

2. **Add to Firebase Console**:
   - Go to [Firebase Console](https://console.firebase.google.com)
   - Select project: `call-navigator`
   - Project Settings → General → Your apps → Android app
   - Click "Add fingerprint" and paste SHA-1 and SHA-256

### **Step 2: Current google-services.json** (Update if needed):

```json
{
  "project_info": {
    "project_number": "1028777851075",
    "project_id": "call-navigator",
    "storage_bucket": "call-navigator.firebasestorage.app"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "1:102877725:android:b074681486d2bd6",
        "android_client_info": {
          "package_name": "com.example.call_navigator"
        }
      },
      "oauth_client": [],
      "api_key": [
        {
          "current_key": "AIzaSyDdHLm_t2RXQEdfsd8h-HcdIJdfseS5v_g"
        }
      ],
      "services": {
        "appinvite_service": {
          "other_platform_oauth_client": []
        }
      }
    }
  ],
  "configuration_version": "1"
}
```

### **Step 3: Android App Configuration**

**File**: `android/app/build.gradle`

```gradle
plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")  // Already added
}

android {
    namespace = "com.example.call_navigator"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.example.call_navigator"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Add this for FCM
        multiDexEnabled true
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'
    // Firebase BOM
    implementation platform('com.google.firebase:firebase-bom:33.1.0')
    implementation 'com.google.firebase:firebase-messaging'
    implementation 'com.google.firebase:firebase-analytics'
}
```

### **Step 4: iOS Configuration** (if needed)

**File**: `ios/Runner/GoogleService-Info.plist`
- Download from Firebase Console and place in `ios/Runner/`

## 🔧 **2. BACKEND SERVER - Firebase Admin Setup**

### **Current Status**: Configured but needs environment variables

### **Step 1: Create Service Account Key**

1. **Firebase Console** → Project Settings → Service accounts
2. Click **"Generate new private key"**
3. Download JSON file (keep secure!)

### **Step 2: Extract Environment Variables**

From the downloaded service account JSON:

```bash
# Backend .env file
FIREBASE_PROJECT_ID="call-navigator"
FIREBASE_PRIVATE_KEY_ID="your-private-key-id-here"
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYOUR_PRIVATE_KEY_HERE\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL="firebase-adminsdk-xxxxx@call-navigator.iam.gserviceaccount.com"
FIREBASE_CLIENT_ID="your-client-id-here"
```

### **Step 3: Complete Backend Environment Variables**

**File**: `call_tracker_backend/.env`

```bash
# Database
NODE_ENV=development
PORT=8000
MONGODB_URL=mongodb://localhost:27017/call_tracker

# JWT
JWT_SECRET=your-super-secret-jwt-key-here
JWT_ACCESS_EXPIRATION_MINUTES=30
JWT_REFRESH_EXPIRATION_DAYS=30

# Firebase Admin SDK (Server-side)
FIREBASE_PROJECT_ID="call-navigator"
FIREBASE_PRIVATE_KEY_ID="your-private-key-id-from-json"
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYOUR_FULL_PRIVATE_KEY\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL="firebase-adminsdk-xxxxx@call-navigator.iam.gserviceaccount.com"
FIREBASE_CLIENT_ID="your-client-id-from-json"

# Redis (for background jobs)
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=""
REDIS_DB=0

# AWS S3 (optional)
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=""
AWS_SECRET_ACCESS_KEY=""
AWS_S3_BUCKET=""

# Email (optional)
SMTP_HOST=""
SMTP_PORT=""
SMTP_USERNAME=""
SMTP_PASSWORD=""
EMAIL_FROM=""

# N8N Webhook (optional)
N8N_WEBHOOK_URL=""
```

## 🎯 **3. COMPLETE SETUP CHECKLIST**

### **Mobile App Setup**
- [ ] Add SHA-1/SHA-256 to Firebase Console
- [ ] Verify google-services.json is in `android/app/`
- [ ] Test FCM permissions in app
- [ ] Verify FCM token generation

### **Backend Setup**
- [ ] Create Firebase service account key
- [ ] Set all Firebase environment variables
- [ ] Test Firebase Admin initialization
- [ ] Verify FCM notification sending

### **Firebase Console Configuration**
- [ ] Enable Firebase Cloud Messaging
- [ ] Configure Android app with correct package name
- [ ] Add SHA certificates for both debug and release
- [ ] Verify API keys are correct

## 🧪 **4. TESTING SETUP**

### **Test Mobile App Firebase**
```dart
// Add to your main.dart or test file
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Test initialization
void testFirebase() async {
  await Firebase.initializeApp();
  final token = await FirebaseMessaging.instance.getToken();
  print('FCM Token: $token');
}
```

### **Test Backend Firebase**
```javascript
// Add to your backend test file
import { sendFCMNotification } from './src/services/fcm.service.js';

async function testFCM() {
  const result = await sendFCMNotification('test-user-id', {
    title: 'Test Notification',
    body: 'Firebase is working!',
    data: { test: 'true' }
  });
  console.log('FCM Test Result:', result);
}
```

## 🚨 **CRITICAL: SHA Certificates Required**

**Without SHA certificates:**
- ❌ FCM won't work in production
- ❌ Push notifications will fail
- ❌ Google Play Store publishing blocked

**How to get SHA-1:**
```bash
# Debug keystore (for development)
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# Release keystore (for production)
keytool -list -v -keystore path/to/keystore.jks -alias your_alias
```

## 📋 **Environment Variables Summary**

### **Backend (.env)**
```bash
FIREBASE_PROJECT_ID="call-navigator"
FIREBASE_PRIVATE_KEY_ID="..."
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL="firebase-adminsdk-xxxxx@call-navigator.iam.gserviceaccount.com"
FIREBASE_CLIENT_ID="..."
```

### **Mobile App**
- google-services.json in `android/app/`
- SHA certificates in Firebase Console
- Package name: `com.example.call_navigator`

## 🎉 **Final Steps**

1. **Set up SHA certificates** in Firebase Console
2. **Configure environment variables** in backend
3. **Test Firebase initialization** on both mobile and server
4. **Verify push notifications** work end-to-end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
# call_navigator

A new Flutter project.

## Getting Started

## After modifications

PS E:\WebStormProjects\call_tracker> flutter clean
>> flutter pub get
>> flutter packages pub run build_runner build --delete-conflicting-outputs 

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
