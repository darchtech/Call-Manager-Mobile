import 'package:call_navigator/utils/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sizer/sizer.dart';
// import 'package:flutter/services.dart';

import '../routes/routes.dart';
import '../utils/text_helper.dart';
import '../utils/dialer_role.dart';
import '../controller/call_controller.dart';
import '../widgets/base_scaffold.dart';

class CallScreen extends GetView<CallController> {
  CallScreen({super.key});

  void _makePhoneCall(String phoneNumber) => controller.startCall(phoneNumber);

  // Removed unused platform channels

  // Unused helper; remove to satisfy lint
  /* Future<void> _requestOverlayPermission() async {
    try {
      print('[overlay] Requesting overlay permission...');
      await dialerChannel.invokeMethod('requestOverlayPermission');
      print('[overlay] Overlay permission requested');
    } catch (e) {
      print('[overlay] Overlay permission request failed: $e');
    }
  } */

  // Unused helper; remove to satisfy lint
  /* Future<void> _testOverlay() async {
    try {
      print('[overlay] Testing overlay...');
      await platform.invokeMethod('showCallOverlay', {
        'phoneNumber': '+91 9876543210',
        'callState': 'CONNECTED',
      });
      print('[overlay] Test overlay shown');
    } catch (e) {
      print('[overlay] Test overlay failed: $e');
    }
  } */

  final List<Map<String, String>> _contacts = [
    {'name': 'Piyush Jaiswal', 'number': '+91 7499582803'},
    {'name': 'Suyog Bhosale', 'number': '+91 7387107829'},
    {'name': 'Mike Johnson', 'number': '+91 7499582805'},
    {'name': 'Sarah Wilson', 'number': '+91 7499582806'},
    {'name': 'David Brown', 'number': '+91 7499582807'},
  ];

  @override
  Widget build(BuildContext context) {
    return DrawerScaffold(
      title: 'Call Manager',
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(Icons.people),
          onPressed: () {
            Get.toNamed(Routes.LEAD_SCREEN);
          },
          tooltip: 'Leads',
        ),
        // Removed Call History navigation (feature deprecated)
        IconButton(
          icon: Icon(Icons.storage),
          onPressed: () {
            Get.toNamed(Routes.CALL_RECORDS_SCREEN);
          },
          tooltip: 'Call Records',
        ),
      ],
      body: Column(
        children: [
          // Call Status Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: () async {
                  await DialerRole.requestDefaultDialer();
                },
                child: Text(
                  'Set as Default Dialer',
                  style: TextHelper.body(color: ColorsForApp.primaryColor),
                ),
              ),
              // ElevatedButton(
              //   onPressed: () async {
              //     await _requestOverlayPermission();
              //   },
              //   child: Text(
              //     'Enable Overlay',
              //     style: TextHelper.body(color: ColorsForApp.primaryColor),
              //   ),
              // ),
              // ElevatedButton(
              //   onPressed: () async {
              //     await _testOverlay();
              //   },
              //   child: Text(
              //     'Test Overlay',
              //     style: TextHelper.body(color: ColorsForApp.primaryColor),
              //   ),
              // ),
            ],
          ),
          // Active Call UI
          // Obx(() => _buildCallStatus()),

          // Contacts List
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(4.w),
              itemCount: _contacts.length,
              itemBuilder: (context, index) {
                final contact = _contacts[index];
                return Card(
                  margin: EdgeInsets.only(bottom: 2.h),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Text(
                        contact['name']![0],
                        style: TextHelper.body(
                          color: Colors.white,
                          weight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      contact['name']!,
                      style: TextHelper.body(weight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      contact['number']!,
                      style: TextHelper.caption(),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.phone, color: Colors.green),
                      onPressed: () => _makePhoneCall(contact['number']!),
                    ),

                    onTap: () => _makePhoneCall(contact['number']!),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Unused UI; remove to satisfy lint
  /*
  Widget _buildCallStatus() {
    final isCallActive = controller.callStartTime.value != null;

    if (isCallActive) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(4.w),
        color: Colors.green.shade50,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.phone_in_talk, color: Colors.green),
                SizedBox(width: 2.w),
                Text(
                  'Call in progress - ${_formatDuration(controller.callDuration.value)}',
                  style: TextHelper.body(
                    color: Colors.green,
                    weight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 2.h),
            // Call Control Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCallButton(
                  icon: Icons.mic_off,
                  label: 'Mute',
                  onPressed: () => _toggleMute(),
                ),
                _buildCallButton(
                  icon: Icons.volume_up,
                  label: 'Speaker',
                  onPressed: () => _toggleSpeaker(),
                ),
                _buildCallButton(
                  icon: Icons.pause,
                  label: 'Hold',
                  onPressed: () => _toggleHold(),
                ),
                _buildCallButton(
                  icon: Icons.call_end,
                  label: 'End',
                  onPressed: () => _endCall(),
                  color: Colors.red,
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(4.w),
      color: Colors.blue.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.phone, color: Colors.grey),
          SizedBox(width: 2.w),
          Text(
            'Status: Not in call',
            style: TextHelper.body(color: Colors.grey),
          ),
        ],
      ),
    );
  }
  */

  // Removed unused button helpers and overlay controls (no longer referenced)
}
