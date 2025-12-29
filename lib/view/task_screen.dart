import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sizer/sizer.dart';
import '../utils/app_colors_new.dart';
import '../utils/text_styles_new.dart';
import '../widgets/base_scaffold.dart';
import '../controller/task_controller.dart';
import '../controller/call_controller.dart';
import '../services/task_sync_service.dart';
import '../routes/routes.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  final TaskController _controller = Get.find<TaskController>();
  final CallController _callController = Get.find<CallController>();
  final TaskSyncService _taskSyncService = Get.find<TaskSyncService>();

  @override
  void initState() {
    super.initState();
    // Listen for call state changes to refresh data
    _callController.addListener(_onCallStateChanged);
    // Load tasks if not already loaded (e.g., after login)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.tasks.isEmpty && !_controller.isLoading.value) {
        _controller.loadTasksPaginated();
      }
      // Recalculate task completions on screen load to ensure accuracy with updated criteria
      _controller.recalculateAllTaskCompletions();
    });
  }

  @override
  void dispose() {
    _callController.removeListener(_onCallStateChanged);
    super.dispose();
  }

  void _onCallStateChanged() {
    // Refresh tasks when call state changes
    if (mounted) {
      _controller.refreshTasks();
    }
  }

  Future<void> _syncAllTaskProgress() async {
    try {
      print('[TaskScreen] Starting global task progress sync...');

      // Show loading indicator
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      // Sync all task progress
      final success = await _taskSyncService.syncTaskProgress();

      // Hide loading indicator
      Get.back();

      if (success) {
        print('[TaskScreen] Global task progress sync successful');
        Get.snackbar(
          'Success',
          'All task progress synced successfully!',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );

        // Refresh the task list to show updated progress data
        await _controller.refreshTasks();
      } else {
        print('[TaskScreen] Global task progress sync failed');
        Get.snackbar(
          'Error',
          'Failed to sync task progress. Please try again.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      // Hide loading indicator if still showing
      if (Get.isDialogOpen == true) {
        Get.back();
      }

      print('[TaskScreen] Error syncing task progress: $e');
      Get.snackbar(
        'Error',
        'Failed to sync task progress: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DrawerScaffold(
      title: 'Tasks',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () async {
            // Recalculate task completions first to ensure accuracy with updated criteria
            await _controller.recalculateAllTaskCompletions();
            // Then refresh the task list
            await _controller.refreshTasks();
          },
          tooltip: 'Refresh',
        ),
        IconButton(
          icon: const Icon(Icons.sync),
          onPressed: _syncAllTaskProgress,
          tooltip: 'Sync All Task Progress',
        ),
      ],
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(4.w),
            color: Colors.white,
            child: Column(
              children: [
                // Search bar
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Search tasks',
                    hintText: 'Enter task title...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _controller.searchQuery.value.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _controller.setSearchQuery(''),
                          )
                        : null,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onChanged: (value) {
                    // Debounce search to avoid too many API calls
                    Future.delayed(const Duration(milliseconds: 500), () {
                      if (_controller.searchQuery.value != value) {
                        _controller.setSearchQuery(value);
                      }
                    });
                  },
                ),
                SizedBox(height: 2.h),
                // Status filter
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _controller.selectedStatus.value.isEmpty
                            ? null
                            : _controller.selectedStatus.value,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: '', child: Text('All')),
                          DropdownMenuItem(
                            value: 'pending',
                            child: Text('Pending'),
                          ),
                          DropdownMenuItem(
                            value: 'completed',
                            child: Text('Completed'),
                          ),
                          DropdownMenuItem(
                            value: 'overdue',
                            child: Text('Overdue'),
                          ),
                        ],
                        onChanged: (v) => _controller.setStatusFilter(v ?? ''),
                      ),
                    ),
                    SizedBox(width: 2.w),
                    // Sort dropdown
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _controller.sortBy.value,
                        decoration: const InputDecoration(
                          labelText: 'Sort',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'createdAt:desc',
                            child: Text('Newest First'),
                          ),
                          DropdownMenuItem(
                            value: 'createdAt:asc',
                            child: Text('Oldest First'),
                          ),
                          DropdownMenuItem(
                            value: 'title:asc',
                            child: Text('Title A-Z'),
                          ),
                          DropdownMenuItem(
                            value: 'title:desc',
                            child: Text('Title Z-A'),
                          ),
                        ],
                        onChanged: (v) =>
                            _controller.setSortBy(v ?? 'createdAt:desc'),
                      ),
                    ),
                  ],
                ),
                // Pagination info
                Obx(() {
                  if (_controller.totalResults.value > 0) {
                    return Padding(
                      padding: EdgeInsets.only(top: 1.h),
                      child: Text(
                        'Showing ${_controller.tasks.length} of ${_controller.totalResults.value} tasks',
                        style: TextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }),
              ],
            ),
          ),
          Expanded(
            child: Obx(() {
              if (_controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              final list = _controller.tasks;
              if (list.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.assignment_turned_in_outlined,
                        size: 20.w,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'No tasks',
                        style: TextStyles.heading2.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.all(2.w),
                itemCount:
                    list.length + (_controller.hasMorePages.value ? 1 : 0),
                itemBuilder: (context, index) {
                  // Show loading indicator at the end if there are more pages
                  if (index == list.length) {
                    return Obx(() {
                      if (_controller.isLoadingMore.value) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      } else if (_controller.hasMorePages.value) {
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Center(
                            child: ElevatedButton(
                              onPressed: _controller.loadMoreTasks,
                              child: const Text('Load More'),
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    });
                  }

                  final t = list[index];
                  return Card(
                    margin: EdgeInsets.only(bottom: 2.h),
                    child: ListTile(
                      leading: Icon(
                        Icons.assignment,
                        color: t.priority >= 3 ? Colors.red : AppColors.primary,
                      ),
                      title: Text(t.title, style: TextStyles.body),
                      subtitle: Text(
                        _formatSubtitle(t),
                        style: TextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                      onTap: () {
                        print(
                          '[TaskScreen] Navigating to task detail with task: ${t.id}',
                        );
                        Get.toNamed(Routes.TASK_DETAIL_SCREEN, arguments: t);
                      },
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  String _formatSubtitle(task) {
    final due = task.dueAt != null
        ? 'Due: ${_formatDate(task.dueAt)}'
        : 'No due date';

    // Add progress data if available
    final progress = (task.completedCount != null && task.totalCount != null)
        ? ' • ${task.completedCount}/${task.totalCount}'
        : '';

    // Normalize status for display (handle both backend uppercase and local lowercase)
    final statusDisplay = _normalizeStatusDisplay(task.status);

    return '$due$progress • Status: $statusDisplay';
  }

  /// Normalize task status for display
  /// Handles both backend format (COMPLETED, IN_PROGRESS, PENDING) 
  /// and local format (completed, in_progress, pending)
  String _normalizeStatusDisplay(String status) {
    final normalized = status.toLowerCase();
    switch (normalized) {
      case 'completed':
      case 'done':
        return 'Completed';
      case 'in_progress':
      case 'inprogress':
        return 'In Progress';
      case 'pending':
      case 'open':
        return 'Pending';
      default:
        // Capitalize first letter of each word
        return status.split('_').map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        }).join(' ');
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
