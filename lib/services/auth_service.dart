import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'offline_sync_manager.dart';
import 'call_sync_service.dart';
import 'lead_sync_service.dart';
import 'api_service.dart';
import 'websocket_service.dart';
import 'fcm_service.dart';

class AuthService extends GetxService {
  static AuthService get instance => Get.find<AuthService>();

  final Rxn<Map<String, dynamic>> _user = Rxn<Map<String, dynamic>>();
  final RxString _accessToken = ''.obs;
  final RxString _refreshToken = ''.obs;

  Map<String, dynamic>? get user => _user.value;
  String get accessToken => _accessToken.value;
  String get refreshToken => _refreshToken.value;
  bool get isAuthenticated => _accessToken.isNotEmpty;
  bool get isUserActive => (_user.value?['isActive'] as bool?) ?? true;

  @override
  Future<void> onInit() async {
    super.onInit();
    await _loadFromStorage();

    // If we have tokens, try to validate them by fetching user info
    if (isAuthenticated) {
      print('[Auth] Found persisted tokens, validating...');
      final isValid = await fetchMe();
      if (!isValid) {
        print('[Auth] Tokens expired or invalid, clearing...');
        await _clear();
      } else {
        print('[Auth] Tokens valid, user authenticated');
        // Initialize sync services since user is already authenticated
        _initializeSyncServices();
        // Ensure FCM token is sent after auth is confirmed on startup
        await FCMService.instance.sendTokenToServer();
      }
    }
  }

  Future<void> _loadFromStorage() async {
    // Load tokens from secure storage
    final secure = FlutterSecureStorage();
    _accessToken.value = (await secure.read(key: 'auth.accessToken')) ?? '';
    _refreshToken.value = (await secure.read(key: 'auth.refreshToken')) ?? '';

    // Load user profile from Hive box
    await Hive.initFlutter();
    final box = await Hive.openBox('auth');
    final userMap = box.get('user');
    if (userMap is Map) {
      _user.value = Map<String, dynamic>.from(userMap);
    } else {
      // Fallback: migrate from old SharedPreferences if present
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('auth.user');
      if (userJson != null) {
        final parsed = jsonDecode(userJson) as Map<String, dynamic>;
        _user.value = parsed;
        await box.put('user', parsed);
        await prefs.remove('auth.user');
      }
    }
  }

  Future<void> _persist() async {
    // Save tokens to secure storage
    final secure = FlutterSecureStorage();
    await secure.write(key: 'auth.accessToken', value: _accessToken.value);
    await secure.write(key: 'auth.refreshToken', value: _refreshToken.value);

    // Save user to Hive box
    final box = await Hive.openBox('auth');
    if (_user.value != null) {
      await box.put('user', _user.value);
    }
  }

  Future<bool> login({required String email, required String password}) async {
    final api = ApiService.instance;
    final response = await api.login(email: email, password: password);
    if (response.isSuccess) {
      final envelope = response.data!; // { success,status,data,message }
      final inner = Map<String, dynamic>.from(envelope['data']);
      final userMap = Map<String, dynamic>.from(inner['user']);
      final tokensMap = Map<String, dynamic>.from(inner['tokens']);
      final access = Map<String, dynamic>.from(tokensMap['access']);
      final refresh = Map<String, dynamic>.from(tokensMap['refresh']);

      _user.value = userMap;
      // ignore: avoid_print
      print('[Auth] login user.isActive=${_user.value?['isActive']}');
      _accessToken.value = access['token'] as String;
      _refreshToken.value = refresh['token'] as String;
      await _persist();
      // Optionally fetch fresh /auth/me
      await fetchMe();
      // Connect WebSocket now that we have a token
      if (Get.isRegistered<WebSocketService>()) {
        // ignore: avoid_print
        print('[Auth] Triggering WebSocket connect after login');
        WebSocketService.instance.connect();
      }
      // Initialize sync services after authenticated
      _initializeSyncServices();
      // Send FCM token now that we are authenticated
      await FCMService.instance.sendTokenToServer();
      return true;
    }
    return false;
  }

  Future<bool> fetchMe() async {
    final api = ApiService.instance;
    final response = await api.getMe();
    if (response.isSuccess) {
      final envelope = response.data!;
      final inner = Map<String, dynamic>.from(envelope['data']);
      _user.value = inner;
      // ignore: avoid_print
      print('[Auth] fetchMe user.isActive=${_user.value?['isActive']}');
      await _persist();
      return true;
    }
    return false;
  }

  Future<bool> refreshTokens() async {
    if (_refreshToken.isEmpty) return false;
    final api = ApiService.instance;
    final response = await api.refreshTokens(_refreshToken.value);
    if (response.isSuccess) {
      final tokens = response.data as Map<String, dynamic>;
      _accessToken.value = tokens['access']['token'] as String;
      _refreshToken.value = tokens['refresh']['token'] as String;
      await _persist();
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    final api = ApiService.instance;
    final rt = _refreshToken.value;
    if (rt.isNotEmpty) {
      await api.logout(rt); // ignore response
    }
    await _clear();
  }

  Future<void> _clear() async {
    _user.value = null;
    _accessToken.value = '';
    _refreshToken.value = '';
    final secure = FlutterSecureStorage();
    await secure.delete(key: 'auth.accessToken');
    await secure.delete(key: 'auth.refreshToken');
    final box = await Hive.openBox('auth');
    await box.delete('user');
  }

  /// Initialize sync services (used both on login and on app startup with valid tokens)
  void _initializeSyncServices() {
    // Initialize sync services after authenticated (order: deps first)
    if (!Get.isRegistered<CallSyncService>()) {
      Get.put(CallSyncService());
    }
    if (!Get.isRegistered<LeadSyncService>()) {
      Get.put(LeadSyncService());
    }
    if (!Get.isRegistered<OfflineSyncManager>()) {
      Get.put(OfflineSyncManager());
    }
    print('[Auth] Sync services initialized');
  }
}
