import 'package:get/get.dart';
import '../model/task.dart';
import '../model/lead.dart';
import '../model/pagination_response.dart';
import '../repository/task_repository.dart';
import '../repository/lead_repository.dart';
import '../controller/task_controller.dart';
import 'api_service.dart';

class TaskService extends GetxService {
  final ApiService _apiService = Get.find<ApiService>();
  final TaskRepository _taskRepo = TaskRepository();
  final LeadRepository _leadRepo = LeadRepository.instance;

  /// Get all tasks from local storage
  List<Task> getAllTasks() {
    print('[SERVICE-TaskService] 📋 Getting all tasks from local storage');
    final tasks = _taskRepo.getAllTasks();
    print('[SERVICE-TaskService] 📊 Found ${tasks.length} tasks locally');
    return tasks;
  }

  /// Get tasks by status
  List<Task> getTasksByStatus(String status) {
    return _taskRepo.getTasksByStatus(status);
  }

  /// Get tasks assigned to current user
  List<Task> getMyTasks() {
    return _taskRepo.getTasksByAssignee(
      'current_user',
    ); // You might want to get actual user ID
  }

  /// Get task statistics
  Map<String, int> getTaskStats() {
    return _taskRepo.getTaskStats();
  }

  /// Get tasks due today
  List<Task> getTasksDueToday() {
    return _taskRepo.getTasksDueToday();
  }

  /// Get overdue tasks
  List<Task> getOverdueTasks() {
    return _taskRepo.getOverdueTasks();
  }

  /// Sync tasks from server (legacy method for backward compatibility)
  Future<TaskSyncResult> syncTasksFromServer() async {
    try {
      print('[TaskService] Fetching tasks from server');

      final response = await _apiService.getMyTasks();

      if (response.isSuccess) {
        int successCount = 0;
        // Upsert tasks instead of clearing to preserve local changes
        final tasks = response.data!;

        // Get current local task IDs for comparison
        final localTasks = _taskRepo.getAllTasks();
        final localTaskIds = localTasks.map((t) => t.id).toSet();
        final serverTaskIds = tasks.map((t) => t.id).toSet();

        // Find tasks that were deleted on server
        final deletedTaskIds = localTaskIds.difference(serverTaskIds);
        print(
          '[SERVICE-TaskService] 🗑️ Found ${deletedTaskIds.length} deleted tasks: $deletedTaskIds',
        );

        // Remove deleted tasks from local storage
        for (final deletedId in deletedTaskIds) {
          await _taskRepo.deleteTask(deletedId);
          print('[SERVICE-TaskService] 🗑️ Deleted local task: $deletedId');
        }

        // Save/update tasks from server
        for (final task in tasks) {
          await _taskRepo.saveTask(task);
          successCount++;
        }

        // Process leads that come with the task data
        await _processTaskLeads(tasks);

        print('[TaskService] Fetched $successCount tasks from server');

        // Notify TaskController to refresh UI if it's registered
        if (Get.isRegistered<TaskController>()) {
          final taskController = Get.find<TaskController>();
          taskController.loadTasks();
          // Recalculate task completions after syncing from server
          await taskController.recalculateAllTaskCompletions();
          print(
            '[TaskService] Notified TaskController to refresh UI and recalculate completions',
          );
        }

        return TaskSyncResult.success(successCount, 0);
      } else {
        print('[TaskService] Failed to fetch tasks: ${response.error}');
        return TaskSyncResult.error(response.error ?? 'Unknown error');
      }
    } catch (e) {
      print('[TaskService] Error syncing tasks from server: $e');
      return TaskSyncResult.error(e.toString());
    }
  }

  /// Sync tasks from server with pagination
  Future<TaskPaginationResult> syncTasksFromServerPaginated({
    int page = 1,
    int limit = 10,
    String? status,
    String? search,
    String? sortBy,
  }) async {
    try {
      print(
        '[TaskService] Fetching tasks from server (page: $page, limit: $limit)',
      );

      final response = await _apiService.getTasksPaginated(
        page: page,
        limit: limit,
        status: status,
        search: search,
        sortBy: sortBy,
      );

      if (response.isSuccess) {
        final paginationData = response.data!;
        int successCount = 0;

        // For pagination, we'll store tasks but not replace all local data
        // This allows for incremental loading
        for (final task in paginationData.results) {
          await _taskRepo.saveTask(task);
          successCount++;
        }

        // Process leads that come with the task data
        await _processTaskLeads(paginationData.results);

        print(
          '[TaskService] Fetched $successCount tasks from server (page $page)',
        );

        return TaskPaginationResult.success(paginationData, successCount, 0);
      } else {
        print('[TaskService] Failed to fetch tasks: ${response.error}');
        return TaskPaginationResult.error(response.error ?? 'Unknown error');
      }
    } catch (e) {
      print('[TaskService] Error syncing tasks from server: $e');
      return TaskPaginationResult.error(e.toString());
    }
  }

  Future<void> _processTaskLeads(List<Task> tasks) async {
    print('[SERVICE-TaskService] 🔄 Processing leads from task data...');

    for (final task in tasks) {
      if (task.relatedLeadIds != null && task.relatedLeadIds!.isNotEmpty) {
        print(
          '[SERVICE-TaskService] 📋 Task ${task.title} has ${task.relatedLeadIds!.length} related leads',
        );

        for (final leadId in task.relatedLeadIds!) {
          final existing = _leadRepo.getLead(leadId);
          if (existing == null) {
            print(
              '[SERVICE-TaskService] 🔍 Lead $leadId not found locally, will fetch from server',
            );
            // Try to fetch from server, create stub if fails
            try {
              final leadResp = await _apiService.getLeadById(leadId);
              if (leadResp.isSuccess && leadResp.data != null) {
                await _leadRepo.saveLead(leadResp.data!);
                print(
                  '[SERVICE-TaskService] ✅ Saved lead from server: ${leadResp.data!.firstName} ${leadResp.data!.lastName}',
                );
                // After saving the canonical lead by id, migrate any phone-based duplicates to this id
                await _relinkPhoneDuplicates(canonicalLeadId: leadId);
              } else {
                await _saveLeadStub(leadId);
                print(
                  '[SERVICE-TaskService] 🔧 Created stub for lead: $leadId',
                );
              }
            } catch (e) {
              await _saveLeadStub(leadId);
              print(
                '[SERVICE-TaskService] 🔧 Created stub for lead $leadId (error: $e)',
              );
            }
          } else {
            print(
              '[SERVICE-TaskService] ✅ Lead $leadId already exists locally: ${existing.firstName} ${existing.lastName}',
            );
            // Ensure no stray duplicates exist for the same phone with a different id
            await _relinkPhoneDuplicates(canonicalLeadId: leadId);
          }
        }
      }
    }
  }

  Future<void> _saveLeadStub(String leadId) async {
    final stub = Lead(
      id: leadId,
      firstName: 'Unknown',
      lastName: 'Lead',
      phoneNumber: '',
      status: 'Unknown',
      callStatus: 'Not Called',
    );
    await _leadRepo.saveLead(stub);
  }

  /// If multiple local leads share the same phone but different ids, migrate
  /// data into the canonical lead id (the one referenced by the task) and
  /// remove the duplicates to keep task linkage consistent.
  Future<void> _relinkPhoneDuplicates({required String canonicalLeadId}) async {
    final canonical = _leadRepo.getLead(canonicalLeadId);
    if (canonical == null || canonical.phoneNumber.isEmpty) return;

    final candidates = _leadRepo.getLeadsByPhoneNumber(canonical.phoneNumber);
    for (final dup in candidates) {
      if (dup.id == canonicalLeadId) continue;

      // Merge simple fields preferring the most recently updated record
      final newer = dup.updatedAt.isAfter(canonical.updatedAt)
          ? dup
          : canonical;

      canonical.firstName = (newer.firstName.isNotEmpty ? newer.firstName : canonical.firstName);
      canonical.lastName = (newer.lastName.isNotEmpty ? newer.lastName : canonical.lastName);
      canonical.email = newer.email ?? canonical.email;
      canonical.company = newer.company ?? canonical.company;
      canonical.status = (newer.updatedAt.isAfter(canonical.updatedAt))
          ? newer.status
          : canonical.status;
      canonical.callStatus = (newer.updatedAt.isAfter(canonical.updatedAt))
          ? newer.callStatus
          : canonical.callStatus;
      canonical.lastContactedAt =
          newer.lastContactedAt ?? canonical.lastContactedAt;
      canonical.assignedTo = newer.assignedTo ?? canonical.assignedTo;
      canonical.source = newer.source ?? canonical.source;
      canonical.priority = newer.priority != 0
          ? newer.priority
          : canonical.priority;
      canonical.metadata = newer.metadata ?? canonical.metadata;

      await _leadRepo.updateLead(canonical);

      // Remove duplicate record
      await _leadRepo.deleteLead(dup.id);
      print(
        '[SERVICE-TaskService] 🔗 Migrated duplicate lead ${dup.id} to canonical $canonicalLeadId',
      );
    }
  }

  /// Update task status locally
  Future<void> updateTaskStatus(String taskId, String status) async {
    await _taskRepo.updateTaskStatus(taskId, status);
    print('[TaskService] Updated task $taskId status to $status');
  }

  /// Mark task as synced
  Future<void> markTaskSynced(String taskId, {String? error}) async {
    await _taskRepo.markTaskSynced(taskId, error: error);
  }

  /// Get unsynced tasks
  List<Task> getUnsyncedTasks() {
    return _taskRepo.getUnsyncedTasks();
  }

  /// Save a task to local storage
  Future<void> saveTask(Task task) async {
    await _taskRepo.saveTask(task);
    print('[TaskService] Saved task: ${task.title}');
  }

  /// Get a task by ID
  Task? getTask(String taskId) {
    return _taskRepo.getTask(taskId);
  }
}

/// Result class for task sync operations
class TaskSyncResult {
  final bool isSuccess;
  final int syncedCount;
  final int failedCount;
  final String? error;

  TaskSyncResult._({
    required this.isSuccess,
    required this.syncedCount,
    required this.failedCount,
    this.error,
  });

  factory TaskSyncResult.success(int synced, int failed) {
    return TaskSyncResult._(
      isSuccess: true,
      syncedCount: synced,
      failedCount: failed,
    );
  }

  factory TaskSyncResult.error(String error) {
    return TaskSyncResult._(
      isSuccess: false,
      syncedCount: 0,
      failedCount: 0,
      error: error,
    );
  }

  @override
  String toString() {
    if (isSuccess) {
      return 'TaskSyncResult: Success ($syncedCount synced, $failedCount failed)';
    } else {
      return 'TaskSyncResult: Error - $error';
    }
  }
}

/// Result class for task pagination operations
class TaskPaginationResult {
  final bool isSuccess;
  final PaginationResponse<Task>? paginationData;
  final int syncedCount;
  final int failedCount;
  final String? error;

  TaskPaginationResult._({
    required this.isSuccess,
    this.paginationData,
    required this.syncedCount,
    required this.failedCount,
    this.error,
  });

  factory TaskPaginationResult.success(
    PaginationResponse<Task> paginationData,
    int synced,
    int failed,
  ) {
    return TaskPaginationResult._(
      isSuccess: true,
      paginationData: paginationData,
      syncedCount: synced,
      failedCount: failed,
    );
  }

  factory TaskPaginationResult.error(String error) {
    return TaskPaginationResult._(
      isSuccess: false,
      syncedCount: 0,
      failedCount: 0,
      error: error,
    );
  }

  @override
  String toString() {
    if (isSuccess) {
      return 'TaskPaginationResult: Success ($syncedCount synced, $failedCount failed) - ${paginationData.toString()}';
    } else {
      return 'TaskPaginationResult: Error - $error';
    }
  }
}
