import 'package:flutter/material.dart';

class TextStyles {
  TextStyles._();

  static TextStyle get appBarTitle => const TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static TextStyle get heading =>
      const TextStyle(fontSize: 24, fontWeight: FontWeight.bold);

  static TextStyle get heading2 =>
      const TextStyle(fontSize: 20, fontWeight: FontWeight.w600);

  static TextStyle get heading3 =>
      const TextStyle(fontSize: 18, fontWeight: FontWeight.w600);

  static TextStyle get body =>
      const TextStyle(fontSize: 16, fontWeight: FontWeight.normal);

  static TextStyle get caption =>
      const TextStyle(fontSize: 14, fontWeight: FontWeight.normal);

  static TextStyle get button =>
      const TextStyle(fontSize: 16, fontWeight: FontWeight.w600);

  static TextStyle get h3 =>
      const TextStyle(fontSize: 18, fontWeight: FontWeight.w600);

  static TextStyle get bodySmall =>
      const TextStyle(fontSize: 12, fontWeight: FontWeight.normal);

  static TextStyle get bodyMedium =>
      const TextStyle(fontSize: 14, fontWeight: FontWeight.normal);
}
