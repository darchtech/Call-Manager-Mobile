import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sizer/sizer.dart';
import '../utils/app_colors_new.dart';
import '../utils/text_styles_new.dart';
import '../controller/app_controller.dart';
import '../services/auth_service.dart';

class GlobalDrawer extends StatelessWidget {
  const GlobalDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // Drawer Header
          Container(
            height: 25.h,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(4.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // App Logo/Icon
                    Container(
                      width: 12.w,
                      height: 12.w,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.phone_in_talk,
                        color: Colors.white,
                        size: 6.w,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    // App Name
                    Text(
                      'Call Manager',
                      style: TextStyles.heading2.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 0.5.h),
                    // App Description
                    Text(
                      'Manage leads and track calls',
                      style: TextStyles.body.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Navigation Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // _buildDrawerItem(
                //   icon: Icons.people,
                //   title: 'Leads',
                //   subtitle: 'Manage your leads',
                //   onTap: () {
                //     Navigator.pop(context);
                //     Get.find<AppController>().navigateToLeads();
                //   },
                // ),
                _buildDrawerItem(
                  icon: Icons.assignment,
                  title: 'Tasks',
                  subtitle: 'Manage your tasks',
                  onTap: () {
                    Navigator.pop(context);
                    Get.toNamed('/tasks');
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.schedule,
                  title: 'Follow-ups',
                  subtitle: 'Upcoming follow-ups',
                  onTap: () {
                    Navigator.pop(context);
                    Get.toNamed('/followUps');
                  },
                ),
                // _buildDrawerItem(
                //   icon: Icons.phone,
                //   title: 'Call Screen',
                //   subtitle: 'Make calls',
                //   onTap: () {
                //     Navigator.pop(context);
                //     Get.find<AppController>().navigateToCallScreen();
                //   },
                // ),
                // _buildDrawerItem(
                //   icon: Icons.history,
                //   title: 'Call History',
                //   subtitle: 'View call records',
                //   onTap: () {
                //     Navigator.pop(context);
                //     Get.find<AppController>().navigateToCallHistory();
                //   },
                // ),
                // _buildDrawerItem(
                //   icon: Icons.analytics,
                //   title: 'Call Records',
                //   subtitle: 'Analytics and reports',
                //   onTap: () {
                //     Navigator.pop(context);
                //     Get.find<AppController>().navigateToCallRecords();
                //   },
                // ),
                // _buildDrawerItem(
                //   icon: Icons.wifi,
                //   title: 'WebSocket Test',
                //   subtitle: 'Test server connection',
                //   onTap: () {
                //     Navigator.pop(context);
                //     Get.toNamed('/websocket-test');
                //   },
                // ),

                // Divider
                Divider(height: 2.h, color: AppColors.border),

                // Settings Section
                // _buildDrawerItem(
                //   icon: Icons.settings,
                //   title: 'Settings',
                //   subtitle: 'App preferences',
                //   onTap: () {
                //     Navigator.pop(context);
                //     _showSettingsDialog(context);
                //   },
                // ),
                // _buildDrawerItem(
                //   icon: Icons.help,
                //   title: 'Help & Support',
                //   subtitle: 'Get help and support',
                //   onTap: () {
                //     Navigator.pop(context);
                //     _showHelpDialog(context);
                //   },
                // ),
                _buildDrawerItem(
                  icon: Icons.info,
                  title: 'About',
                  subtitle: 'App information',
                  onTap: () {
                    Navigator.pop(context);
                    _showAboutDialog(context);
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.logout,
                  title: 'Logout',
                  subtitle: 'Sign out of the app',
                  onTap: () {
                    Navigator.pop(context);
                    _showLogoutDialog(context);
                  },
                ),
              ],
            ),
          ),

          // Footer
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: AppColors.lightBackground,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.phone_android,
                  color: AppColors.textSecondary,
                  size: 4.w,
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: Text(
                    'Call Manager v1.0.0',
                    style: TextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 10.w,
        height: 10.w,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 5.w),
      ),
      title: Text(
        title,
        style: TextStyles.body.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyles.caption.copyWith(color: AppColors.textSecondary),
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Settings', style: TextStyles.heading3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.notifications, color: AppColors.primary),
              title: Text('Notifications'),
              subtitle: Text('Manage notification settings'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement notification settings
              },
            ),
            ListTile(
              leading: Icon(Icons.sync, color: AppColors.primary),
              title: Text('Sync Settings'),
              subtitle: Text('Configure data synchronization'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement sync settings
              },
            ),
            ListTile(
              leading: Icon(Icons.security, color: AppColors.primary),
              title: Text('Privacy & Security'),
              subtitle: Text('Manage privacy settings'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement privacy settings
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Help & Support', style: TextStyles.heading3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Need help? Here are some resources:', style: TextStyles.body),
            SizedBox(height: 2.h),
            _buildHelpItem(
              icon: Icons.book,
              title: 'User Guide',
              subtitle: 'Learn how to use the app',
            ),
            _buildHelpItem(
              icon: Icons.video_library,
              title: 'Video Tutorials',
              subtitle: 'Watch step-by-step guides',
            ),
            _buildHelpItem(
              icon: Icons.support_agent,
              title: 'Contact Support',
              subtitle: 'Get help from our team',
            ),
            _buildHelpItem(
              icon: Icons.bug_report,
              title: 'Report Issue',
              subtitle: 'Report bugs or problems',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyles.body.copyWith(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1.h),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 5.w),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyles.body.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: TextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout', style: TextStyles.heading3),
        content: Text(
          'Are you sure you want to logout? You will need to sign in again to access the app.',
          style: TextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Logout',
              style: TextStyles.body.copyWith(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout() async {
    try {
      // Show loading indicator
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      // Perform logout using AuthService
      await AuthService.instance.logout();

      // Close loading dialog
      Get.back();

      // Navigate to login screen
      Get.offAllNamed('/login');

      // Show success message
      Get.snackbar(
        'Logout',
        'You have been successfully logged out',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      // Close loading dialog if it's still open
      if (Get.isDialogOpen == true) {
        Get.back();
      }

      // Show error message
      Get.snackbar(
        'Logout Error',
        'Failed to logout: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );

      // Still navigate to login screen even if logout failed
      Get.offAllNamed('/login');
    }
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('About Call Manager', style: TextStyles.heading3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20.w,
              height: 20.w,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.phone_in_talk,
                color: AppColors.primary,
                size: 10.w,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              'Call Manager',
              style: TextStyles.heading3.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 0.5.h),
            Text(
              'Version 1.0.0',
              style: TextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
            SizedBox(height: 2.h),
            Text(
              'A comprehensive lead management and call tracking application designed to help you manage your leads and track your calling activities efficiently.',
              style: TextStyles.body,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 2.h),
            Text(
              '© 2025 Call Manager. All rights reserved.',
              style: TextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyles.body.copyWith(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
