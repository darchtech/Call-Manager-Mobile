import 'package:flutter/services.dart';

class CallRepository {
  static const MethodChannel _channel = MethodChannel('call_tracking');
  Future<bool> makePhoneCall(String phoneNumber) async {
    try {
      final bool placed = await _channel.invokeMethod('startPhoneCall', {
        'phoneNumber': phoneNumber,
      });
      return placed;
    } catch (_) {
      return false;
    }
  }
}
