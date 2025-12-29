import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sizer/sizer.dart';
import '../utils/app_colors_new.dart';
import '../utils/text_styles_new.dart';
import '../controller/call_controller.dart';
import 'global_drawer.dart';

class BaseScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool showDrawer;
  final Color? backgroundColor;
  final Color? appBarColor;
  final Color? appBarForegroundColor;
  final bool centerTitle;
  final Widget? bottomNavigationBar;
  final PreferredSizeWidget? bottom;

  const BaseScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.showDrawer = true,
    this.backgroundColor,
    this.appBarColor,
    this.appBarForegroundColor,
    this.centerTitle = false,
    this.bottomNavigationBar,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.background,
      appBar: AppBar(
        title: Text(title, style: TextStyles.appBarTitle),
        backgroundColor: appBarColor ?? AppColors.primary,
        foregroundColor: appBarForegroundColor ?? Colors.white,
        elevation: 0,
        centerTitle: centerTitle,
        actions: actions,
        bottom: bottom,
      ),
      drawer: showDrawer ? const GlobalDrawer() : null,
      body: Column(
        children: [
          // Active Call Banner - shown across all screens when call is active
          Obx(() {
            try {
              final callController = Get.find<CallController>();
              if (callController.callStartTime.value != null) {
                return _buildActiveCallBanner(callController);
              }
            } catch (e) {
              // CallController not available, ignore
            }
            return const SizedBox.shrink();
          }),
          Expanded(child: body),
        ],
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }

  /// Build the "Active Call" banner that appears on all screens when call is active
  Widget _buildActiveCallBanner(CallController callController) {
    return InkWell(
      onTap: () async {
        try {
          final bool success = await callController.returnToCallScreen();
          if (!success) {
            Get.snackbar(
              'No Active Call',
              'There is no active call to return to',
              snackPosition: SnackPosition.TOP,
            );
          }
        } catch (e) {
          Get.snackbar(
            'Error',
            'Failed to return to call screen: $e',
            snackPosition: SnackPosition.TOP,
          );
        }
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          border: Border(
            bottom: BorderSide(
              color: AppColors.primary.withOpacity(0.3),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.phone, color: AppColors.primary, size: 5.w),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active Call',
                    style: TextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    'Tap to return to call',
                    style: TextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward, color: AppColors.primary, size: 5.w),
          ],
        ),
      ),
    );
  }
}

// Convenience widget for screens that need the drawer
class DrawerScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Color? backgroundColor;
  final Color? appBarColor;
  final Color? appBarForegroundColor;
  final bool centerTitle;
  final Widget? bottomNavigationBar;
  final PreferredSizeWidget? bottom;

  const DrawerScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.backgroundColor,
    this.appBarColor,
    this.appBarForegroundColor,
    this.centerTitle = false,
    this.bottomNavigationBar,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: title,
      body: body,
      actions: actions,
      floatingActionButton: floatingActionButton,
      showDrawer: true,
      backgroundColor: backgroundColor,
      appBarColor: appBarColor,
      appBarForegroundColor: appBarForegroundColor,
      centerTitle: centerTitle,
      bottomNavigationBar: bottomNavigationBar,
      bottom: bottom,
    );
  }
}
