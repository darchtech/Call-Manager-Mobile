import 'package:get/get.dart';

class FontUtils {
  static const String _defaultFont = 'Poppins';
  static const String _arabicFont = 'Tajawal';
  
  /// Returns the appropriate font family based on the current locale
  static String getFontFamily() {
    final locale = Get.locale;
    if (locale?.languageCode == 'ar') {
      return _arabicFont;
    }
    return _defaultFont;
  }
  
  /// Returns the default font family (Poppins)
  static String get defaultFont => _defaultFont;
  
  /// Returns the Arabic font family (Tajawal)
  static String get arabicFont => _arabicFont;
} 