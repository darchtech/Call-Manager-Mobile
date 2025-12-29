import 'package:get/get.dart';
import '../repository/lead_repository.dart';
import '../services/api_service.dart';
import '../services/task_service.dart';
import '../controller/task_controller.dart';

class TaskSyncService extends GetxService {
  final ApiService _apiService = Get.find<ApiService>();
  final LeadRepository _leadRepo = LeadRepository.instance;
  final TaskService _taskService = Get.find<TaskService>();

  /// Sync task progress by collecting all lead data and sending to server
  Future<bool> syncTaskProgress() async {
    try {
      print('[TaskSyncService] Starting task progress sync...');

      // Get all leads from local database
      final allLeads = _leadRepo.getAllLeads();
      print('[TaskSyncService] Found ${allLeads.length} leads locally');

      if (allLeads.isEmpty) {
        print('[TaskSyncService] No leads found, skipping sync');
        return true;
      }

      // Prepare lead data for server
      final leadsData = allLeads
          .map(
            (lead) => {
              'leadId': lead.id,
              'status': lead.status,
              'callStatus': lead.callStatus,
              'remark': lead.remark,
              'lastContactedAt': lead.lastContactedAt?.toIso8601String(),
            },
          )
          .toList();

      print('[TaskSyncService] Sending ${leadsData.length} leads to server...');

      // Send to server
      final response = await _apiService.syncTaskProgress(leadsData);

      if (response.isSuccess && response.data != null) {
        final result = response.data!;
        print('[TaskSyncService] Server response: ${result['message']}');

        // Update local task completion counts based on server response
        if (result['updatedTasks'] != null) {
          await _updateLocalTaskCompletions(result['updatedTasks']);
        }

        // Refresh task controller to show updated counts
        if (Get.isRegistered<TaskController>()) {
          final taskController = Get.find<TaskController>();
          await taskController.loadTasks();
          await taskController.refreshTasks();
          print('[TaskSyncService] Refreshed TaskController with updated data');
        }

        print('[TaskSyncService] Task progress sync completed successfully');
        return true;
      } else {
        print('[TaskSyncService] Server sync failed: ${response.error}');
        return false;
      }
    } catch (e) {
      print('[TaskSyncService] Error syncing task progress: $e');
      return false;
    }
  }

  /// Update local task completion counts based on server response
  Future<void> _updateLocalTaskCompletions(List<dynamic> updatedTasks) async {
    try {
      print(
        '[TaskSyncService] Updating local task completion counts for ${updatedTasks.length} tasks...',
      );

      for (final taskData in updatedTasks) {
        final taskId = taskData['taskId'];
        final completedCount = taskData['completedCount'];
        final totalCount = taskData['totalCount'];
        final status = taskData['status'];

        print(
          '[TaskSyncService] Updating task $taskId: $completedCount/$totalCount ($status)',
        );

        // Get the task from local storage
        final task = _taskService.getTask(taskId);
        if (task != null) {
          // Update completion counts
          task.completedCount = completedCount;
          task.totalCount = totalCount;
          task.status = status.toLowerCase();
          task.updatedAt = DateTime.now();
          task.isSynced = true;

          // Save updated task
          await _taskService.saveTask(task);
          print(
            '[TaskSyncService] Updated local task $taskId: ${task.completedCount}/${task.totalCount}',
          );

          // Notify TaskController about the update
          if (Get.isRegistered<TaskController>()) {
            final taskController = Get.find<TaskController>();
            // Trigger a recalculation for all tasks to ensure consistency
            await taskController.recalculateAllTaskCompletions();
          }
        } else {
          print('[TaskSyncService] Task $taskId not found locally, skipping');
        }
      }

      print('[TaskSyncService] Local task completion counts updated');

      // Final refresh of TaskController to ensure UI shows latest data
      if (Get.isRegistered<TaskController>()) {
        final taskController = Get.find<TaskController>();
        await taskController.refreshTasks();
        print('[TaskSyncService] Final TaskController refresh completed');
      }
    } catch (e) {
      print('[TaskSyncService] Error updating local task completions: $e');
    }
  }

  /// Sync progress for a specific task
  Future<bool> syncTaskProgressForTask(String taskId) async {
    try {
      print('[TaskSyncService] Syncing progress for specific task: $taskId');

      // Get the task
      final task = _taskService.getTask(taskId);
      if (task == null) {
        print('[TaskSyncService] Task $taskId not found locally');
        return false;
      }

      // Get all lead IDs for this task
      final List<String> allLeadIds = [];
      if (task.leadId != null) allLeadIds.add(task.leadId!);
      if (task.relatedLeadIds != null) allLeadIds.addAll(task.relatedLeadIds!);

      // Remove duplicates
      final uniqueLeadIds = allLeadIds.toSet().toList();

      print('[TaskSyncService] Task $taskId has ${uniqueLeadIds.length} leads');

      if (uniqueLeadIds.isEmpty) {
        print('[TaskSyncService] No leads found for task $taskId');
        return true;
      }

      // Get lead data for this task only
      final leadsData = uniqueLeadIds
          .map((leadId) => _leadRepo.getLead(leadId))
          .where((lead) => lead != null)
          .map(
            (lead) => {
              'leadId': lead!.id,
              'status': lead.status,
              'callStatus': lead.callStatus,
              'remark': lead.remark,
              'lastContactedAt': lead.lastContactedAt?.toIso8601String(),
            },
          )
          .toList();

      if (leadsData.isEmpty) {
        print('[TaskSyncService] No lead data found for task $taskId');
        return true;
      }

      print(
        '[TaskSyncService] Sending ${leadsData.length} leads for task $taskId to server...',
      );

      // Send to server
      final response = await _apiService.syncTaskProgress(leadsData);

      if (response.isSuccess && response.data != null) {
        final result = response.data!;
        print(
          '[TaskSyncService] Server response for task $taskId: ${result['message']}',
        );

        // Update local task completion counts
        if (result['updatedTasks'] != null) {
          await _updateLocalTaskCompletions(result['updatedTasks']);
        }

        // Refresh task controller to show updated counts
        if (Get.isRegistered<TaskController>()) {
          final taskController = Get.find<TaskController>();
          await taskController.loadTasks();
          await taskController.refreshTasks();
          print(
            '[TaskSyncService] Refreshed TaskController with updated data for task $taskId',
          );
        }

        print(
          '[TaskSyncService] Task $taskId progress sync completed successfully',
        );
        return true;
      } else {
        print(
          '[TaskSyncService] Server sync failed for task $taskId: ${response.error}',
        );
        return false;
      }
    } catch (e) {
      print('[TaskSyncService] Error syncing progress for task $taskId: $e');
      return false;
    }
  }
}
