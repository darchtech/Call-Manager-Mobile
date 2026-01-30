import 'dart:async';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../model/task.dart';
import '../model/lead.dart';
import '../services/task_service.dart';
import '../repository/lead_repository.dart';
import '../services/auth_service.dart';

class TaskController extends GetxController {
  final TaskService _taskService = Get.find<TaskService>();

  final RxList<Task> tasks = <Task>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxString selectedStatus =
      ''.obs; // '', 'pending', 'completed', 'overdue'

  // Pagination state
  final RxInt currentPage = 1.obs;
  final RxInt totalPages = 1.obs;
  final RxInt totalResults = 0.obs;
  final RxBool hasMorePages = false.obs;
  final RxString searchQuery = ''.obs;
  final RxString sortBy = 'createdAt:desc'.obs;

  static const int pageSize = 10;

  // Caching and debouncing
  DateTime? _lastFetchTime;
  Timer? _refreshDebounceTimer;
  static const Duration _cacheDuration = Duration(minutes: 2);
  static const Duration _debounceDuration = Duration(milliseconds: 500);

  @override
  void onInit() {
    super.onInit();
    print('[CONTROLLER-TaskController] ===== INITIALIZING =====');
    // Only load tasks if user is authenticated
    final authService = Get.find<AuthService>();
    if (authService.isAuthenticated) {
      loadTasksPaginated();
    } else {
      print(
        '[CONTROLLER-TaskController] Skipping task load - user not authenticated',
      );
    }
  }

  Future<void> loadTasks() async {
    print('[CONTROLLER-TaskController] 📋 Loading tasks...');
    isLoading.value = true;
    try {
      final allTasks = _taskService.getAllTasks();
      print('[CONTROLLER-TaskController] 📊 Loaded ${allTasks.length} tasks');
      tasks.assignAll(allTasks);
      _applyFilter();
      print(
        '[CONTROLLER-TaskController] 🔍 Applied filter, showing ${tasks.length} tasks',
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Load tasks with pagination (first page)
  Future<void> loadTasksPaginated({bool reset = true, bool forceRefresh = false}) async {
    print('[CONTROLLER-TaskController] 📋 Loading tasks with pagination...');

    // Check cache unless force refresh is requested
    if (!forceRefresh &&
        !reset &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration &&
        tasks.isNotEmpty) {
      print('[CONTROLLER-TaskController] 📋 Using cached tasks (last fetch: $_lastFetchTime)');
      return;
    }

    if (reset) {
      currentPage.value = 1;
      tasks.clear();
    }

    isLoading.value = true;
    try {
      final result = await _taskService.syncTasksFromServerPaginated(
        page: currentPage.value,
        limit: pageSize,
        status: selectedStatus.value.isEmpty ? null : selectedStatus.value,
        search: searchQuery.value.isEmpty ? null : searchQuery.value,
        sortBy: sortBy.value,
      );

      if (result.isSuccess && result.paginationData != null) {
        final paginationData = result.paginationData!;

        if (reset) {
          tasks.assignAll(paginationData.results);
        } else {
          tasks.addAll(paginationData.results);
        }

        currentPage.value = paginationData.page;
        totalPages.value = paginationData.totalPages;
        totalResults.value = paginationData.totalResults;
        hasMorePages.value = paginationData.hasNextPage;

        // Update cache timestamp
        _lastFetchTime = DateTime.now();

        print(
          '[CONTROLLER-TaskController] 📊 Loaded ${paginationData.results.length} tasks (page ${paginationData.page}/${paginationData.totalPages})',
        );
        print(
          '[CONTROLLER-TaskController] 📊 Total results: ${paginationData.totalResults}',
        );
      } else {
        print(
          '[CONTROLLER-TaskController] ❌ Failed to load tasks: ${result.error}',
        );
        // Only show error toast if it's not a 401 (authentication required)
        // 401 errors are expected when user is not authenticated
        final authService = Get.find<AuthService>();
        final isAuthError =
            result.error?.contains('401') == true ||
            result.error?.contains('Unauthorized') == true ||
            !authService.isAuthenticated;

        if (!isAuthError) {
          Get.snackbar(
            'Error',
            'Failed to load tasks: ${result.error}',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      }
    } finally {
      isLoading.value = false;
    }
  }

  /// Load more tasks (next page)
  Future<void> loadMoreTasks() async {
    if (isLoadingMore.value || !hasMorePages.value) return;

    print('[CONTROLLER-TaskController] 📋 Loading more tasks...');
    isLoadingMore.value = true;

    try {
      currentPage.value++;
      final result = await _taskService.syncTasksFromServerPaginated(
        page: currentPage.value,
        limit: pageSize,
        status: selectedStatus.value.isEmpty ? null : selectedStatus.value,
        search: searchQuery.value.isEmpty ? null : searchQuery.value,
        sortBy: sortBy.value,
      );

      if (result.isSuccess && result.paginationData != null) {
        final paginationData = result.paginationData!;
        tasks.addAll(paginationData.results);

        currentPage.value = paginationData.page;
        totalPages.value = paginationData.totalPages;
        totalResults.value = paginationData.totalResults;
        hasMorePages.value = paginationData.hasNextPage;

        print(
          '[CONTROLLER-TaskController] 📊 Loaded ${paginationData.results.length} more tasks (page ${paginationData.page}/${paginationData.totalPages})',
        );
      } else {
        print(
          '[CONTROLLER-TaskController] ❌ Failed to load more tasks: ${result.error}',
        );
        // Revert page increment on failure
        currentPage.value--;
      }
    } finally {
      isLoadingMore.value = false;
    }
  }

  /// Refresh tasks (reload first page)
  Future<void> refreshTasks() async {
    // Cancel any pending refresh to debounce rapid calls
    _refreshDebounceTimer?.cancel();

    // Debounce the refresh call
    _refreshDebounceTimer = Timer(_debounceDuration, () async {
      await loadTasksPaginated(reset: true, forceRefresh: true);
    });
  }

  /// Set status filter and reload
  void setStatusFilter(String status) {
    selectedStatus.value = status;
    loadTasksPaginated(reset: true);
  }

  /// Set search query and reload
  void setSearchQuery(String query) {
    searchQuery.value = query;
    loadTasksPaginated(reset: true);
  }

  /// Set sort order and reload
  void setSortBy(String sort) {
    sortBy.value = sort;
    loadTasksPaginated(reset: true);
  }

  /// Legacy method for backward compatibility
  Future<void> loadTasksLegacy() async {
    print('[CONTROLLER-TaskController] 📋 Loading tasks (legacy method)...');
    isLoading.value = true;
    try {
      final allTasks = _taskService.getAllTasks();
      print('[CONTROLLER-TaskController] 📊 Loaded ${allTasks.length} tasks');
      tasks.assignAll(allTasks);
      _applyFilter();
      print(
        '[CONTROLLER-TaskController] 🔍 Applied filter, showing ${tasks.length} tasks',
      );
    } finally {
      isLoading.value = false;
    }
  }

  void _applyFilter() {
    final all = _taskService.getAllTasks();
    if (selectedStatus.value.isEmpty) {
      tasks.assignAll(all);
      return;
    }
    if (selectedStatus.value == 'overdue') {
      tasks.assignAll(_taskService.getOverdueTasks());
      return;
    }
    tasks.assignAll(
      all.where(
        (t) => t.status.toLowerCase() == selectedStatus.value.toLowerCase(),
      ),
    );
  }

  /// Update task completion count when a call is made to a lead in the task
  Future<void> updateTaskCompletionForCall(
    String leadId,
    String callStatusLabel,
  ) async {
    print(
      '[CONTROLLER-TaskController] 📞 Updating task completion for call to lead: $leadId',
    );
    print('[CONTROLLER-TaskController] 📞 Call status: $callStatusLabel');

    try {
      // Find tasks that contain this lead ID
      final allTasks = _taskService.getAllTasks();
      final relatedTasks = allTasks.where((task) {
        // Check if the task's primary leadId matches
        if (task.leadId == leadId) return true;

        // Check if the task's relatedLeadIds contains this leadId
        if (task.relatedLeadIds != null &&
            task.relatedLeadIds!.contains(leadId)) {
          return true;
        }

        return false;
      }).toList();

      print(
        '[CONTROLLER-TaskController] 📋 Found ${relatedTasks.length} related tasks',
      );

      for (final task in relatedTasks) {
        // Only increment if the call was successful (connected)
        if (_isSuccessfulCall(callStatusLabel)) {
          print(
            '[CONTROLLER-TaskController] ✅ Call was successful, incrementing completion for task: ${task.id}',
          );

          // Increment completed count
          final currentCompleted = task.completedCount ?? 0;
          task.completedCount = currentCompleted + 1;
          task.updatedAt = DateTime.now();
          task.isSynced = false; // Mark for sync

          // Save the updated task
          await _taskService.saveTask(task);

          print(
            '[CONTROLLER-TaskController] 📊 Task ${task.id} completion: ${task.completedCount}/${task.totalCount}',
          );

          // Check if task is now completed
          if (task.totalCount != null &&
              task.completedCount! >= task.totalCount!) {
            print(
              '[CONTROLLER-TaskController] 🎉 Task ${task.id} is now completed!',
            );
            task.status = 'completed';
            await _taskService.saveTask(task);
          }
        } else {
          print(
            '[CONTROLLER-TaskController] ❌ Call was not successful, not incrementing completion',
          );
        }
      }

      // Update local task list with modified tasks (no API call needed)
      for (final updatedTask in relatedTasks) {
        final index = tasks.indexWhere((t) => t.id == updatedTask.id);
        if (index != -1) {
          tasks[index] = updatedTask;
        }
      }
      // Trigger UI update
      tasks.refresh();
    } catch (e) {
      print('[CONTROLLER-TaskController] ❌ Error updating task completion: $e');
    }
  }

  /// Check if the call status indicates a successful call
  bool _isSuccessfulCall(String callStatusLabel) {
    final successfulStatuses = [
      'CALLED',
      'CALL_ENDED_CONNECTED',
      'CALL_ENDED_BY_CALLER',
      'CALL_ENDED_BY_CALLEE',
      'CALL_CONNECTED',
      'CALL_ACTIVE',
    ];

    return successfulStatuses.any(
      (status) => callStatusLabel.toUpperCase() == status.toUpperCase(),
    );
  }

  /// Get task by ID
  Task? getTaskById(String taskId) {
    return _taskService.getTask(taskId);
  }

  /// Get tasks related to a specific lead
  List<Task> getTasksForLead(String leadId) {
    final allTasks = _taskService.getAllTasks();
    return allTasks.where((task) {
      if (task.leadId == leadId) return true;
      if (task.relatedLeadIds != null &&
          task.relatedLeadIds!.contains(leadId)) {
        return true;
      }
      return false;
    }).toList();
  }

  /// Check if a lead is complete based on call status, remark, and lead status
  bool isLeadComplete(String callStatus, String leadStatus, String? remark) {
    // Check if call status is one of the appropriate successful call statuses
    final appropriateCallStatuses = [
      'CALLED',
      'CALL_ENDED_CONNECTED',
      'CALL_ENDED_BY_CALLER',
      'CALL_ENDED_BY_CALLEE',
      'CALL_CONNECTED',
      'CALL_ACTIVE',
    ];

    final hasAppropriateCallStatus = appropriateCallStatuses.any(
      (status) => callStatus.toUpperCase() == status.toUpperCase(),
    );

    // Check if lead status is appropriate (not unassigned, assigned, new, etc.)
    final inappropriateLeadStatuses = [
      'unassigned',
      'assigned',
      'new',
      'pending',
      'initial',
      'draft',
      'created',
    ];

    final hasAppropriateLeadStatus = !inappropriateLeadStatuses.any(
      (status) => leadStatus.toLowerCase().contains(status.toLowerCase()),
    );

    // Check if remark is not empty
    final hasRemark = remark != null && remark.trim().isNotEmpty;

    print('[CONTROLLER-TaskController] 🔍 Lead completion check:');
    print(
      '[CONTROLLER-TaskController] - Call status: $callStatus (appropriate: $hasAppropriateCallStatus)',
    );
    print(
      '[CONTROLLER-TaskController] - Lead status: $leadStatus (appropriate: $hasAppropriateLeadStatus)',
    );
    print(
      '[CONTROLLER-TaskController] - Remark: "${remark ?? 'null'}" (has remark: $hasRemark)',
    );

    final isComplete =
        hasAppropriateCallStatus && hasAppropriateLeadStatus && hasRemark;
    print('[CONTROLLER-TaskController] - Is complete: $isComplete');

    return isComplete;
  }

  /// Recalculate task completion based on lead completion status
  Future<void> recalculateTaskCompletionForLead(String leadId) async {
    print(
      '[CONTROLLER-TaskController] 🔄 Recalculating task completion for lead: $leadId',
    );

    try {
      // Get the lead data
      final leadRepo = LeadRepository.instance;
      final lead = leadRepo.getLead(leadId);

      if (lead == null) {
        print('[CONTROLLER-TaskController] ❌ Lead not found: $leadId');
        return;
      }

      // Find tasks that contain this lead ID
      final allTasks = _taskService.getAllTasks();
      final relatedTasks = allTasks.where((task) {
        if (task.leadId == leadId) return true;
        if (task.relatedLeadIds != null &&
            task.relatedLeadIds!.contains(leadId)) {
          return true;
        }
        return false;
      }).toList();

      print(
        '[CONTROLLER-TaskController] 📋 Found ${relatedTasks.length} related tasks',
      );

      for (final task in relatedTasks) {
        await _recalculateTaskCompletion(task);
      }

      // Update local task list with recalculated tasks (no API call needed)
      for (final updatedTask in relatedTasks) {
        final index = tasks.indexWhere((t) => t.id == updatedTask.id);
        if (index != -1) {
          tasks[index] = updatedTask;
        }
      }
      // Trigger UI update
      tasks.refresh();
    } catch (e) {
      print(
        '[CONTROLLER-TaskController] ❌ Error recalculating task completion: $e',
      );
    }
  }

  /// Recalculate completion for a specific task based on all its leads
  Future<void> _recalculateTaskCompletion(Task task) async {
    print(
      '[CONTROLLER-TaskController] 🔄 Recalculating completion for task: ${task.id}',
    );

    try {
      // Get all leads for this task
      final leadRepo = LeadRepository.instance;
      final List<String> allLeadIds = [];

      if (task.leadId != null) allLeadIds.add(task.leadId!);
      if (task.relatedLeadIds != null) allLeadIds.addAll(task.relatedLeadIds!);

      // Remove duplicates to avoid counting the same lead twice
      final uniqueLeadIds = allLeadIds.toSet().toList();

      print(
        '[CONTROLLER-TaskController] 🔍 Lead IDs before deduplication: ${allLeadIds.length} (${allLeadIds.join(', ')})',
      );
      print(
        '[CONTROLLER-TaskController] 🔍 Lead IDs after deduplication: ${uniqueLeadIds.length} (${uniqueLeadIds.join(', ')})',
      );

      final leads = uniqueLeadIds
          .map((id) => leadRepo.getLead(id))
          .where((lead) => lead != null)
          .cast<Lead>()
          .toList();

      print(
        '[CONTROLLER-TaskController] 📋 Task has ${leads.length} leads to check',
      );

      // Helper function to normalize status for comparison
      // Handles variations like "un-assigned", "un_assigned", "un assigned", etc.
      String normalizeStatus(String status) {
        if (status.isEmpty) return '';
        return status.toLowerCase().trim().replaceAll(RegExp(r'[-_\s]'), '');
      }

      // Count completed leads based on unified criteria
      // A lead is considered completed if status is NOT "assigned", "assign", "new", "unassigned", "unassigne", or "unassign"
      // Handles variations: "un-assigned", "un_assigned", "un assigned", "UnAssigned", "un-assigne", "un-assign", etc.
      int completedCount = 0;
      for (final lead in leads) {
        final normalizedStatus = normalizeStatus(lead.status);
        final isCompleted =
            normalizedStatus != 'assigned' &&
            normalizedStatus != 'assign' &&
            normalizedStatus != 'new' &&
            normalizedStatus != 'unassigned' &&
            normalizedStatus != 'unassigne' &&
            normalizedStatus != 'unassign';

        if (isCompleted) {
          completedCount++;
          print(
            '[CONTROLLER-TaskController] ✅ Lead ${lead.id} (${lead.firstName} ${lead.lastName}) is completed (status: ${lead.status})',
          );
        } else {
          print(
            '[CONTROLLER-TaskController] ❌ Lead ${lead.id} (${lead.firstName} ${lead.lastName}) is not completed (status: ${lead.status})',
          );
        }
      }

      final totalCount = leads.length;
      final oldCompletedCount = task.completedCount ?? 0;
      final oldStatus = task.status;

      // Update task completion count and status
      task.completedCount = completedCount;
      task.totalCount = totalCount;
      task.updatedAt = DateTime.now();
      task.isSynced = false;

      // Update task status based on completion
      if (completedCount >= totalCount && totalCount > 0) {
        task.status = 'completed';
      } else if (completedCount > 0) {
        task.status = 'in_progress';
      } else {
        task.status = 'pending';
      }

      await _taskService.saveTask(task);

      print(
        '[CONTROLLER-TaskController] 📊 Task ${task.id} completion: $completedCount/$totalCount (was: $oldCompletedCount/$totalCount)',
      );
      print(
        '[CONTROLLER-TaskController] 📊 Task ${task.id} status: ${task.status} (was: $oldStatus)',
      );

      if (completedCount != oldCompletedCount || task.status != oldStatus) {
        print(
          '[CONTROLLER-TaskController] 🔄 Task ${task.id} completion updated!',
        );
      }
    } catch (e) {
      print(
        '[CONTROLLER-TaskController] ❌ Error recalculating task ${task.id}: $e',
      );
    }
  }

  /// Recalculate completion for all tasks
  Future<void> recalculateAllTaskCompletions() async {
    print(
      '[CONTROLLER-TaskController] 🔄 Recalculating completion for all tasks',
    );

    try {
      final allTasks = _taskService.getAllTasks();
      print(
        '[CONTROLLER-TaskController] 📋 Found ${allTasks.length} tasks to recalculate',
      );

      for (final task in allTasks) {
        await _recalculateTaskCompletion(task);
      }

      // Refresh the tasks list to show updated counts
      refreshTasks();

      print(
        '[CONTROLLER-TaskController] ✅ Completed recalculation for all tasks',
      );
    } catch (e) {
      print(
        '[CONTROLLER-TaskController] ❌ Error recalculating all task completions: $e',
      );
    }
  }

  @override
  void onClose() {
    _refreshDebounceTimer?.cancel();
    super.onClose();
  }
}
