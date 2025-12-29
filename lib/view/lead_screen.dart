import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sizer/sizer.dart';
import '../controller/lead_controller.dart';
import '../controller/call_controller.dart';
import '../model/lead.dart';
// import '../model/task.dart';
import '../utils/app_colors_new.dart';
import '../utils/text_styles_new.dart';
import '../widgets/toastification.dart';
import '../widgets/base_scaffold.dart';
import 'lead_detail_screen.dart';
import '../services/task_service.dart';

class LeadScreen extends StatefulWidget {
  const LeadScreen({super.key});

  @override
  State<LeadScreen> createState() => _LeadScreenState();
}

class _LeadScreenState extends State<LeadScreen> {
  final LeadController _controller = Get.find<LeadController>();
  final CallController _callController = Get.find<CallController>();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      _controller.setSearchQuery(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DrawerScaffold(
      title: 'Leads',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => _controller.refreshData(),
          tooltip: 'Refresh',
        ),
        IconButton(
          icon: const Icon(Icons.assignment),
          onPressed: () => _showTasksBottomSheet(context),
          tooltip: 'My Tasks',
        ),
        IconButton(
          icon: const Icon(Icons.sync),
          onPressed: () => _controller.forceSync(),
          tooltip: 'Sync',
        ),
        PopupMenuButton<String>(
          onSelected: _handleSortSelection,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'updatedAt',
              child: Text('Sort by Updated'),
            ),
            const PopupMenuItem(value: 'name', child: Text('Sort by Name')),
            const PopupMenuItem(value: 'status', child: Text('Sort by Status')),
            const PopupMenuItem(
              value: 'callStatus',
              child: Text('Sort by Call Status'),
            ),
          ],
        ),
      ],
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: EdgeInsets.all(4.w),
            color: Colors.white,
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search leads...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _controller.setSearchQuery('');
                            },
                          )
                        : null,
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
                SizedBox(height: 2.h),
                // Filter Row
                Row(
                  children: [
                    Expanded(
                      child: Obx(
                        () => DropdownButtonFormField<String>(
                          value: _controller.selectedStatus.isEmpty
                              ? null
                              : _controller.selectedStatus,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('All Status'),
                            ),
                            ..._controller.leadStatusOptions.map(
                              (option) => DropdownMenuItem(
                                value: option.name,
                                child: Text(option.name),
                              ),
                            ),
                          ],
                          onChanged: (value) =>
                              _controller.setStatusFilter(value ?? ''),
                        ),
                      ),
                    ),
                    SizedBox(width: 2.w),
                    Expanded(
                      child: Obx(
                        () => DropdownButtonFormField<String>(
                          value: _controller.selectedCallStatus.isEmpty
                              ? null
                              : _controller.selectedCallStatus,
                          decoration: const InputDecoration(
                            labelText: 'Call Status',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('All Call Status'),
                            ),
                            ..._controller.callStatusOptions.map(
                              (option) => DropdownMenuItem(
                                value: option.name,
                                child: Text(option.name),
                              ),
                            ),
                          ],
                          onChanged: (value) =>
                              _controller.setCallStatusFilter(value ?? ''),
                        ),
                      ),
                    ),
                    SizedBox(width: 2.w),
                    IconButton(
                      icon: const Icon(Icons.filter_list_off),
                      onPressed: () => _controller.clearFilters(),
                      tooltip: 'Clear Filters',
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Statistics Section
          Container(
            padding: EdgeInsets.all(4.w),
            color: AppColors.lightBackground,
            child: Obx(
              () => Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatCard(
                    'Total',
                    _controller.statistics['totalLeads'].toString(),
                    AppColors.primary,
                  ),
                  _buildStatCard(
                    'Contacted',
                    _controller.statistics['contactedLeads'].toString(),
                    Colors.green,
                  ),
                  _buildStatCard(
                    'Follow Up',
                    _controller.statistics['followUpLeads'].toString(),
                    Colors.orange,
                  ),
                  _buildStatCard(
                    'Called',
                    _controller.statistics['calledLeads'].toString(),
                    Colors.blue,
                  ),
                ],
              ),
            ),
          ),
          // Leads List
          Expanded(
            child: Obx(() {
              if (_controller.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              final filteredLeads = _controller.filteredLeads;

              if (filteredLeads.isEmpty) {
                return Center(
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
                );
              }

              return RefreshIndicator(
                onRefresh: () => _controller.refreshData(),
                child: ListView.builder(
                  padding: EdgeInsets.all(2.w),
                  itemCount: filteredLeads.length,
                  itemBuilder: (context, index) {
                    final lead = filteredLeads[index];
                    return _buildLeadCard(lead);
                  },
                ),
              );
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateLeadDialog(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showTasksBottomSheet(BuildContext context) {
    final taskService = Get.find<TaskService>();
    final tasks = taskService.getAllTasks();
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(4.w),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
            SizedBox(height: 2.h),
            Text('My Tasks', style: TextStyles.heading3),
            SizedBox(height: 2.h),
            if (tasks.isEmpty)
              Center(
                child: Text(
                  'No tasks assigned to you.',
                  style: TextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  return Card(
                    margin: EdgeInsets.only(bottom: 1.h),
                    child: ListTile(
                      title: Text(task.title),
                      subtitle: Text(
                        'Due: ${task.dueAt != null ? _formatDate(task.dueAt!) : 'N/A'} - Status: ${task.status}',
                        style: TextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: Icon(Icons.arrow_forward_ios, size: 4.w),
                      onTap: () {
                        Get.back();
                      },
                    ),
                  );
                },
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
                    lead.callStatus,
                    _getCallStatusColor(lead.callStatus),
                  ),
                  const Spacer(),
                  if (lead.needsFollowUp)
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
      default:
        return AppColors.textSecondary;
    }
  }

  Color _getCallStatusColor(String callStatus) {
    switch (callStatus.toLowerCase()) {
      case 'called':
        return Colors.green;
      case 'missed':
        return Colors.red;
      case 'scheduled':
        return Colors.blue;
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _makePhoneCall(Lead lead) async {
    try {
      // Use the same calling mechanism as call_screen.dart
      await _callController.startCallForLead(
        leadId: lead.id,
        phoneNumber: lead.phoneNumber,
      );

      // Update call status to "Called" after initiating call
      _controller.updateCallStatus(lead.id, 'Called');

      print('[LeadScreen] Initiated call to: ${lead.phoneNumber}');
    } catch (e) {
      print('[LeadScreen] Error making call: $e');
      Get.snackbar('Error', 'Failed to make call: $e');
    }
  }

  void _navigateToLeadDetail(Lead lead) {
    Get.to(() => LeadDetailScreen(lead: lead));
  }

  void _handleSortSelection(String sortBy) {
    _controller.setSorting(sortBy);
  }

  void _showCreateLeadDialog() {
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final companyController = TextEditingController();
    final classController = TextEditingController();
    final cityController = TextEditingController();
    final remarkController = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: const Text('Create New Lead'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 2.h),
              TextField(
                controller: lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 2.h),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 2.h),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 2.h),
              TextField(
                controller: companyController,
                decoration: const InputDecoration(
                  labelText: 'Company',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 2.h),
              TextField(
                controller: classController,
                decoration: const InputDecoration(
                  labelText: 'Class',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 2.h),
              TextField(
                controller: cityController,
                decoration: const InputDecoration(
                  labelText: 'City',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 2.h),
              TextField(
                controller: remarkController,
                decoration: const InputDecoration(
                  labelText: 'Remark',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (firstNameController.text.isNotEmpty &&
                  lastNameController.text.isNotEmpty &&
                  phoneController.text.isNotEmpty) {
                _controller.createLead(
                  firstName: firstNameController.text,
                  lastName: lastNameController.text,
                  phoneNumber: phoneController.text,
                  email: emailController.text.isNotEmpty
                      ? emailController.text
                      : null,
                  company: companyController.text.isNotEmpty
                      ? companyController.text
                      : null,
                  class_: classController.text.isNotEmpty
                      ? classController.text
                      : null,
                  city: cityController.text.isNotEmpty
                      ? cityController.text
                      : null,
                  remark: remarkController.text.isNotEmpty
                      ? remarkController.text
                      : null,
                );
                Get.back();
              } else {
                ToastHelper.showErrorToast('Please fill in required fields');
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
