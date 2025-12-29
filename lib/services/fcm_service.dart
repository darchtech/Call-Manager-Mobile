import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
// removed unused imports
import 'api_service.dart';
import 'auth_service.dart';

/// FCM Service for handling push notifications and follow-up reminders
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  static FCMService get instance => _instance;

  FirebaseMessaging? _messaging;
  FlutterLocalNotificationsPlugin? _localNotifications;
  String? _fcmToken;
  StreamSubscription<String>? _tokenStream;
  bool _initialized = false;

  /// Initialize FCM service
  Future<void> initialize() async {
    try {
      // Initialize Firebase
      await Firebase.initializeApp();

      // Initialize FCM
      _messaging = FirebaseMessaging.instance;

      // Initialize local notifications
      await _initializeLocalNotifications();
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('UTC'));

      // Request permission
      await _requestPermission();

      // Get FCM token
      await _getFCMToken();

      // Setup message handlers
      _setupMessageHandlers();

      // Listen for token changes
      _listenForTokenChanges();

      print('[FCMService] Initialized successfully');
      _initialized = true;
    } catch (e) {
      print('[FCMService] Error initializing: $e');
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    _localNotifications = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _localNotifications!.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Request notification permission
  Future<void> _requestPermission() async {
    if (Platform.isIOS) {
      await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    }
  }

  /// Get FCM token
  Future<void> _getFCMToken() async {
    try {
      _fcmToken = await _messaging!.getToken();
      if (_fcmToken != null) {
        await _saveFCMToken(_fcmToken!);
        print('[FCMService] FCM Token: $_fcmToken');
        // Send token to server only if authenticated; otherwise will be sent post-auth
        await sendTokenToServer();
      }
    } catch (e) {
      print('[FCMService] Error getting FCM token: $e');
    }
  }

  /// Save FCM token locally
  Future<void> _saveFCMToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
  }

  /// Send FCM token to server
  Future<void> _sendTokenToServer(String token) async {
    try {
      // Require authentication before sending token
      if (Get.isRegistered<AuthService>() &&
          AuthService.instance.isAuthenticated) {
        await ApiService.instance.saveFcmToken(token);
        print('[FCMService] Token sent to server: $token');
      } else {
        print('[FCMService] Skipping token send (not authenticated yet)');
      }
    } catch (e) {
      print('[FCMService] Error sending token to server: $e');
    }
  }

  /// Public method to send current token to server if authenticated
  Future<void> sendTokenToServer() async {
    if (_fcmToken == null) {
      // If not initialized yet, initialize and fetch token
      if (!_initialized) {
        await initialize();
      }
      if (_fcmToken == null) return;
    }
    await _sendTokenToServer(_fcmToken!);
  }

  /// Listen for token changes
  void _listenForTokenChanges() {
    _tokenStream = _messaging!.onTokenRefresh.listen((newToken) async {
      _fcmToken = newToken;
      await _saveFCMToken(newToken);
      await sendTokenToServer();
      print('[FCMService] Token refreshed: $newToken');
    });
  }

  /// Setup message handlers
  void _setupMessageHandlers() {
    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  /// Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('[FCMService] Received foreground message: ${message.messageId}');

    // Show local notification for foreground messages
    await _showLocalNotification(message);
  }

  /// Handle notification taps
  Future<void> _handleNotificationTap(RemoteMessage message) async {
    print('[FCMService] Notification tapped: ${message.messageId}');
    await _processNotificationData(message.data);
  }

  /// Handle local notification taps
  void _onNotificationTapped(NotificationResponse response) {
    print('[FCMService] Local notification tapped: ${response.payload}');
    // Process notification payload
    if (response.payload != null) {
      _processNotificationPayload(response.payload!);
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'follow_up_reminders',
          'Follow-up Reminders',
          channelDescription: 'Notifications for follow-up reminders',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications!.show(
      message.hashCode,
      message.notification?.title ?? 'Follow-up Reminder',
      message.notification?.body ?? 'You have a follow-up reminder',
      notificationDetails,
      payload: message.data.toString(),
    );
  }

  /// Process notification data
  Future<void> _processNotificationData(Map<String, dynamic> data) async {
    try {
      final type = data['type'];
      final leadId = data['leadId'];

      switch (type) {
        case 'follow_up_reminder':
          if (leadId != null) {
            _navigateToLead(leadId);
          }
          break;
        case 'task_reminder':
          _navigateToTasks();
          break;
        default:
          _navigateToHome();
      }
    } catch (e) {
      print('[FCMService] Error processing notification data: $e');
    }
  }

  /// Process notification payload
  void _processNotificationPayload(String payload) {
    try {
      // Parse payload and navigate accordingly
      print('[FCMService] Processing payload: $payload');
    } catch (e) {
      print('[FCMService] Error processing payload: $e');
    }
  }

  /// Navigate to lead details
  void _navigateToLead(String leadId) {
    try {
      Get.toNamed('/leadDetail', arguments: {'leadId': leadId});
    } catch (e) {
      print('[FCMService] Error navigating to lead: $e');
    }
  }

  /// Navigate to tasks
  void _navigateToTasks() {
    try {
      Get.toNamed('/tasks');
    } catch (e) {
      print('[FCMService] Error navigating to tasks: $e');
    }
  }

  /// Navigate to home
  void _navigateToHome() {
    try {
      Get.toNamed('/');
    } catch (e) {
      print('[FCMService] Error navigating to home: $e');
    }
  }

  /// Schedule follow-up reminder
  Future<void> scheduleFollowUpReminder({
    required String leadId,
    required String leadName,
    required DateTime reminderDate,
    String? message,
  }) async {
    try {
      final notificationId = leadId.hashCode;
      final title = 'Follow-up Reminder';
      final body = (message != null && message.trim().isNotEmpty)
          ? message
          : 'Follow up with $leadName';

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'follow_up_reminders',
            'Follow-up Reminders',
            channelDescription: 'Notifications for follow-up reminders',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Convert UTC DateTime to TZDateTime for scheduling
      // The reminderDate is already in UTC, so we need to create a TZDateTime in UTC
      final tzDateTime = tz.TZDateTime.from(reminderDate, tz.UTC);

      // Validate that the scheduled time is in the future
      final now = tz.TZDateTime.now(tz.UTC);
      if (tzDateTime.isBefore(now)) {
        print(
          '[FCMService] Warning: Reminder time is in the past, skipping FCM scheduling',
        );
        return;
      }

      await _localNotifications!.zonedSchedule(
        notificationId,
        title,
        body,
        tzDateTime,
        notificationDetails,
        payload: 'leadId:$leadId',
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      print(
        '[FCMService] Scheduled reminder for $leadName at $tzDateTime (UTC)',
      );
    } catch (e) {
      print('[FCMService] Error scheduling reminder: $e');
    }
  }

  /// Cancel follow-up reminder
  Future<void> cancelFollowUpReminder(String leadId) async {
    try {
      final notificationId = leadId.hashCode;
      await _localNotifications!.cancel(notificationId);
      print('[FCMService] Cancelled reminder for lead: $leadId');
    } catch (e) {
      print('[FCMService] Error cancelling reminder: $e');
    }
  }

  /// Get FCM token
  String? get fcmToken => _fcmToken;

  /// Dispose resources
  void dispose() {
    _tokenStream?.cancel();
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('[FCMService] Background message received: ${message.messageId}');
}
