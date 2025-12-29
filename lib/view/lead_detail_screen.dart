import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sizer/sizer.dart';
import '../controller/lead_controller.dart';
import '../controller/call_controller.dart';
import '../model/lead.dart';
import '../model/follow_up.dart';
import '../services/follow_up_service.dart';
import '../widgets/follow_up_dialog.dart';
import '../widgets/edit_follow_up_dialog.dart';
import '../utils/app_colors_new.dart';
import '../utils/text_styles_new.dart';
import '../utils/date_utils.dart' as AppDateUtils;
import '../widgets/toastification.dart';
import 'package:toastification/toastification.dart';
import '../routes/routes.dart';
import '../widgets/global_drawer.dart';

class LeadDetailScreen extends StatefulWidget {
  final Lead lead;
  final bool isFromCallScreen;
  final bool editMode;

  const LeadDetailScreen({
    super.key,
    required this.lead,
    this.isFromCallScreen = false,
    this.editMode = false,
  });

  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen> {
  final LeadController _controller = Get.find<LeadController>();
  final CallController _callController = Get.find<CallController>();
  final FollowUpService _followUpService = Get.find<FollowUpService>();
  final TextEditingController _remarkController = TextEditingController();

  String _selectedStatus = '';
  bool _isEditing = false;
  List<FollowUp> _followUps = [];
  bool _isLoadingFollowUps = false;

  @override
  void initState() {
    super.initState();
    print('[UI-LeadDetailScreen] ===== INITIALIZING =====');
    print('[UI-LeadDetailScreen] 📋 Lead details received:');
    print('[UI-LeadDetailScreen] - ID: ${widget.lead.id}');
    print('[UI-LeadDetailScreen] - Name: ${widget.lead.firstName} ${widget.lead.lastName}');
    print('[UI-LeadDetailScreen] - Phone: ${widget.lead.phoneNumber}');
    print('[UI-LeadDetailScreen] - Status: ${widget.lead.status}');
    print('[UI-LeadDetailScreen] - Call Status: ${widget.lead.callStatus}');
    print('[UI-LeadDetailScreen] - Email: ${widget.lead.email}');
    print('[UI-LeadDetailScreen] - Company: ${widget.lead.company}');

    _selectedStatus = widget.lead.status;
    _remarkController.text = widget.lead.remark ?? '';

    // Set edit mode if specified
    if (widget.editMode) {
      _isEditing = true;
    }

    // Listen for call state changes to refresh data
    _callController.addListener(_onCallStateChanged);

    // Ensure status options are loaded
    _loadStatusOptions();

    // Load follow-ups for this lead
    _loadFollowUps();

    print(
      '[UI-LeadDetailScreen] ✅ Lead detail screen initialized successfully',
    );
  }

  @override
  void dispose() {
    _callController.removeListener(_onCallStateChanged);
    _remarkController.dispose();
    super.dispose();
  }

  void _onCallStateChanged() {
    // Refresh lead data when call state changes
    if (mounted) {
      print(
        '[UI-LeadDetailScreen] 🔄 Call state changed, refreshing lead data...',
      );
      
      // If call ended and we came from call screen, close this screen
      if (widget.isFromCallScreen && _callController.callStartTime.value == null) {
        print(
          '[UI-LeadDetailScreen] Call ended while on lead detail screen from call, closing...',
        );
        // Use a small delay to ensure UI updates are complete
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            Get.back();
          }
        });
        return;
      }
      
      _refreshLeadData();
      _refreshTaskData();
    }
  }

  void _refreshTaskData() {
    // Refresh task data to show updated completion counts for related tasks
    if (mounted) {
      setState(() {
        // Trigger UI rebuild to show updated task completion counts
      });
    }
  }

  /// Load follow-ups for this lead
  Future<void> _loadFollowUps() async {
    if (_isLoadingFollowUps) return;

    setState(() {
      _isLoadingFollowUps = true;
    });

    try {
      print(
        '[UI-LeadDetailScreen] 📋 Loading follow-ups for lead: ${widget.lead.id}',
      );

      final allFollowUps = await _followUpService.getFollowUpsForLead(
        widget.lead.id,
      );

      // Sort follow-ups: upcoming first (by due date), then others
      final now = DateTime.now();
      final nowUTC = now.toUtc();

      // Compare UTC times to avoid timezone issues
      final upcomingFollowUps = allFollowUps.where((followUp) {
        final followUpUTC = followUp.dueAt.toUtc();
        final isAfter = followUpUTC.isAfter(nowUTC);
        return isAfter;
      }).toList();
      final pastFollowUps = allFollowUps
          .where((followUp) => !followUp.dueAt.toUtc().isAfter(nowUTC))
          .toList();

      // Sort upcoming by due date (earliest first)
      upcomingFollowUps.sort((a, b) => a.dueAt.compareTo(b.dueAt));

      // Sort past by due date (most recent first)
      pastFollowUps.sort((a, b) => b.dueAt.compareTo(a.dueAt));

      // Combine: upcoming first, then past
      final sortedFollowUps = [...upcomingFollowUps, ...pastFollowUps];

      if (mounted) {
        setState(() {
          _followUps = sortedFollowUps;
        });
      }

      print(
        '[UI-LeadDetailScreen] ✅ Loaded ${sortedFollowUps.length} follow-ups',
      );
      print('[UI-LeadDetailScreen] - Upcoming: ${upcomingFollowUps.length}');
      print('[UI-LeadDetailScreen] - Past: ${pastFollowUps.length}');
    } catch (e) {
      print('[UI-LeadDetailScreen] ❌ Error loading follow-ups: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFollowUps = false;
        });
      }
    }
  }

  void _refreshLeadData() {
    // Refresh the lead data from the controller
    final updatedLead = _controller.getLeadById(widget.lead.id);
    if (updatedLead != null) {
      setState(() {
        _selectedStatus = updatedLead.status;
        _remarkController.text = updatedLead.remark ?? '';
        // Update the widget's lead object to reflect changes
        // This ensures that other parts of the UI that read from widget.lead also see the updates
        widget.lead.status = updatedLead.status;
        widget.lead.remark = updatedLead.remark;
        widget.lead.updatedAt = updatedLead.updatedAt;
        // Copy other updated fields if needed
        widget.lead.callStatus = updatedLead.callStatus;
        widget.lead.lastContactedAt = updatedLead.lastContactedAt;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh status options when screen becomes visible
    _loadStatusOptions();
  }

  /// Load status options from LeadController
  Future<void> _loadStatusOptions() async {
    print('[UI-LeadDetailScreen] 🔄 Loading status options...');
    try {
      // First, load from local repository
      await _controller.loadStatusOptions();

      print('[UI-LeadDetailScreen] ✅ Status options loaded:');
      print(
        '[UI-LeadDetailScreen] - Lead status options: ${_controller.leadStatusOptions.length}',
      );
      print(
        '[UI-LeadDetailScreen] - Call status options: ${_controller.callStatusOptions.length}',
      );

      // If no status options are available locally, trigger a refresh from server
      if (_controller.leadStatusOptions.isEmpty ||
          _controller.callStatusOptions.isEmpty) {
        print(
          '[UI-LeadDetailScreen] 🔄 No status options found locally, triggering server refresh...',
        );
        await _controller.refreshData();

        // Reload after refresh
        await _controller.loadStatusOptions();

        print('[UI-LeadDetailScreen] ✅ Status options after refresh:');
        print(
          '[UI-LeadDetailScreen] - Lead status options: ${_controller.leadStatusOptions.length}',
        );
        print(
          '[UI-LeadDetailScreen] - Call status options: ${_controller.callStatusOptions.length}',
        );
      }

      // Log the actual options
      print('[UI-LeadDetailScreen] 📋 Lead status options:');
      for (final option in _controller.leadStatusOptions) {
        print('[UI-LeadDetailScreen] - Lead status: ${option.name}');
      }
      print('[UI-LeadDetailScreen] 📋 Call status options:');
      for (final option in _controller.callStatusOptions) {
        print('[UI-LeadDetailScreen] - Call status: ${option.name}');
      }

      // Check for duplicates
      final leadStatusNames = _controller.leadStatusOptions
          .map((o) => o.name)
          .toList();
      final callStatusNames = _controller.callStatusOptions
          .map((o) => o.name)
          .toList();

      final leadDuplicates = leadStatusNames
          .where((name) => leadStatusNames.where((n) => n == name).length > 1)
          .toSet();
      final callDuplicates = callStatusNames
          .where((name) => callStatusNames.where((n) => n == name).length > 1)
          .toSet();

      if (leadDuplicates.isNotEmpty) {
        print(
          '[UI-LeadDetailScreen] ⚠️ Duplicate lead status options found: $leadDuplicates',
        );
      }
      if (callDuplicates.isNotEmpty) {
        print(
          '[UI-LeadDetailScreen] ⚠️ Duplicate call status options found: $callDuplicates',
        );
      }
    } catch (e) {
      print('[UI-LeadDetailScreen] ❌ Error loading status options: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Lead Details", style: TextStyles.appBarTitle),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        // Commented out X button - keeping sidebar icon instead
        // leading: widget.isFromCallScreen
        //     ? IconButton(
        //         icon: const Icon(Icons.close, color: Colors.white),
        //         onPressed: () {
        //           // Close the screen and return to call
        //           Get.back();
        //         },
        //         tooltip: 'Close',
        //       )
        //     : null,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.check : Icons.edit),
            onPressed: _toggleEditing,
            tooltip: _isEditing ? 'Save' : 'Edit',
          ),
          // PopupMenuButton<String>(
          //   onSelected: _handleMenuAction,
          //   itemBuilder: (context) => [
          //     const PopupMenuItem(
          //       value: 'call',
          //       child: Row(
          //         children: [
          //           Icon(Icons.phone, color: AppColors.primary),
          //           SizedBox(width: 8),
          //           Text('Call'),
          //         ],
          //       ),
          //     ),
          //     const PopupMenuItem(
          //       value: 'delete',
          //       child: Row(
          //         children: [
          //           Icon(Icons.delete, color: Colors.red),
          //           SizedBox(width: 8),
          //           Text('Delete'),
          //         ],
          //       ),
          //     ),
          //   ],
          // ),
        ],
      ),
      drawer: const GlobalDrawer(),
      body: Column(
        children: [
          // Back to Call Banner (shown when coming from call screen AND call is active)
          if (widget.isFromCallScreen)
            Obx(() {
              // Only show banner if call is actually active
              if (_callController.callStartTime.value != null) {
                return _buildBackToCallBanner();
              }
              return const SizedBox.shrink();
            }),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(4.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Lead Info Card
                  _buildLeadInfoCard(),
                  SizedBox(height: 3.h),
                  // Status Section
                  _buildStatusSection(),
                  SizedBox(height: 3.h),
                  // Remark Section
                  _buildRemarkSection(),
                  SizedBox(height: 3.h),
                  // Call History Section
                  _buildCallHistorySection(),
                  SizedBox(height: 3.h),
                  // Related Tasks Section
                  // _buildRelatedTasksSection(),
                  // SizedBox(height: 3.h),
                  // Follow-ups Section
                  _buildFollowUpsSection(),
                  SizedBox(height: 3.h),
                  // Metadata Section
                  _buildMetadataSection(),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _makePhoneCall(widget.lead),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.phone, color: Colors.white),
        label: const Text(
          'Call',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            // fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildLeadInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 6.w,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    widget.lead.displayName.isNotEmpty
                        ? widget.lead.displayName[0].toUpperCase()
                        : '?',
                    style: TextStyles.heading2.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
                SizedBox(width: 4.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.lead.displayName, style: TextStyles.heading2),
                      SizedBox(height: 0.5.h),
                      Text(
                        widget.lead.formattedPhoneNumber,
                        style: TextStyles.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (widget.lead.email != null) ...[
                        SizedBox(height: 0.5.h),
                        Text(
                          widget.lead.email!,
                          style: TextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      if (widget.lead.company != null) ...[
                        SizedBox(height: 0.5.h),
                        Text(
                          widget.lead.company!,
                          style: TextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Completion indicator
                if (_isLeadComplete(widget.lead))
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
                      'Completed',
                      style: TextStyles.caption.copyWith(color: Colors.green),
                    ),
                  )
                else if (widget.lead.needsFollowUp)
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
                      'Follow Up',
                      style: TextStyles.caption.copyWith(color: Colors.orange),
                    ),
                  ),
              ],
            ),
            // if (widget.lead.assignedTo != null ||
            //     widget.lead.source != null) ...[
            //   SizedBox(height: 2.h),
            //   Row(
            //     children: [
            //       if (widget.lead.assignedTo != null) ...[
            //         Icon(
            //           Icons.person,
            //           size: 4.w,
            //           color: AppColors.textSecondary,
            //         ),
            //         SizedBox(width: 1.w),
            //         Text(
            //           'Assigned to: ${widget.lead.assignedTo}',
            //           style: TextStyles.caption.copyWith(
            //             color: AppColors.textSecondary,
            //           ),
            //         ),
            //         SizedBox(width: 4.w),
            //       ],
            //       if (widget.lead.source != null) ...[
            //         Icon(
            //           Icons.source,
            //           size: 4.w,
            //           color: AppColors.textSecondary,
            //         ),
            //         SizedBox(width: 1.w),
            //         Text(
            //           'Source: ${widget.lead.source}',
            //           style: TextStyles.caption.copyWith(
            //             color: AppColors.textSecondary,
            //           ),
            //         ),
            //       ],
            //     ],
            //   ),
            // ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Status', style: TextStyles.heading3),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.refresh, size: 4.w),
                  onPressed: _loadStatusOptions,
                  tooltip: 'Refresh status options',
                ),
              ],
            ),
            SizedBox(height: 2.h),
            // Lead Status - Stack vertically to prevent overflow
            Column(
              children: [
                // Lead Status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lead Status',
                      style: TextStyles.body.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    _isEditing
                        ? Obx(() {
                            // Ensure unique items and handle missing values
                            final uniqueOptions = _controller.leadStatusOptions
                                .map((option) => option.name)
                                .toSet()
                                .toList();

                            // If current value is not in options, add it
                            if (!uniqueOptions.contains(_selectedStatus)) {
                              uniqueOptions.insert(0, _selectedStatus);
                            }

                            return DropdownButtonFormField<String>(
                              value: uniqueOptions.contains(_selectedStatus)
                                  ? _selectedStatus
                                  : uniqueOptions.isNotEmpty
                                  ? uniqueOptions.first
                                  : null,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              items: uniqueOptions
                                  .map(
                                    (option) => DropdownMenuItem(
                                      value: option,
                                      child: Text(option),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedStatus = value ?? _selectedStatus;
                                });
                              },
                            );
                          })
                        : Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              horizontal: 3.w,
                              vertical: 1.h,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(
                                _selectedStatus,
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _getStatusColor(_selectedStatus),
                              ),
                            ),
                            child: Text(
                              _selectedStatus,
                              style: TextStyles.body.copyWith(
                                color: _getStatusColor(_selectedStatus),
                              ),
                            ),
                          ),
                  ],
                ),
                SizedBox(height: 2.h),
                // Call Status - Only show when not editing
                if (!_isEditing)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Call Status',
                        style: TextStyles.body.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 1.h),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: 3.w,
                          vertical: 1.h,
                        ),
                        decoration: BoxDecoration(
                          color: _getCallCategoryColor(
                            widget.lead,
                          ).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _getCallCategoryColor(widget.lead),
                          ),
                        ),
                        child: Text(
                          _getCallCategoryLabel(widget.lead),
                          style: TextStyles.body.copyWith(
                            color: _getCallCategoryColor(widget.lead),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemarkSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Remark', style: TextStyles.heading3),
            SizedBox(height: 2.h),
            _isEditing
                ? TextField(
                    controller: _remarkController,
                    style: TextStyles.body.copyWith(fontSize: 16.sp),
                    decoration: InputDecoration(
                      hintText: 'Add a remark...',
                      hintStyle: TextStyles.body.copyWith(
                        fontSize: 16.sp,
                        color: AppColors.textSecondary,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                  )
                : Obx(() {
                    // Reactively observe the leads list to get latest data
                    final leads = _controller.leads;
                    Lead? currentLead;
                    try {
                      currentLead = leads.firstWhere(
                        (l) => l.id == widget.lead.id,
                      );
                    } catch (e) {
                      currentLead = widget.lead;
                    }
                    final currentRemark = currentLead.remark ?? '';

                    return Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(3.w),
                      decoration: BoxDecoration(
                        color: AppColors.lightBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        currentRemark.isNotEmpty
                            ? currentRemark
                            : 'No remark added',
                        style: TextStyles.body.copyWith(
                          color: currentRemark.isNotEmpty
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    );
                  }),
          ],
        ),
      ),
    );
  }

  Widget _buildCallHistorySection() {
    // Show call records for this lead (source of truth: CallRecord)
    final records = _callController.getCallRecordsByNumber(
      widget.lead.phoneNumber,
    );
    final latest = records.length > 4 ? records.sublist(0, 4) : records;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Call History', style: TextStyles.heading3),
            SizedBox(height: 2.h),
            if (records.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.history,
                      size: 8.w,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'No call records yet',
                      style: TextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      'Call this lead to start tracking',
                      style: TextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: latest.length,
                separatorBuilder: (_, __) => SizedBox(height: 1.h),
                itemBuilder: (context, index) {
                  final r = latest[index];
                  final isIncoming = !(r.isOutgoing == true);
                  final status = r.statusText;
                  final time = AppDateUtils.DateUtils.formatCallTime(
                    r.initiatedAt,
                  );
                  return ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 2.w),
                    leading: CircleAvatar(
                      backgroundColor: isIncoming ? Colors.green : Colors.blue,
                      child: Icon(
                        isIncoming ? Icons.call_received : Icons.call_made,
                        color: Colors.white,
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.phoneNumber,
                            style: TextStyles.body.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 2.w,
                            vertical: 0.5.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.lightBackground,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status,
                            style: TextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: EdgeInsets.only(top: 0.5.h),
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 2.w,
                        runSpacing: 0.5.h,
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 12,
                            color: AppColors.textSecondary,
                          ),
                          Text(
                            '${AppDateUtils.DateUtils.formatCallDate(r.initiatedAt)} · $time',
                            style: TextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Icon(
                            Icons.timelapse,
                            size: 12,
                            color: AppColors.textSecondary,
                          ),
                          Text(
                            r.formattedDuration,
                            style: TextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              if (records.length > 4) ...[
                SizedBox(height: 1.h),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Get.toNamed(
                        Routes.CALL_RECORDS_SCREEN,
                        arguments: widget.lead.phoneNumber,
                      );
                    },
                    child: Text(
                      'View all',
                      style: TextStyles.body.copyWith(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFollowUpsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Follow-ups', style: TextStyles.heading3),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.add, size: 4.w),
                  onPressed: _showAddFollowUpDialog,
                  tooltip: 'Add Follow-up',
                ),
                if (_isLoadingFollowUps)
                  SizedBox(
                    width: 4.w,
                    height: 4.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 2.h),
            if (_followUps.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.schedule_outlined,
                      size: 8.w,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'No follow-ups scheduled',
                      style: TextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      'Tap + to schedule a follow-up',
                      style: TextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              // Show only first 5 follow-ups
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _followUps.length > 5 ? 5 : _followUps.length,
                separatorBuilder: (_, __) => SizedBox(height: 1.h),
                itemBuilder: (context, index) {
                  final followUp = _followUps[index];
                  return _buildFollowUpItem(followUp);
                },
              ),
              // Show "View more" button if there are more than 5 follow-ups
              if (_followUps.length > 5) ...[
                SizedBox(height: 1.h),
                Center(
                  child: TextButton(
                    onPressed: () => _openFollowUpScreen(),
                    child: Text(
                      'View more',
                      style: TextStyles.body.copyWith(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  bool _isLeadComplete(Lead lead) {
    // Helper function to normalize status for comparison
    // Handles variations like "un-assigned", "un_assigned", "un assigned", etc.
    String normalizeStatus(String status) {
      if (status.isEmpty) return '';
      return status.toLowerCase().trim().replaceAll(RegExp(r'[-_\s]'), '');
    }

    // Lead is complete if status is NOT "assigned", "assign", "new", "unassigned", "unassigne", or "unassign"
    // Handles variations: "un-assigned", "un_assigned", "un assigned", "UnAssigned", "un-assigne", "un-assign", etc.
    final normalizedStatus = normalizeStatus(lead.status);
    return normalizedStatus != 'assigned' &&
        normalizedStatus != 'assign' &&
        normalizedStatus != 'new' &&
        normalizedStatus != 'unassigned' &&
        normalizedStatus != 'unassigne' &&
        normalizedStatus != 'unassign';
  }

  Widget _buildFollowUpItem(FollowUp followUp) {
    final isOverdue =
        followUp.dueAt.isBefore(DateTime.now()) && followUp.isPending;
    // final isToday =
    //     followUp.dueAt.day == DateTime.now().day &&
    //     followUp.dueAt.month == DateTime.now().month &&
    //     followUp.dueAt.year == DateTime.now().year;

    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: AppColors.lightBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getFollowUpStatusColor(followUp.status),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Minimal status indicator: colored dot + tooltip
              Tooltip(
                message: followUp.statusText,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _getFollowUpStatusColor(followUp.status),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: Text(
                  followUp.formattedDueDate,
                  style: TextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isOverdue ? Colors.red : AppColors.textPrimary,
                  ),
                ),
              ),
              // Action buttons: Edit and Delete
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blueAccent),
                tooltip: 'Edit follow-up',
                onPressed: () async {
                  final result = await showDialog<FollowUp>(
                    context: context,
                    builder: (context) =>
                        EditFollowUpDialog(followUp: followUp),
                  );

                  if (result != null) {
                    // Refresh follow-ups list
                    await _loadFollowUps();
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                tooltip: 'Delete follow-up',
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Follow-up'),
                      content: const Text(
                        'Are you sure you want to delete this follow-up?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text(
                            'Delete',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm != true) return;
                  try {
                    await _followUpService.deleteFollowUp(followUp.id);
                    await _loadFollowUps();
                    ToastHelper.showToast(
                      context: context,
                      message: 'Follow-up deleted',
                      type: ToastificationType.success,
                    );
                  } catch (e) {
                    ToastHelper.showToast(
                      context: context,
                      message: 'Failed to delete follow-up',
                      type: ToastificationType.error,
                    );
                  }
                },
              ),
            ],
          ),
          if (followUp.note != null && followUp.note!.isNotEmpty) ...[
            SizedBox(height: 1.h),
            Text(
              followUp.note!,
              style: TextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          // Removed explicit overdue/due-today warnings; status is indicated by icon/color
        ],
      ),
    );
  }

  Color _getFollowUpStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Colors.blue;
      case 'DONE':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      default:
        return AppColors.textSecondary;
    }
  }

  // Removed icon mapping; using a minimal colored dot indicator instead

  void _showAddFollowUpDialog() async {
    final result = await showDialog<FollowUp>(
      context: context,
      builder: (context) => FollowUpDialog(lead: widget.lead),
    );

    if (result != null) {
      // Refresh follow-ups list
      _loadFollowUps();

      // Note: Success toast is already shown by FollowUpDialog, no need to show another one
    }
  }

  /// Open follow-up screen filtered by lead ID
  void _openFollowUpScreen() {
    Get.toNamed(Routes.FOLLOW_UP_SCREEN, arguments: widget.lead.id);
  }

  Widget _buildMetadataSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Details', style: TextStyles.heading3),
            SizedBox(height: 2.h),
            _buildMetadataRow(
              'Created',
              AppDateUtils.DateUtils.formatMetadataDate(widget.lead.createdAt),
            ),
            _buildMetadataRow(
              'Updated',
              AppDateUtils.DateUtils.formatMetadataDate(widget.lead.updatedAt),
            ),
            if (widget.lead.lastContactedAt != null)
              _buildMetadataRow(
                'Last Contacted',
                AppDateUtils.DateUtils.formatMetadataDate(
                  widget.lead.lastContactedAt!,
                ),
              ),
            _buildMetadataRow('Priority', widget.lead.priorityText),
            _buildMetadataRow(
              'Sync Status',
              widget.lead.isSynced ? 'Synced' : 'Pending',
            ),
            if (widget.lead.syncedAt != null)
              _buildMetadataRow(
                'Last Synced',
                AppDateUtils.DateUtils.formatMetadataDate(
                  widget.lead.syncedAt!,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 0.5.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 30.w,
            child: Text(
              label,
              style: TextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Text(value, style: TextStyles.caption)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'contacted':
        return Colors.green;
      case 'not interested':
        return Colors.red;
      case 'follow up':
        return Colors.orange;
      case 'qualified':
        return Colors.blue;
      case 'converted':
        return Colors.purple;
      default:
        return AppColors.textSecondary;
    }
  }

  // Categorized call status helpers
  Color _getCallCategoryColor(Lead lead) {
    final category = lead.callStatusCategory.toUpperCase();
    switch (category) {
      case 'CONTACTED':
        return Colors.green;
      case 'CALLED':
        return Colors.blue;
      case 'NO ANSWER':
        return Colors.red;
      case 'NOT CONTACTED':
        return AppColors.textSecondary;
      default:
        return AppColors.textSecondary;
    }
  }

  String _getCallCategoryLabel(Lead lead) {
    switch (lead.callStatusCategory.toUpperCase()) {
      case 'CONTACTED':
        return 'Contacted';
      case 'CALLED':
        return 'Called';
      case 'NO ANSWER':
        return 'No Answer';
      case 'NOT CONTACTED':
        return 'Not Contacted';
      default:
        return lead.callStatus;
    }
  }

  void _toggleEditing() {
    if (_isEditing) {
      // Save changes
      _saveChanges();
    } else {
      // Start editing - refresh status options first
      _loadStatusOptions().then((_) {
        setState(() {
          _isEditing = true;
        });
      });
    }
  }

  void _saveChanges() async {
    bool hasChanges = false;

    // Check if status changed
    if (_selectedStatus != widget.lead.status) {
      await _controller.updateLeadStatus(widget.lead.id, _selectedStatus);
      hasChanges = true;
    }

    // Check if remark changed
    if (_remarkController.text != (widget.lead.remark ?? '')) {
      await _controller.updateLeadRemark(
        widget.lead.id,
        _remarkController.text,
      );
      hasChanges = true;
    }

    if (hasChanges) {
      // Wait a bit for controller to update
      await Future.delayed(const Duration(milliseconds: 100));

      // Refresh lead data after saving changes
      _refreshLeadData();

      ToastHelper.showToast(
        context: context,
        message: 'Changes saved successfully',
        type: ToastificationType.success,
      );
    }

    setState(() {
      _isEditing = false;
    });
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'call':
        _makePhoneCall(widget.lead);
        break;
      case 'delete':
        _showDeleteConfirmation();
        break;
    }
  }

  void _makePhoneCall(Lead lead) async {
    try {
      // Use the same calling mechanism as call_screen.dart
      await _callController.startCallForLead(
        leadId: lead.id,
        phoneNumber: lead.phoneNumber,
      );
      // Refresh lead data to show latest information
      _refreshLeadData();

      print('[LeadDetailScreen] Initiated call to: ${lead.phoneNumber}');
    } catch (e) {
      print('[LeadDetailScreen] Error making call: $e');
      Get.snackbar('Error', 'Failed to make call: $e');
    }
  }

  void _showDeleteConfirmation() {
    Get.dialog(
      AlertDialog(
        title: const Text('Delete Lead'),
        content: Text(
          'Are you sure you want to delete ${widget.lead.displayName}?',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              _controller.deleteLead(widget.lead.id);
              Get.back(); // Close dialog
              Get.back(); // Go back to leads list
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Build the "Back to Call" banner that appears when navigating from call screen
  Widget _buildBackToCallBanner() {
    return InkWell(
      onTap: _returnToCallScreen,
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

  /// Return to the active call screen
  Future<void> _returnToCallScreen() async {
    try {
      final bool success = await _callController.returnToCallScreen();
      if (!success) {
        Get.snackbar(
          'No Active Call',
          'There is no active call to return to',
          snackPosition: SnackPosition.TOP,
        );
      }
    } catch (e) {
      print('[LeadDetailScreen] Error returning to call screen: $e');
      Get.snackbar(
        'Error',
        'Failed to return to call screen: $e',
        snackPosition: SnackPosition.TOP,
      );
    }
  }
}
