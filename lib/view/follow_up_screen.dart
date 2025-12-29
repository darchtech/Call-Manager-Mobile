import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sizer/sizer.dart';
import '../model/follow_up.dart';
import '../model/lead.dart';
import '../services/follow_up_service.dart';
import '../controller/lead_controller.dart';
import '../utils/app_colors_new.dart';
import '../utils/text_styles_new.dart';
import '../utils/date_utils.dart' as AppDateUtils;
import '../widgets/edit_follow_up_dialog.dart';
import '../widgets/base_scaffold.dart';
import '../routes/routes.dart';

class FollowUpScreen extends StatefulWidget {
  final String? leadId; // Optional lead ID to filter follow-ups

  const FollowUpScreen({super.key, this.leadId});

  @override
  State<FollowUpScreen> createState() => _FollowUpScreenState();
}

class _FollowUpScreenState extends State<FollowUpScreen> {
  final FollowUpService _followUpService = Get.find<FollowUpService>();
  final LeadController _leadController = Get.find<LeadController>();

  List<FollowUp> _upcomingFollowUps = [];
  bool _isLoading = false;
  String _selectedFilter = 'upcoming'; // 'upcoming' or 'newest'

  @override
  void initState() {
    super.initState();
    print('[UI-FollowUpScreen] ===== INITIALIZING =====');
    _loadUpcomingFollowUps();
  }

  Future<void> _loadUpcomingFollowUps() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      print('[UI-FollowUpScreen] 📋 Loading upcoming follow-ups...');

      // Get follow-ups - either all or filtered by lead ID
      List<FollowUp> allFollowUps;
      if (widget.leadId != null) {
        // Get follow-ups for specific lead
        allFollowUps = await _followUpService.getFollowUpsForLead(
          widget.leadId!,
        );
        print(
          '[UI-FollowUpScreen] 📋 Filtering follow-ups for lead: ${widget.leadId}',
        );
      } else {
        // Get all follow-ups
        allFollowUps = await _followUpService.getAllFollowUps();
      }

      List<FollowUp> filteredFollowUps = [];
      final now = DateTime.now();
      final nowUTC = now.toUtc();

      if (_selectedFilter == 'upcoming') {
        // Filter for upcoming follow-ups (due date is in the future)
        // Compare UTC times to avoid timezone issues
        filteredFollowUps = allFollowUps.where((followUp) {
          final followUpUTC = followUp.dueAt.toUtc();
          final isAfter = followUpUTC.isAfter(nowUTC);
          return isAfter;
        }).toList();
        // Sort by due date (earliest first)
        filteredFollowUps.sort((a, b) => a.dueAt.compareTo(b.dueAt));
      } else if (_selectedFilter == 'newest') {
        // Show all follow-ups sorted by creation date (newest first)
        filteredFollowUps = List.from(allFollowUps);
        filteredFollowUps.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      if (mounted) {
        setState(() {
          _upcomingFollowUps = filteredFollowUps;
        });
      }

      print(
        '[UI-FollowUpScreen] ✅ Loaded ${filteredFollowUps.length} follow-ups (${_selectedFilter})',
      );

      // Debug: Print first few follow-ups to see their data
      if (filteredFollowUps.isNotEmpty) {
        print('[UI-FollowUpScreen] 📊 Sample follow-ups:');
        for (int i = 0; i < filteredFollowUps.length && i < 3; i++) {
          final f = filteredFollowUps[i];
          print(
            '[UI-FollowUpScreen] - ${f.id}: ${f.dueAt} - ${f.note ?? "No note"}',
          );
        }
      }
    } catch (e) {
      print('[UI-FollowUpScreen] ❌ Error loading follow-ups: $e');
      Get.snackbar(
        'Error',
        'Failed to load follow-ups: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('[UI-FollowUpScreen] ===== BUILDING UI =====');
    print('[UI-FollowUpScreen] 📊 Current state:');
    print('[UI-FollowUpScreen] - isLoading: $_isLoading');
    print(
      '[UI-FollowUpScreen] - upcomingFollowUps count: ${_upcomingFollowUps.length}',
    );

    return DrawerScaffold(
      title: widget.leadId != null
          ? 'Follow-ups for Lead'
          : (_selectedFilter == 'upcoming'
                ? 'Upcoming Follow-ups'
                : 'All Follow-ups'),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadUpcomingFollowUps,
          tooltip: 'Refresh',
        ),
      ],
      body: Column(
        children: [
          // Filter Section
          Container(
            padding: EdgeInsets.all(4.w),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedFilter,
                    decoration: const InputDecoration(
                      labelText: 'Filter',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'upcoming',
                        child: Text('Upcoming'),
                      ),
                      DropdownMenuItem(value: 'newest', child: Text('Newest')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedFilter = value ?? 'upcoming';
                      });
                      _loadUpcomingFollowUps();
                    },
                  ),
                ),
              ],
            ),
          ),
          // Follow-ups List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _upcomingFollowUps.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.schedule_outlined,
                          size: 20.w,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          _selectedFilter == 'upcoming'
                              ? 'No upcoming follow-ups'
                              : 'No follow-ups',
                          style: TextStyles.heading2.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 1.h),
                        Text(
                          _selectedFilter == 'upcoming'
                              ? 'All caught up! 🎉'
                              : 'No follow-ups created yet',
                          style: TextStyles.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: EdgeInsets.all(2.w),
                    child: ListView.builder(
                      itemCount: _upcomingFollowUps.length,
                      itemBuilder: (context, index) {
                        final followUp = _upcomingFollowUps[index];
                        return _buildFollowUpCard(followUp);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowUpCard(FollowUp followUp) {
    final isToday = AppDateUtils.DateUtils.isToday(followUp.dueAt);
    final isPast = followUp.dueAt.isBefore(DateTime.now());
    final isResolved = followUp.isResolved;

    // Get lead information
    final lead = _leadController.getLeadById(followUp.leadId);
    final leadName = lead?.displayName ?? 'Unknown Lead';

    return Card(
      margin: EdgeInsets.only(bottom: 2.h),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _openLeadDetails(lead),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(4.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(leadName, style: TextStyles.heading3)),
                  // Resolution status badge (priority over other badges)
                  if (isResolved)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 2.w,
                        vertical: 0.5.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Text(
                        '✅ Resolved',
                        style: TextStyles.caption.copyWith(color: Colors.green),
                      ),
                    )
                  else if (_selectedFilter == 'upcoming' && isToday)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 2.w,
                        vertical: 0.5.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Text(
                        'Today',
                        style: TextStyles.caption.copyWith(
                          color: Colors.orange,
                        ),
                      ),
                    )
                  else if (_selectedFilter == 'newest')
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 2.w,
                        vertical: 0.5.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue),
                      ),
                      child: Text(
                        'New',
                        style: TextStyles.caption.copyWith(color: Colors.blue),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 1.h),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 4.w,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: 1.w),
                  Text(
                    'Due: ${AppDateUtils.DateUtils.formatRelativeToIST(followUp.dueAt)}',
                    style: TextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isPast ? Colors.red : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              if (isResolved) ...[
                SizedBox(height: 1.h),
                Row(
                  children: [
                    Icon(Icons.check_circle, size: 4.w, color: Colors.green),
                    SizedBox(width: 1.w),
                    Text(
                      'Resolved: ${AppDateUtils.DateUtils.formatMetadataDate(followUp.resolvedAt!)}',
                      style: TextStyles.caption.copyWith(color: Colors.green),
                    ),
                  ],
                ),
                if (followUp.resolutionReason != null) ...[
                  SizedBox(height: 0.5.h),
                  Text(
                    'Reason: ${followUp.resolutionReason}',
                    style: TextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
              if (_selectedFilter == 'newest' && !isResolved) ...[
                SizedBox(height: 1.h),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 4.w,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 1.w),
                    Text(
                      'Created: ${AppDateUtils.DateUtils.formatMetadataDate(followUp.createdAt)}',
                      style: TextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
              if (followUp.note != null && followUp.note!.isNotEmpty) ...[
                SizedBox(height: 1.h),
                Text(
                  followUp.note!,
                  style: TextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              SizedBox(height: 1.h),
              // Action buttons - minimal and desaturated design
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _editFollowUp(followUp),
                      icon: Icon(
                        Icons.edit_outlined,
                        size: 4.w,
                        color: AppColors.primary.withOpacity(0.7),
                      ),
                      label: Text(
                        'Edit',
                        style: TextStyles.body.copyWith(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary.withOpacity(0.7),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 1.2.h),
                        side: BorderSide(
                          color: AppColors.primary.withOpacity(0.9),
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 1.5.w),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showDeleteDialog(followUp),
                      icon: Icon(
                        Icons.delete_outline,
                        size: 4.w,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Delete',
                        style: TextStyles.body.copyWith(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error.withOpacity(0.95),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 1.2.h),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Open lead details screen
  void _openLeadDetails(Lead? lead) {
    if (lead != null) {
      Get.toNamed(Routes.LEAD_DETAIL_SCREEN, arguments: lead);
    } else {
      Get.snackbar(
        'Error',
        'Lead information not found',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Show delete confirmation dialog
  void _showDeleteDialog(FollowUp followUp) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Follow-up',
          style: TextStyles.heading3.copyWith(fontSize: 18.sp),
        ),
        content: Text(
          'Are you sure you want to delete this follow-up?',
          style: TextStyles.body.copyWith(fontSize: 16.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyles.body.copyWith(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteFollowUp(followUp);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Delete',
              style: TextStyles.body.copyWith(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Delete follow-up
  Future<void> _deleteFollowUp(FollowUp followUp) async {
    try {
      final success = await _followUpService.deleteFollowUp(followUp.id);

      if (success) {
        Get.snackbar(
          'Success',
          'Follow-up deleted successfully',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        _loadUpcomingFollowUps(); // Refresh the list
      } else {
        Get.snackbar(
          'Error',
          'Failed to delete follow-up',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Error deleting follow-up: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _editFollowUp(FollowUp followUp) async {
    print('[UI-FollowUpScreen] 📝 Starting edit for follow-up: ${followUp.id}');

    final result = await showDialog<FollowUp>(
      context: context,
      builder: (context) => EditFollowUpDialog(followUp: followUp),
    );

    if (result != null) {
      print('[UI-FollowUpScreen] ✅ Edit completed, refreshing list...');
      print('[UI-FollowUpScreen] - Updated follow-up: ${result.id}');
      print('[UI-FollowUpScreen] - New due date: ${result.dueAt}');
      print('[UI-FollowUpScreen] - New note: ${result.note}');

      // Refresh the list to show updated follow-up
      await _loadUpcomingFollowUps();

      print('[UI-FollowUpScreen] ✅ List refreshed after edit');
    } else {
      print('[UI-FollowUpScreen] ❌ Edit was cancelled or failed');
    }
  }
}
