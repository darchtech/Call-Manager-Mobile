import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sizer/sizer.dart';
import 'package:flutter/services.dart';

import '../utils/text_helper.dart';
import '../controller/call_controller.dart';

class ActiveCallScreen extends GetView<CallController> {
  const ActiveCallScreen({super.key});

  static const platform = MethodChannel('call_tracking');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Obx(() {
          final isCallActive = controller.callStartTime.value != null;
          final call = controller.currentCallRecord.value;

          if (isCallActive && call != null) {
            return _buildActiveCallUI(call);
          } else {
            return _buildCallEndedUI();
          }
        }),
      ),
    );
  }

  Widget _buildActiveCallUI(call) {
    return Column(
      children: [
        // Top spacing
        SizedBox(height: 8.h),

        // Caller info
        CircleAvatar(
          radius: 15.w,
          backgroundColor: Colors.green,
          child: Icon(Icons.person, size: 20.w, color: Colors.white),
        ),
        SizedBox(height: 4.h),

        Text(
          call.phoneNumber,
          style: TextStyle(
            color: Colors.white,
            fontSize: 24.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 2.h),

        // Live duration timer
        Container(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.green, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer, color: Colors.green, size: 6.w),
              SizedBox(width: 2.w),
              Text(
                _formatDuration(controller.callDuration.value),
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        Spacer(),

        // Call control buttons
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCallButton(
                icon: Icons.mic_off,
                label: 'Mute',
                onPressed: () => _toggleMute(),
                color: Colors.blue,
              ),
              _buildCallButton(
                icon: Icons.volume_up,
                label: 'Speaker',
                onPressed: () => _toggleSpeaker(),
                color: Colors.orange,
              ),
              _buildCallButton(
                icon: Icons.pause,
                label: 'Hold',
                onPressed: () => _toggleHold(),
                color: Colors.purple,
              ),
              _buildCallButton(
                icon: Icons.call_end,
                label: 'End',
                onPressed: () => _endCall(),
                color: Colors.red,
              ),
            ],
          ),
        ),

        SizedBox(height: 6.h),
      ],
    );
  }

  Widget _buildCallEndedUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.call_end, size: 20.w, color: Colors.red),
          SizedBox(height: 4.h),
          Text(
            'Call Ended',
            style: TextStyle(color: Colors.white, fontSize: 24.sp),
          ),
          SizedBox(height: 4.h),
          ElevatedButton.icon(
            icon: Icon(Icons.arrow_back),
            label: Text('Back to Dialer'),
            onPressed: () => Get.back(),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 15.w,
          height: 15.w,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: 8.w),
            onPressed: onPressed,
          ),
        ),
        SizedBox(height: 2.h),
        Text(label, style: TextHelper.caption(color: Colors.white)),
      ],
    );
  }

  Future<void> _toggleMute() async {
    try {
      await platform.invokeMethod('muteCall', {'muted': true});
    } catch (e) {
      print('Mute failed: $e');
    }
  }

  Future<void> _toggleSpeaker() async {
    try {
      await platform.invokeMethod('toggleSpeaker', {'on': true});
    } catch (e) {
      print('Speaker toggle failed: $e');
    }
  }

  Future<void> _toggleHold() async {
    try {
      await platform.invokeMethod('holdCall');
    } catch (e) {
      print('Hold failed: $e');
    }
  }

  Future<void> _endCall() async {
    try {
      await platform.invokeMethod('endCall');
    } catch (e) {
      print('End call failed: $e');
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }
}
