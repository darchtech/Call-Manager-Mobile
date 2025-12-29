import 'package:hive/hive.dart';
import '../model/task.dart';

class TaskRepository {
  static const String _taskBoxName = 'tasks';
  static Box<Task>? _taskBox;

  /// Initialize the task database
  static Future<void> initialize() async {
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(TaskAdapter());
    }
    _taskBox = await Hive.openBox<Task>(_taskBoxName);
    print('[TaskRepo] Database initialized with ${_taskBox!.length} tasks');
  }

  /// Get the task box
  Box<Task> get taskBox {
    if (_taskBox == null || !_taskBox!.isOpen) {
      throw Exception(
        'Task database not initialized. Call initialize() first.',
      );
    }
    return _taskBox!;
  }

  /// Save a task to local storage
  Future<void> saveTask(Task task) async {
    await taskBox.put(task.id, task);
    print('[TaskRepo] Saved task: ${task.title}');
  }

  /// Get a task by ID
  Task? getTask(String id) {
    return taskBox.get(id);
  }

  /// Get all tasks
  List<Task> getAllTasks() {
    return taskBox.values.toList();
  }

  /// Get tasks by status
  List<Task> getTasksByStatus(String status) {
    return taskBox.values.where((task) => task.status == status).toList();
  }

  /// Get tasks assigned to a specific user
  List<Task> getTasksByAssignee(String assignedTo) {
    // Task model does not persist assignedTo; return all for now
    return taskBox.values.toList();
  }

  /// Get unsynced tasks
  List<Task> getUnsyncedTasks() {
    return taskBox.values.where((task) => !task.isSynced).toList();
  }

  /// Mark a task as synced
  Future<void> markTaskSynced(String taskId, {String? error}) async {
    final task = getTask(taskId);
    if (task != null) {
      task.markSynced(error: error);
      await saveTask(task);
    }
  }

  /// Update task status
  Future<void> updateTaskStatus(String taskId, String status) async {
    final task = getTask(taskId);
    if (task != null) {
      task.updateStatus(status);
      await saveTask(task);
    }
  }

  /// Delete a specific task
  Future<void> deleteTask(String taskId) async {
    await taskBox.delete(taskId);
    print('[TaskRepo] Deleted task: $taskId');
  }

  /// Clear all tasks
  Future<void> clearAllTasks() async {
    await taskBox.clear();
    print('[TaskRepo] Cleared all tasks');
  }

  /// Get task statistics
  Map<String, int> getTaskStats() {
    final tasks = getAllTasks();
    return {
      'total': tasks.length,
      'pending': tasks.where((t) => t.status == 'pending').length,
      'completed': tasks.where((t) => t.status == 'completed').length,
      'overdue': tasks
          .where(
            (t) =>
                t.status == 'pending' &&
                (t.dueAt != null && t.dueAt!.isBefore(DateTime.now())),
          )
          .length,
    };
  }

  /// Get tasks due today
  List<Task> getTasksDueToday() {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

    return taskBox.values.where((task) {
      final due = task.dueAt;
      return due != null && due.isAfter(startOfDay) && due.isBefore(endOfDay);
    }).toList();
  }

  /// Get overdue tasks
  List<Task> getOverdueTasks() {
    final now = DateTime.now();
    return taskBox.values.where((task) {
      final due = task.dueAt;
      return task.status != 'completed' && due != null && due.isBefore(now);
    }).toList();
  }
}
