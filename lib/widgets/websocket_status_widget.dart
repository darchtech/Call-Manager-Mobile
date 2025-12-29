import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sizer/sizer.dart';
import '../services/websocket_service.dart';
import '../utils/app_colors_new.dart';
import '../utils/text_styles_new.dart';

class WebSocketStatusWidget extends StatelessWidget {
  const WebSocketStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final wsService = WebSocketService.instance;

    return Obx(() {
      final isConnected = wsService.isConnected;
      final status = wsService.connectionStatus;
      final latency = wsService.latency;
      final serverTime = wsService.serverTime;

      return Container(
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
        margin: EdgeInsets.all(2.w),
        decoration: BoxDecoration(
          color: isConnected
              ? AppColors.success.withOpacity(0.1)
              : AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isConnected ? AppColors.success : AppColors.error,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status indicator
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isConnected ? AppColors.success : AppColors.error,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 2.w),

            // Status text
            Text(
              status,
              style: TextStyles.bodySmall.copyWith(
                color: isConnected ? AppColors.success : AppColors.error,
                fontWeight: FontWeight.w500,
              ),
            ),

            // Latency indicator (if connected)
            if (isConnected && latency > 0) ...[
              SizedBox(width: 2.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 1.w, vertical: 0.5.h),
                decoration: BoxDecoration(
                  color: _getLatencyColor(latency).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${latency}ms',
                  style: TextStyles.caption.copyWith(
                    color: _getLatencyColor(latency),
                    fontSize: 10.sp,
                  ),
                ),
              ),
            ],

            // Server time (if connected)
            if (isConnected && serverTime.isNotEmpty) ...[
              SizedBox(width: 2.w),
              Icon(Icons.access_time, size: 12.sp, color: AppColors.primary),
            ],

            // Reconnect button (if disconnected)
            if (!isConnected) ...[
              SizedBox(width: 2.w),
              GestureDetector(
                onTap: () => wsService.forceReconnect(),
                child: Icon(
                  Icons.refresh,
                  size: 14.sp,
                  color: AppColors.primary,
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  Color _getLatencyColor(int latency) {
    if (latency < 100) return AppColors.success;
    if (latency < 300) return AppColors.warning;
    return AppColors.error;
  }
}

class WebSocketStatusDialog extends StatelessWidget {
  const WebSocketStatusDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final wsService = WebSocketService.instance;

    return Dialog(
      child: Container(
        padding: EdgeInsets.all(4.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.wifi, color: AppColors.primary, size: 20.sp),
                SizedBox(width: 2.w),
                Text('Connection Status', style: TextStyles.h3),
                const Spacer(),
                IconButton(
                  onPressed: () => Get.back(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),

            SizedBox(height: 3.h),

            // Status details
            Obx(() {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusRow('Status', wsService.connectionStatus),
                  _buildStatusRow(
                    'Connected',
                    wsService.isConnected ? 'Yes' : 'No',
                  ),
                  _buildStatusRow('Latency', '${wsService.latency}ms'),
                  _buildStatusRow(
                    'Reconnect Attempts',
                    '${wsService.reconnectAttempts}',
                  ),
                  if (wsService.serverTime.isNotEmpty)
                    _buildStatusRow('Server Time', wsService.serverTime),
                  if (wsService.lastError.isNotEmpty)
                    _buildStatusRow(
                      'Last Error',
                      wsService.lastError,
                      isError: true,
                    ),
                ],
              );
            }),

            SizedBox(height: 3.h),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => wsService.forceReconnect(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Reconnect'),
                  ),
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Get.back(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, {bool isError = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 0.5.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 30.w,
            child: Text(
              '$label:',
              style: TextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyles.bodyMedium.copyWith(
                color: isError ? AppColors.error : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
