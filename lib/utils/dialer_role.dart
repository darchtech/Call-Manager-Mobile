import 'package:flutter/services.dart';

class DialerRole {
  static const MethodChannel _channel = MethodChannel('dialer_role');

  static Future<bool> isDefaultDialer() async {
    try {
      final bool result =
          await _channel.invokeMethod('isDefaultDialer') as bool;
      return result;
    } catch (_) {
      return false;
    }
  }

  static Future<void> requestDefaultDialer() async {
    try {
      await _channel.invokeMethod('requestDefaultDialer');
    } catch (_) {
      // no-op
    }
  }
}
