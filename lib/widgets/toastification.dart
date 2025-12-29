import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sizer/sizer.dart';
import 'package:toastification/toastification.dart';

class ToastHelper {
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static void showToast({
    required BuildContext context,
    required String message,
    required ToastificationType type,
  }) {
    toastification.show(
      context: context,
      type: type,
      style: ToastificationStyle.minimal,
      autoCloseDuration: const Duration(seconds: 3),
      title: Text(
        getTitle(type),
        style: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 15.sp,
        ),
      ),
      description: Text(
        message,
        style: TextStyle(fontSize: 15.sp),
      ),
      alignment: Alignment.topRight,
      animationDuration: const Duration(milliseconds: 200),
      animationBuilder: (context, animation, alignment, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      icon: Icon(
        getIcon(type),
        color: getIconColor(type),
        size: 15.sp, // Reduce icon size
      ),
      showIcon: true,
      primaryColor: getPrimaryColor(type),
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      borderRadius: BorderRadius.circular(10.sp),
      padding: EdgeInsets.symmetric(horizontal: 10.sp, vertical: 6.sp),
      margin: EdgeInsets.symmetric(horizontal: 10.sp, vertical: 5.sp),
      showProgressBar: true,
      closeButtonShowType: CloseButtonShowType.onHover,
      pauseOnHover: true,
      dragToClose: true,
    );
  }

  static void showErrorToast(String message) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    toastification.show(
      context: context,
      type: ToastificationType.error,
      style: ToastificationStyle.minimal,
      autoCloseDuration: const Duration(seconds: 3),
      title: Text(
        getTitle(ToastificationType.error),
        style: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 15.sp,
        ),
      ),
      description: Text(
        message,
        style: TextStyle(fontSize: 15.sp),
      ),
      alignment: Alignment.topRight,
      icon: Icon(getIcon(ToastificationType.error), color: getIconColor(ToastificationType.error), size: 15.sp),
      showIcon: true,
      primaryColor: getPrimaryColor(ToastificationType.error),
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      borderRadius: BorderRadius.circular(10.sp),
      padding: EdgeInsets.symmetric(horizontal: 10.sp, vertical: 6.sp),
      margin: EdgeInsets.symmetric(horizontal: 10.sp, vertical: 5.sp),
      showProgressBar: true,
      closeButtonShowType: CloseButtonShowType.onHover,
      pauseOnHover: true,
      dragToClose: true,
    );
  }

  static String getTitle(ToastificationType type) {
    switch (type) {
      case ToastificationType.success:
        return "Success".tr;
      case ToastificationType.warning:
        return "Warning".tr;
      case ToastificationType.error:
        return "Error".tr;
      default:
        return "Oops!".tr;
    }
  }

  static IconData getIcon(ToastificationType type) {
    switch (type) {
      case ToastificationType.success:
        return Icons.check_circle;
      case ToastificationType.warning:
        return Icons.warning_amber_rounded;
      case ToastificationType.error:
        return Icons.error;
      default:
        return Icons.info;
    }
  }

  static Color getPrimaryColor(ToastificationType type) {
    switch (type) {
      case ToastificationType.success:
        return Colors.green.shade700;
      case ToastificationType.warning:
        return Colors.orange.shade700;
      case ToastificationType.error:
        return Colors.red.shade700;
      default:
        return Colors.blue.shade700;
    }
  }

  static Color getIconColor(ToastificationType type) {
    switch (type) {
      case ToastificationType.success:
        return Colors.green;
      case ToastificationType.warning:
        return Colors.orange;
      case ToastificationType.error:
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
}
