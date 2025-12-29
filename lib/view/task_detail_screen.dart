import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sizer/sizer.dart';
import '../model/task.dart';
import '../model/lead.dart';
import '../utils/app_colors_new.dart';
import '../utils/text_styles_new.dart';
import '../widgets/base_scaffold.dart';
import '../repository/lead_repository.dart';
import '../services/api_service.dart';
import '../controller/call_controller.dart';
import '../controller/task_controller.dart';
import '../controller/lead_controller.dart';
import '../services/task_sync_service.dart';
import '../routes/routes.dart';

class TaskDetailScreen extends StatefulWidget {
  final Task task;

  const TaskDetailScreen({super.key, required this.task});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final LeadRepository _leadRepo = LeadRepository.instance;
  final ApiService _apiService = Get.find<ApiService>();
  final CallController _callController = Get.find<CallController>();
  final TaskSyncService _taskSyncService = Get.find<TaskSyncService>();
  final LeadController _leadController = Get.find<LeadController>();

  List<Lead> _relatedLeads = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedStatus = '';
  String _selectedCallStatus = '';

  @override
  void initState() {
    super.initState();
    print('[UI-TaskDetailScreen] ===== INITIALIZING =====');
    print('[UI-TaskDetailScreen] Task details:');
    print('[UI-TaskDetailScreen] - ID: ${widget.task.id}');
    print('[UI-TaskDetailScreen] - Title: ${widget.task.title}');
    print('[UI-TaskDetailScreen] - LeadId: ${widget.task.leadId}');
    print(
      '[UI-TaskDetailScreen] - RelatedLeadIds: ${widget.task.relatedLeadIds}',
    );
    print(
      '[UI-TaskDetailScreen] - RelatedLeadIds count: ${widget.task.relatedLeadIds?.length ?? 0}',
    );
    print('[UI-TaskDetailScreen] Starting to load related leads...');

    // Listen for call state changes to refresh data
    _callController.addListener(_onCallStateChanged);

    // Load status options from database
    _loadStatusOptions();

    _loadRelatedLeads();
  }

  @override
  void dispose() {
    _callController.removeListener(_onCallStateChanged);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh status options when screen becomes visible
    _loadStatusOptions();
  }

  void _onCallStateChanged() {
    // Refresh leads when call state changes
    if (mounted) {
      print('[UI-TaskDetailScreen] 🔄 Call state changed, refreshing leads...');
      _loadRelatedLeads();
      _refreshTaskData();
    }
  }

  void _refreshTaskData() {
    // Refresh task data to show updated completion counts
    if (mounted) {
      setState(() {
        // Trigger UI rebuild to show updated task completion counts
      });

      // Also refresh the task data from TaskController to get latest completion counts
      if (Get.isRegistered<TaskController>()) {
        final taskController = Get.find<TaskController>();
        final updatedTask = taskController.getTaskById(widget.task.id);
        if (updatedTask != null) {
          // Update the widget's task with latest data
          widget.task.completedCount = updatedTask.completedCount;
          widget.task.totalCount = updatedTask.totalCount;
          widget.task.status = updatedTask.status;
        }
      }
    }
  }

  /// Load status options from LeadController
  Future<void> _loadStatusOptions() async {
    print('[UI-TaskDetailScreen] 🔄 Loading status options...');
    try {
      // Load status options from LeadController
      await _leadController.loadStatusOptions();

      print('[UI-TaskDetailScreen] ✅ Status options loaded:');
      print(
        '[UI-TaskDetailScreen] - Lead status options: ${_leadController.leadStatusOptions.length}',
      );
      print(
        '[UI-TaskDetailScreen] - Call status options: ${_leadController.callStatusOptions.length}',
      );

      // If no status options are available locally, trigger a refresh from server
      if (_leadController.leadStatusOptions.isEmpty ||
          _leadController.callStatusOptions.isEmpty) {
        print(
          '[UI-TaskDetailScreen] 🔄 No status options found locally, triggering server refresh...',
        );
        await _leadController.refreshData();

        // Reload after refresh
        await _leadController.loadStatusOptions();

        print('[UI-TaskDetailScreen] ✅ Status options after refresh:');
        print(
          '[UI-TaskDetailScreen] - Lead status options: ${_leadController.leadStatusOptions.length}',
        );
        print(
          '[UI-TaskDetailScreen] - Call status options: ${_leadController.callStatusOptions.length}',
        );
      }
    } catch (e) {
      print('[UI-TaskDetailScreen] ❌ Error loading status options: $e');
    }
  }

  Future<void> _syncTaskProgress() async {
    try {
      print('[TaskDetailScreen] Starting task progress sync...');

      setState(() {
        _isLoading = true;
      });

      // Sync progress for this specific task
      final success = await _taskSyncService.syncTaskProgressForTask(
        widget.task.id,
      );

      if (success) {
        print('[TaskDetailScreen] Task progress sync successful');
        // Get.snackbar(
        //   'Success',
        //   'Task progress synced successfully!',
        //   snackPosition: SnackPosition.TOP,
        //   backgroundColor: Colors.green,
        //   colorText: Colors.white,
        // );

        // Refresh the leads to show updated data
        await _loadRelatedLeads();

        // Refresh task data to show updated completion counts
        _refreshTaskData();
      } else {
        print('[TaskDetailScreen] Task progress sync failed');
        // Get.snackbar(
        //   'Error',
        //   'Failed to sync task progress. Please try again.',
        //   snackPosition: SnackPosition.TOP,
        //   backgroundColor: Colors.red,
        //   colorText: Colors.white,
        // );
      }
    } catch (e) {
      print('[TaskDetailScreen] Error syncing task progress: $e');
      // Get.snackbar(
      //   'Error',
      //   'Failed to sync task progress: $e',
      //   snackPosition: SnackPosition.TOP,
      //   backgroundColor: Colors.red,
      //   colorText: Colors.white,
      // );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadRelatedLeads() async {
    print('[UI-TaskDetailScreen] ===== LOADING RELATED LEADS =====');

    if (widget.task.relatedLeadIds == null ||
        widget.task.relatedLeadIds!.isEmpty) {
      print('[UI-TaskDetailScreen] ❌ No related lead IDs found');
      return;
    }

    print(
      '[UI-TaskDetailScreen] 📋 Loading ${widget.task.relatedLeadIds!.length} related leads',
    );

    setState(() {
      _isLoading = true;
    });

    final List<Lead> leads = [];

    for (final leadId in widget.task.relatedLeadIds!) {
      try {
        print('[UI-TaskDetailScreen] 🔍 Processing lead ID: $leadId');

        // Check if lead exists locally
        final localLead = _leadRepo.getLead(leadId);
        print(
          '[UI-TaskDetailScreen] 💾 Local lead found: ${localLead != null}',
        );
        if (localLead != null) {
          print('[UI-TaskDetailScreen] 💾 Local lead name: ${localLead.firstName} ${localLead.lastName}');
        }

        if (localLead != null) {
          // Lead exists locally, check if we need to sync
          final shouldSync = await _shouldSyncLead(localLead);
          print('[UI-TaskDetailScreen] 🔄 Should sync lead: $shouldSync');

          if (shouldSync) {
            // Fetch from server and compare timestamps
            print('[UI-TaskDetailScreen] 🌐 Fetching lead from server...');
            final serverLead = await _fetchLeadFromServer(leadId);
            if (serverLead != null) {
              // Use the latest version based on updatedAt
              final latestLead = _getLatestLead(localLead, serverLead);
              await _leadRepo.saveLead(latestLead);
              // Recalculate task completion for this lead
              await _recalculateTaskCompletionForLead(latestLead.id);
              leads.add(latestLead);
              print(
                '[UI-TaskDetailScreen] ✅ Added synced lead: ${latestLead.firstName} ${latestLead.lastName}',
              );
            } else {
              leads.add(localLead);
              print(
                '[UI-TaskDetailScreen] ⚠️ Added local lead (server fetch failed): ${localLead.firstName} ${localLead.lastName}',
              );
            }
          } else {
            leads.add(localLead);
            print(
              '[UI-TaskDetailScreen] ✅ Added local lead (no sync needed): ${localLead.firstName} ${localLead.lastName}',
            );
          }
        } else {
          // Lead doesn't exist locally, fetch from server
          print(
            '[UI-TaskDetailScreen] 🌐 Lead not found locally, fetching from server...',
          );
          final serverLead = await _fetchLeadFromServer(leadId);
          if (serverLead != null) {
            await _leadRepo.saveLead(serverLead);
            // Recalculate task completion for this lead
            await _recalculateTaskCompletionForLead(serverLead.id);
            leads.add(serverLead);
            print(
              '[UI-TaskDetailScreen] ✅ Added server lead: ${serverLead.firstName} ${serverLead.lastName}',
            );
          } else {
            print(
              '[UI-TaskDetailScreen] ❌ Failed to fetch lead from server, creating stub...',
            );
            // Create a stub lead if server fetch fails
            final stubLead = Lead(
              id: leadId,
              firstName: 'Unknown',
              lastName: 'Lead (Offline)',
              phoneNumber: '',
              status: 'Unknown',
              callStatus: 'Not Called',
            );
            await _leadRepo.saveLead(stubLead);
            leads.add(stubLead);
            print('[UI-TaskDetailScreen] 🔧 Added stub lead: ${stubLead.firstName} ${stubLead.lastName}');
          }
        }
      } catch (e) {
        print('[UI-TaskDetailScreen] ❌ Error loading lead $leadId: $e');
        // Create a stub lead for this ID
        final stubLead = Lead(
          id: leadId,
          firstName: 'Error',
          lastName: 'Loading Lead',
          phoneNumber: '',
          status: 'Unknown',
          callStatus: 'Not Called',
        );
        leads.add(stubLead);
        print(
          '[UI-TaskDetailScreen] 🔧 Added error stub lead: ${stubLead.firstName} ${stubLead.lastName}',
        );
      }
    }

    print('[UI-TaskDetailScreen] ===== LOADING COMPLETE =====');
    print('[UI-TaskDetailScreen] 📊 Loaded ${leads.length} leads total');
    for (int i = 0; i < leads.length; i++) {
      print(
        '[UI-TaskDetailScreen] 📋 Lead $i: ${leads[i].firstName} ${leads[i].lastName} (${leads[i].id})',
      );
    }

    setState(() {
      _relatedLeads = leads;
      _isLoading = false;
    });
  }

  Future<bool> _shouldSyncLead(Lead localLead) async {
    print(
      '[SERVICE-TaskDetailScreen] 🔄 Checking if lead needs sync: ${localLead.firstName} ${localLead.lastName}',
    );

    // Always sync to ensure we have the latest data from server
    // This prevents stale local data from being displayed
    print(
      '[SERVICE-TaskDetailScreen] ⏰ Force syncing lead to get latest server data',
    );
    return true;
  }

  Future<Lead?> _fetchLeadFromServer(String leadId) async {
    print('[SERVICE-TaskDetailScreen] 🌐 Fetching lead from server: $leadId');
    try {
      final response = await _apiService.getLeadById(leadId);
      print(
        '[SERVICE-TaskDetailScreen] 🌐 API Response - Success: ${response.isSuccess}',
      );
      if (response.isSuccess && response.data != null) {
        print(
          '[SERVICE-TaskDetailScreen] ✅ Server lead fetched: ${response.data!.firstName} ${response.data!.lastName}',
        );
        return response.data!;
      } else {
        print(
          '[SERVICE-TaskDetailScreen] ❌ Server lead fetch failed: ${response.error}',
        );
      }
    } catch (e) {
      print(
        '[SERVICE-TaskDetailScreen] ❌ Exception fetching lead from server: $e',
      );
    }
    return null;
  }

  Lead _getLatestLead(Lead localLead, Lead serverLead) {
    print('[SERVICE-TaskDetailScreen] 🔄 Comparing leads:');
    print(
      '[SERVICE-TaskDetailScreen] 📅 Local: ${localLead.firstName} ${localLead.lastName} (${localLead.updatedAt})',
    );
    print(
      '[SERVICE-TaskDetailScreen] 📅 Server: ${serverLead.firstName} ${serverLead.lastName} (${serverLead.updatedAt})',
    );

    // Compare updatedAt timestamps to determine which is latest
    if (serverLead.updatedAt.isAfter(localLead.updatedAt)) {
      print(
        '[SERVICE-TaskDetailScreen] ✅ Server lead is newer, using server version: ${serverLead.firstName} ${serverLead.lastName}',
      );
      return serverLead;
    } else {
      print(
        '[SERVICE-TaskDetailScreen] ✅ Local lead is newer, using local version: ${localLead.firstName} ${localLead.lastName}',
      );
      return localLead;
    }
  }

  List<Lead> get _filteredLeads {
    var leads = _relatedLeads;

    if (_searchQuery.isNotEmpty) {
      leads = leads
          .where(
            (lead) =>
                lead.firstName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                lead.lastName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                lead.phoneNumber.contains(_searchQuery) ||
                (lead.email?.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ??
                    false) ||
                (lead.company?.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ??
                    false),
          )
          .toList();
    }

    if (_selectedStatus.isNotEmpty) {
      leads = leads.where((lead) => lead.status == _selectedStatus).toList();
    }

    if (_selectedCallStatus.isNotEmpty) {
      leads = leads
          .where((lead) => lead.callStatus == _selectedCallStatus)
          .toList();
    }

    return leads;
  }

  @override
  Widget build(BuildContext context) {
    print('[UI-TaskDetailScreen] ===== BUILDING UI =====');
    print('[UI-TaskDetailScreen] 📊 Current state:');
    print('[UI-TaskDetailScreen] - isLoading: $_isLoading');
    print(
      '[UI-TaskDetailScreen] - relatedLeads count: ${_relatedLeads.length}',
    );
    print('[UI-TaskDetailScreen] - searchQuery: "$_searchQuery"');
    print('[UI-TaskDetailScreen] - selectedStatus: "$_selectedStatus"');
    print('[UI-TaskDetailScreen] - selectedCallStatus: "$_selectedCallStatus"');

    return DrawerScaffold(
      title: 'Task Details',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadRelatedLeads,
          tooltip: 'Refresh',
        ),
        IconButton(
          icon: const Icon(Icons.sync),
          onPressed: _syncTaskProgress,
          tooltip: 'Sync Task Progress',
        ),
      ],
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Task Details Section
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: EdgeInsets.all(4.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Task Information', style: TextStyles.heading3),
                  SizedBox(height: 2.h),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(4.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.assignment,
                                color: (widget.task.priority >= 3)
                                    ? Colors.red
                                    : AppColors.primary,
                              ),
                              SizedBox(width: 2.w),
                              Expanded(
                                child: Text(
                                  widget.task.title,
                                  style: TextStyles.heading3,
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
                                  widget.task.status,
                                  style: TextStyles.caption,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 1.h),
                          if (widget.task.description != null &&
                              widget.task.description!.isNotEmpty) ...[
                            Text(
                              widget.task.description!,
                              style: TextStyles.body,
                            ),
                            SizedBox(height: 1.h),
                          ],
                          Row(
                            children: [
                              Icon(
                                Icons.event,
                                size: 4.w,
                                color: AppColors.textSecondary,
                              ),
                              SizedBox(width: 1.w),
                              Text(
                                widget.task.dueAt != null
                                    ? 'Due: ${_formatDate(widget.task.dueAt!)}'
                                    : 'No due date',
                                style: TextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const Spacer(),
                              if (widget.task.completedCount != null ||
                                  widget.task.totalCount != null) ...[
                                Icon(
                                  Icons.trending_up,
                                  size: 4.w,
                                  color: AppColors.textSecondary,
                                ),
                                SizedBox(width: 1.w),
                                Text(
                                  '${widget.task.completedCount ?? 0}/${widget.task.totalCount ?? 0}',
                                  style: TextStyles.caption.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                // Show completion percentage
                                if (widget.task.totalCount != null &&
                                    widget.task.totalCount! > 0) ...[
                                  SizedBox(width: 1.w),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 1.w,
                                      vertical: 0.2.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getCompletionColor(),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${((widget.task.completedCount ?? 0) / widget.task.totalCount! * 100).round()}%',
                                      style: TextStyles.caption.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Search and Filter Section
            Container(
              padding: EdgeInsets.all(4.w),
              color: Colors.white,
              child: Column(
                children: [
                  // Search Bar
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          style: TextStyles.body.copyWith(fontSize: 16.sp),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search leads...',
                            hintStyle: TextStyles.body.copyWith(
                              fontSize: 16.sp,
                              color: AppColors.textSecondary,
                            ),
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppColors.primary),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 2.w),
                      IconButton(
                        icon: Icon(Icons.refresh, size: 4.w),
                        onPressed: _loadStatusOptions,
                        tooltip: 'Refresh status options',
                      ),
                    ],
                  ),
                  SizedBox(height: 2.h),
                  // Filter Row
                  Row(
                    children: [
                      Expanded(
                        child: Obx(() {
                          // Get unique lead status options from database
                          final uniqueOptions = _leadController
                              .leadStatusOptions
                              .map((option) => option.name)
                              .toSet()
                              .toList();

                          // Add "All Status" option at the beginning
                          final allOptions = ['', ...uniqueOptions];

                          return DropdownButtonFormField<String>(
                            value: allOptions.contains(_selectedStatus)
                                ? _selectedStatus
                                : allOptions.isNotEmpty
                                ? allOptions.first
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items: allOptions
                                .map(
                                  (option) => DropdownMenuItem(
                                    value: option,
                                    child: Text(
                                      option.isEmpty ? 'All Status' : option,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedStatus = value ?? '';
                              });
                            },
                          );
                        }),
                      ),
                      SizedBox(width: 2.w),
                      // Expanded(
                      //   child: DropdownButtonFormField<String>(
                      //     value: _selectedCallStatus.isEmpty
                      //         ? null
                      //         : _selectedCallStatus,
                      //     decoration: const InputDecoration(
                      //       labelText: 'Call Status',
                      //       border: OutlineInputBorder(),
                      //       contentPadding: EdgeInsets.symmetric(
                      //         horizontal: 12,
                      //         vertical: 8,
                      //       ),
                      //     ),
                      //     items: [
                      //       const DropdownMenuItem(
                      //         value: '',
                      //         child: Text('All Call Status'),
                      //       ),
                      //       const DropdownMenuItem(
                      //         value: 'Called',
                      //         child: Text('Called'),
                      //       ),
                      //       const DropdownMenuItem(
                      //         value: 'Not Called',
                      //         child: Text('Not Called'),
                      //       ),
                      //       const DropdownMenuItem(
                      //         value: 'Missed',
                      //         child: Text('Missed'),
                      //       ),
                      //     ],
                      //     onChanged: (value) {
                      //       setState(() {
                      //         _selectedCallStatus = value ?? '';
                      //       });
                      //     },
                      //   ),
                      // ),
                      // SizedBox(width: 2.w),
                      IconButton(
                        icon: const Icon(Icons.filter_list_off),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _selectedStatus = '';
                            _selectedCallStatus = '';
                          });
                        },
                        tooltip: 'Clear Filters',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Statistics Section
            // Container(
            //   padding: EdgeInsets.all(4.w),
            //   color: AppColors.lightBackground,
            //   child: Row(
            //     mainAxisAlignment: MainAxisAlignment.spaceAround,
            //     children: [
            //       _buildStatCard(
            //         'Total',
            //         _relatedLeads.length.toString(),
            //         AppColors.primary,
            //       ),
            //       _buildStatCard(
            //         'Contacted',
            //         _relatedLeads
            //             .where((l) => l.status == 'contacted')
            //             .length
            //             .toString(),
            //         Colors.green,
            //       ),
            //       _buildStatCard(
            //         'Assigned',
            //         _relatedLeads
            //             .where((l) => l.status == 'assigned')
            //             .length
            //             .toString(),
            //         Colors.blue,
            //       ),
            //       _buildStatCard(
            //         'Called',
            //         _relatedLeads
            //             .where((l) => l.callStatus == 'Called')
            //             .length
            //             .toString(),
            //         Colors.orange,
            //       ),
            //     ],
            //   ),
            // ),
            // // Leads List
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_filteredLeads.isEmpty)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 20.w,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'No leads found',
                      style: TextStyles.heading2.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      'Try adjusting your search or filters',
                      style: TextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: EdgeInsets.all(2.w),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredLeads.length,
                  itemBuilder: (context, index) {
                    final lead = _filteredLeads[index];
                    return _buildLeadCard(lead);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(value, style: TextStyles.heading2.copyWith(color: color)),
          SizedBox(height: 0.5.h),
          Text(
            label,
            style: TextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadCard(Lead lead) {
    return Card(
      margin: EdgeInsets.only(bottom: 2.h),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToLeadDetail(lead),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(4.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lead.displayName, style: TextStyles.heading3),
                        SizedBox(height: 0.5.h),
                        Text(
                          lead.formattedPhoneNumber,
                          style: TextStyles.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (lead.company != null) ...[
                          SizedBox(height: 0.5.h),
                          Text(
                            lead.company!,
                            style: TextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.phone, color: AppColors.primary),
                    onPressed: () => _makePhoneCall(lead),
                    tooltip: 'Call',
                  ),
                ],
              ),
              SizedBox(height: 2.h),
              // Status Row
              Row(
                children: [
                  _buildStatusChip(lead.status, _getStatusColor(lead.status)),
                  SizedBox(width: 2.w),
                  _buildStatusChip(
                    _getCallCategoryLabel(lead),
                    _getCallCategoryColor(lead),
                  ),
                  const Spacer(),
                  if (_isLeadComplete(lead))
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
                  else if (lead.needsFollowUp)
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
                        style: TextStyles.caption.copyWith(
                          color: Colors.orange,
                        ),
                      ),
                    ),
                ],
              ),
              if (lead.remark != null && lead.remark!.isNotEmpty) ...[
                SizedBox(height: 1.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(2.w),
                  decoration: BoxDecoration(
                    color: AppColors.lightBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(lead.remark!, style: TextStyles.caption),
                ),
              ],
              SizedBox(height: 1.h),
              // Footer Row
              Row(
                children: [
                  Text(
                    'Updated: ${_formatDate(lead.updatedAt)}',
                    style: TextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  if (!lead.isSynced)
                    Icon(Icons.sync_problem, size: 4.w, color: Colors.orange),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(status, style: TextStyles.caption.copyWith(color: color)),
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
      case 'assigned':
        return Colors.blue;
      default:
        return AppColors.textSecondary;
    }
  }

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
        return lead.callStatus; // fallback to raw if unknown
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getCompletionColor() {
    if (widget.task.totalCount == null || widget.task.totalCount! == 0) {
      return AppColors.textSecondary;
    }

    final percentage =
        (widget.task.completedCount ?? 0) / widget.task.totalCount!;

    if (percentage >= 1.0) {
      return Colors.green; // Completed
    } else if (percentage >= 0.8) {
      return Colors.blue; // Almost done
    } else if (percentage >= 0.5) {
      return Colors.orange; // Half done
    } else {
      return Colors.red; // Just started
    }
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

  void _makePhoneCall(Lead lead) async {
    try {
      await _callController.startCallForLead(
        leadId: lead.id,
        phoneNumber: lead.phoneNumber,
      );
      print('[TaskDetailScreen] Initiated call to: ${lead.phoneNumber}');

      // Refresh data after making call to show latest information
      _loadRelatedLeads();
    } catch (e) {
      print('[TaskDetailScreen] Error making call: $e');
      // Get.snackbar('Error', 'Failed to make call: $e');
    }
  }

  Future<void> _navigateToLeadDetail(Lead lead) async {
    print('[UI-TaskDetailScreen] 🚀 Navigating to lead detail screen');
    print('[UI-TaskDetailScreen] 📋 Lead details:');
    print('[UI-TaskDetailScreen] - ID: ${lead.id}');
    print('[UI-TaskDetailScreen] - Name: ${lead.firstName} ${lead.lastName}');
    print('[UI-TaskDetailScreen] - Phone: ${lead.phoneNumber}');
    print('[UI-TaskDetailScreen] - Status: ${lead.status}');
    print('[UI-TaskDetailScreen] - Call Status: ${lead.callStatus}');

    try {
      await Get.toNamed(Routes.LEAD_DETAIL_SCREEN, arguments: lead);
      print('[UI-TaskDetailScreen] ✅ Returned from lead detail, refreshing');
      await _recalculateTaskCompletionForLead(lead.id);
      await _loadRelatedLeads();
      setState(() {});
    } catch (e) {
      print('[UI-TaskDetailScreen] ❌ Navigation failed: $e');
      // Get.snackbar('Error', 'Failed to navigate to lead details: $e');
    }
  }

  /// Recalculate task completion for a lead
  Future<void> _recalculateTaskCompletionForLead(String leadId) async {
    try {
      if (Get.isRegistered<TaskController>()) {
        final taskController = Get.find<TaskController>();
        await taskController.recalculateTaskCompletionForLead(leadId);

        // Update the widget's task with latest completion data
        final updatedTask = taskController.getTaskById(widget.task.id);
        if (updatedTask != null) {
          widget.task.completedCount = updatedTask.completedCount;
          widget.task.totalCount = updatedTask.totalCount;
          widget.task.status = updatedTask.status;
        }

        print(
          '[TaskDetailScreen] ✅ Recalculated task completion for lead: $leadId',
        );
      }
    } catch (e) {
      print(
        '[TaskDetailScreen] ❌ Error recalculating task completion for lead $leadId: $e',
      );
    }
  }
}
