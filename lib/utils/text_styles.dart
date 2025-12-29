import 'package:flutter/material.dart';

class TextHelper {
  TextHelper._();

  static TextStyle size28(BuildContext context) => Theme.of(context).textTheme.displayLarge ?? const TextStyle(fontSize: 28);
  static TextStyle size26(BuildContext context) => Theme.of(context).textTheme.displayMedium ?? const TextStyle(fontSize: 26);
  static TextStyle size24(BuildContext context) => Theme.of(context).textTheme.displaySmall ?? const TextStyle(fontSize: 24);
  static TextStyle size22(BuildContext context) => Theme.of(context).textTheme.headlineLarge ?? const TextStyle(fontSize: 22);
  static TextStyle size20(BuildContext context) => Theme.of(context).textTheme.headlineMedium ?? const TextStyle(fontSize: 20);
  static TextStyle size18(BuildContext context) => Theme.of(context).textTheme.headlineSmall ?? const TextStyle(fontSize: 18);
  static TextStyle size16(BuildContext context) => Theme.of(context).textTheme.titleLarge ?? const TextStyle(fontSize: 16);
  static TextStyle size15(BuildContext context) => Theme.of(context).textTheme.titleMedium ?? const TextStyle(fontSize: 15);
  static TextStyle size14(BuildContext context) => Theme.of(context).textTheme.titleSmall ?? const TextStyle(fontSize: 14);
  static TextStyle size13(BuildContext context) => Theme.of(context).textTheme.bodyLarge ?? const TextStyle(fontSize: 13);
  static TextStyle size12(BuildContext context) => Theme.of(context).textTheme.bodyMedium ?? const TextStyle(fontSize: 12);
  static TextStyle size11(BuildContext context) => Theme.of(context).textTheme.bodySmall ?? const TextStyle(fontSize: 11);
  static TextStyle size10(BuildContext context) => Theme.of(context).textTheme.labelLarge ?? const TextStyle(fontSize: 10);
  static TextStyle size9(BuildContext context) => Theme.of(context).textTheme.labelMedium ?? const TextStyle(fontSize: 9);
  static TextStyle size8(BuildContext context) => Theme.of(context).textTheme.labelSmall ?? const TextStyle(fontSize: 8);
}
