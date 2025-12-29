import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

class TextHelper {
  TextHelper._();

  static TextStyle heading({
    Color? color,
    FontWeight weight = FontWeight.w600,
  }) {
    return TextStyle(
      fontSize: 22.sp,
      fontWeight: weight,
      color: color,
      height: 1.25,
    );
  }

  static TextStyle body({Color? color, FontWeight weight = FontWeight.w400}) {
    return TextStyle(
      fontSize: 15.sp,
      fontWeight: weight,
      color: color,
      height: 1.35,
    );
  }

  static TextStyle caption({Color? color}) {
    return TextStyle(
      fontSize: 13.sp,
      fontWeight: FontWeight.w400,
      color: color,
    );
  }
}
