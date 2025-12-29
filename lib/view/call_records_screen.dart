import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sizer/sizer.dart';

import '../utils/text_helper.dart';
import '../controller/call_controller.dart';
import '../model/call_record.dart';
import '../services/call_sync_service.dart';
import '../widgets/base_scaffold.dart';

class CallRecordsScreen extends GetView<CallController> {
  const CallRecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DrawerScaffold(
      title: 'Call Records',
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(Icons.sync),
          onPressed: () => controller.syncCallRecords(),
        ),
        IconButton(
          icon: Icon(Icons.analytics),
          onPressed: () => _showStatistics(context),
        ),
      ],
      body: Column(
        children: [
          _buildSyncStatus(),
          Expanded(child: _buildCallRecordsList()),
        ],
      ),
    );
  }

  Widget _buildSyncStatus() {
    return Obx(() {
      final syncService = CallSyncService.instance;
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(4.w),
        color: Colors.blue.shade50,
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  syncService.autoSyncEnabled
                      ? Icons.sync
                      : Icons.sync_disabled,
                  color: syncService.autoSyncEnabled
                      ? Colors.green
                      : Colors.orange,
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: Text(
                    syncService.lastSyncStatus,
                    style: TextHelper.body(),
                  ),
                ),
              ],
            ),
            if (syncService.pendingSyncCount > 0) ...[
              SizedBox(height: 1.h),
              Text(
                '${syncService.pendingSyncCount} records pending sync',
                style: TextHelper.caption(color: Colors.orange),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildCallRecordsList() {
    final arg = Get.arguments;
    final String? phoneFilter = arg is String ? arg : null;
    final records = phoneFilter == null
        ? controller.getAllCallRecords()
        : controller.getCallRecordsByNumber(phoneFilter);

    if (records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.call, size: 20.w, color: Colors.grey),
            SizedBox(height: 2.h),
            Text(
              phoneFilter == null
                  ? 'No call records yet'
                  : 'No call records for $phoneFilter',
              style: TextHelper.body(color: Colors.grey),
            ),
            SizedBox(height: 1.h),
            Text(
              'Make a call to see records here',
              style: TextHelper.caption(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        return _buildCallRecordTile(record);
      },
    );
  }

  Widget _buildCallRecordTile(CallRecord record) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(record.status),
          child: Icon(
            record.isOutgoing ? Icons.call_made : Icons.call_received,
            color: Colors.white,
          ),
        ),
        title: Text(
          record.contactName ?? record.phoneNumber,
          style: TextHelper.body(weight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(record.phoneNumber, style: TextHelper.caption()),
            SizedBox(height: 0.5.h),
            Row(
              children: [
                Text(
                  record.statusText,
                  style: TextHelper.caption(
                    color: _getStatusColor(record.status),
                  ),
                ),
                if (record.duration != null) ...[
                  Text(' • ', style: TextHelper.caption()),
                  Text(record.formattedDuration, style: TextHelper.caption()),
                ],
              ],
            ),
            SizedBox(height: 0.5.h),
            Text(
              _formatTimestamp(record.initiatedAt),
              style: TextHelper.caption(color: Colors.grey),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!record.isSynced)
              Icon(Icons.sync_problem, color: Colors.orange, size: 5.w)
            else
              Icon(Icons.cloud_done, color: Colors.green, size: 5.w),
            if (record.source == CallSource.app)
              Container(
                margin: EdgeInsets.only(top: 1.h),
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'APP',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        onTap: () => _showCallRecordDetails(record),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'CALL_CONNECTED':
      case 'CALL_ACTIVE':
      case 'CALL_ENDED_CONNECTED':
      case 'CALL_ENDED_BY_CALLER':
      case 'CALL_ENDED_BY_CALLEE':
        return Colors.green;
      case 'CALL_DECLINED_BY_LEAD':
      case 'CALL_DECLINED_BY_CALLEE':
      case 'CALL_DECLINED_BY_CALLER':
      case 'CALL_NO_ANSWER':
      case 'CALL_ENDED_NO_ANSWER':
        return Colors.red;
      case 'CALL_BUSY':
        return Colors.orange;
      case 'CALL_DIALING':
      case 'CALL_CONNECTING':
      case 'CALL_RINGING':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showCallRecordDetails(CallRecord record) {
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(6.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 12.w,
                height: 0.5.h,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            SizedBox(height: 3.h),
            Text('Call Details', style: TextHelper.heading()),
            SizedBox(height: 2.h),
            _buildDetailRow('ID', record.id),
            _buildDetailRow('Phone Number', record.phoneNumber),
            _buildDetailRow('Contact Name', record.contactName ?? 'Unknown'),
            _buildDetailRow(
              'Type',
              record.isOutgoing ? 'Outgoing' : 'Incoming',
            ),
            _buildDetailRow('Status', record.statusText),
            _buildDetailRow('Initiated', record.initiatedAt.toString()),
            if (record.connectedAt != null)
              _buildDetailRow('Connected', record.connectedAt.toString()),
            if (record.endedAt != null)
              _buildDetailRow('Ended', record.endedAt.toString()),
            if (record.duration != null)
              _buildDetailRow('Duration', record.formattedDuration),
            _buildDetailRow('Source', record.source.name.toUpperCase()),
            _buildDetailRow('Synced', record.isSynced ? 'Yes' : 'No'),
            if (record.syncError != null)
              _buildDetailRow('Sync Error', record.syncError!),
            SizedBox(height: 2.h),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Get.back(),
                    child: Text('Close'),
                  ),
                ),
                if (!record.isSynced) ...[
                  SizedBox(width: 4.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back();
                        _forceSyncRecord(record);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                      child: Text(
                        'Force Sync',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 30.w,
            child: Text(label, style: TextHelper.body(weight: FontWeight.bold)),
          ),
          Expanded(child: Text(value, style: TextHelper.body())),
        ],
      ),
    );
  }

  void _forceSyncRecord(CallRecord record) async {
    final syncService = CallSyncService.instance;
    final success = await syncService.forceSyncRecord(record);

    if (success) {
      Get.snackbar('Sync Success', 'Record synced successfully');
    } else {
      Get.snackbar('Sync Failed', 'Failed to sync record');
    }
  }

  void _showStatistics(BuildContext context) {
    final stats = controller.getCallStatistics();

    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(6.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 12.w,
                height: 0.5.h,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            SizedBox(height: 3.h),
            Text('Call Statistics', style: TextHelper.heading()),
            SizedBox(height: 2.h),
            _buildStatRow('Total Calls', '${stats['totalCalls']}'),
            _buildStatRow('Outgoing Calls', '${stats['outgoingCalls']}'),
            _buildStatRow('Incoming Calls', '${stats['incomingCalls']}'),
            _buildStatRow('Connected Calls', '${stats['connectedCalls']}'),
            _buildStatRow('Missed Calls', '${stats['missedCalls']}'),
            _buildStatRow(
              'Total Duration',
              _formatDuration(stats['totalDuration']),
            ),
            _buildStatRow(
              'Average Duration',
              _formatDuration(stats['avgDuration']),
            ),
            _buildStatRow('Unsynced Records', '${stats['unsyncedCount']}'),
            SizedBox(height: 2.h),
            ElevatedButton(onPressed: () => Get.back(), child: Text('Close')),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextHelper.body()),
          Text(value, style: TextHelper.body(weight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final secs = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${secs}s';
    } else if (minutes > 0) {
      return '${minutes}m ${secs}s';
    } else {
      return '${secs}s';
    }
  }
}
