import 'dart:async';
import 'package:get/get.dart';
import '../model/lead.dart';
import '../repository/lead_repository.dart';
import '../controller/task_controller.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'network_service.dart';
import 'task_service.dart';

class LeadSyncService extends GetxService {
  static LeadSyncService get instance => Get.find<LeadSyncService>();

  final LeadRepository _leadRepo = LeadRepository.instance;
  late final ApiService _apiService;
  late final NetworkService _networkService;
  late final TaskService _taskService;

  Timer? _periodicSyncTimer;
  bool _isSyncing = false;

  final RxBool _autoSyncEnabled = true.obs;
  final RxString _lastSyncStatus = 'Never synced'.obs;
  final RxInt _pendingSyncCount = 0.obs;

  bool get autoSyncEnabled => _autoSyncEnabled.value;
  String get lastSyncStatus => _lastSyncStatus.value;
  int get pendingSyncCount => _pendingSyncCount.value;
  bool get isSyncing => _isSyncing;

  @override
  Future<void> onInit() async {
    super.onInit();
    _apiService = ApiService.instance;
    _networkService = NetworkService.instance;
    _taskService = Get.find<TaskService>();

    // Start periodic sync if auto-sync is enabled
    if (_autoSyncEnabled.value) {
      _startPeriodicSync();
    }

    // Initial sync on app launch
    _scheduleSyncWhenConnected();
  }

  /// Start periodic sync timer
  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(
      const Duration(minutes: 5), // Sync every 5 minutes
      (_) => _scheduleSyncWhenConnected(),
    );
    print('[LeadSync] Started periodic sync timer');
  }

  /// Stop periodic sync timer
  void _stopPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
    print('[LeadSync] Stopped periodic sync timer');
  }

  /// Schedule sync when network is available
  void _scheduleSyncWhenConnected() {
    _networkService.executeWhenConnected(() {
      syncAllData();
    });
  }

  /// Update pending sync count (leads only - status options are admin-managed)
  void _updatePendingSyncCount() {
    _pendingSyncCount.value = _leadRepo.getUnsyncedLeads().length;
    // Note: Status options are not counted as they're admin-managed (read-only on mobile)
  }

  /// Recalculate task completion for a lead
  Future<void> _recalculateTaskCompletionForLead(String leadId) async {
    try {
      if (Get.isRegistered<TaskController>()) {
        final taskController = Get.find<TaskController>();
        await taskController.recalculateTaskCompletionForLead(leadId);
        print('[LeadSync] ✅ Recalculated task completion for lead: $leadId');
      }
    } catch (e) {
      print(
        '[LeadSync] ❌ Error recalculating task completion for lead $leadId: $e',
      );
    }
  }

  /// Enable/disable auto sync
  void setAutoSyncEnabled(bool enabled) {
    _autoSyncEnabled.value = enabled;

    if (enabled) {
      _startPeriodicSync();
      _scheduleSyncWhenConnected();
    } else {
      _stopPeriodicSync();
    }

    print('[LeadSync] Auto sync ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Sync all data (leads and status options)
  Future<LeadSyncResult> syncAllData() async {
    // Gate by authentication
    final authed =
        Get.isRegistered<AuthService>() && AuthService.instance.isAuthenticated;
    if (!authed) {
      return LeadSyncResult.error('Not authenticated');
    }
    if (_isSyncing) {
      print('[LeadSync] Sync already in progress, skipping');
      return LeadSyncResult.alreadyInProgress();
    }

    if (!_networkService.isConnected) {
      print('[LeadSync] No network connection, sync skipped');
      return LeadSyncResult.noConnection();
    }

    _isSyncing = true;
    _lastSyncStatus.value = 'Syncing...';

    try {
      print('[LeadSync] Starting full data sync');

      // 1. Fetch latest status options from server
      final statusOptionsResult = await _syncStatusOptions();

      // 2. Fetch latest leads from server
      final leadsResult = await _syncLeadsFromServer();

      // 3. Fetch tasks assigned to me
      final tasksResult = await _syncTasksFromServer();

      // 4. Sync local changes to server
      final localChangesResult = await _syncLocalChangesToServer();

      final totalSuccess =
          (statusOptionsResult.successCount ?? 0) +
          (leadsResult.successCount ?? 0) +
          (tasksResult.successCount ?? 0) +
          (localChangesResult.successCount ?? 0);
      final totalFailure =
          (statusOptionsResult.failureCount ?? 0) +
          (leadsResult.failureCount ?? 0) +
          (tasksResult.failureCount ?? 0) +
          (localChangesResult.failureCount ?? 0);

      _lastSyncStatus.value = 'Synced $totalSuccess items';
      _updatePendingSyncCount();

      print(
        '[LeadSync] Full sync completed: $totalSuccess success, $totalFailure failures',
      );
      return LeadSyncResult.success(totalSuccess, totalFailure);
    } catch (e) {
      _lastSyncStatus.value = 'Sync failed: ${e.toString()}';
      print('[LeadSync] Error during sync: $e');
      return LeadSyncResult.error(e.toString());
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync status options from server (READ-ONLY from admin panel)
  Future<LeadSyncResult> _syncStatusOptions() async {
    final authed =
        Get.isRegistered<AuthService>() && AuthService.instance.isAuthenticated;
    if (!authed) return LeadSyncResult.error('Not authenticated');
    try {
      print('[LeadSync] Fetching status options from server (admin-managed)');

      // Fetch both lead status and call status options
      final leadStatusResponse = await _apiService.getStatusOptions(
        type: 'leadStatus',
      );
      final callStatusResponse = await _apiService.getStatusOptions(
        type: 'callStatus',
      );

      int successCount = 0;
      int failureCount = 0;

      // Only clear local data if we have successful responses
      bool shouldClearLocal = false;

      if (leadStatusResponse.isSuccess || callStatusResponse.isSuccess) {
        // Clear existing local status options only if we have successful data
        await _leadRepo.clearAllStatusOptions();
        print(
          '[LeadSync] Cleared local status options - admin panel is source of truth',
        );
        shouldClearLocal = true;
      }

      if (leadStatusResponse.isSuccess) {
        for (final option in leadStatusResponse.data!) {
          await _leadRepo.saveStatusOption(option);
          successCount++;
        }
        print(
          '[LeadSync] Synced ${leadStatusResponse.data!.length} lead status options from admin panel',
        );
      } else {
        failureCount++;
        print(
          '[LeadSync] Failed to fetch lead status options: ${leadStatusResponse.error}',
        );
      }

      if (callStatusResponse.isSuccess) {
        for (final option in callStatusResponse.data!) {
          await _leadRepo.saveStatusOption(option);
          successCount++;
        }
        print(
          '[LeadSync] Synced ${callStatusResponse.data!.length} call status options from admin panel',
        );
      } else {
        failureCount++;
        print(
          '[LeadSync] Failed to fetch call status options: ${callStatusResponse.error}',
        );
      }

      // If both API calls failed, keep existing local data
      if (!shouldClearLocal) {
        print('[LeadSync] Both API calls failed - keeping existing local data');
      }

      // Removed enforcing Android-only call status labels in mobile app

      return LeadSyncResult.success(successCount, failureCount);
    } catch (e) {
      print('[LeadSync] Error syncing status options: $e');
      return LeadSyncResult.error(e.toString());
    }
  }

  /// Sync leads from server
  Future<LeadSyncResult> _syncLeadsFromServer() async {
    final authed =
        Get.isRegistered<AuthService>() && AuthService.instance.isAuthenticated;
    if (!authed) return LeadSyncResult.error('Not authenticated');
    try {
      print('[LeadSync] Fetching leads from server');

      final response = await _apiService.getLeads();

      if (response.isSuccess) {
        int successCount = 0;
        for (final serverLead in response.data!) {
          // Merge strategy: preserve newer local updates (e.g., callStatus from call outcomes)
          final localLead = _leadRepo.getLead(serverLead.id);
          if (localLead != null) {
            final isLocalNewer = localLead.updatedAt.isAfter(
              serverLead.updatedAt,
            );
            if (isLocalNewer) {
              // Keep local (already up to date locally); don't overwrite with older server data
              await _leadRepo.updateLead(localLead);
              // Recalculate task completion for this lead
              await _recalculateTaskCompletionForLead(localLead.id);
              successCount++;
              continue;
            }
          }
          await _leadRepo.saveLead(serverLead);
          // Recalculate task completion for this lead
          await _recalculateTaskCompletionForLead(serverLead.id);
          successCount++;
        }
        print(
          '[LeadSync] Fetched $successCount leads from server (with local-merge protection)',
        );
        return LeadSyncResult.success(successCount, 0);
      } else {
        print('[LeadSync] Failed to fetch leads: ${response.error}');
        return LeadSyncResult.error(response.error ?? 'Unknown error');
      }
    } catch (e) {
      print('[LeadSync] Error syncing leads from server: $e');
      return LeadSyncResult.error(e.toString());
    }
  }

  /// Sync tasks assigned to current user from server
  Future<LeadSyncResult> _syncTasksFromServer() async {
    final authed =
        Get.isRegistered<AuthService>() && AuthService.instance.isAuthenticated;
    if (!authed) return LeadSyncResult.error('Not authenticated');
    try {
      print('[LeadSync] Syncing tasks from server');

      final result = await _taskService.syncTasksFromServer();

      if (result.isSuccess) {
        print('[LeadSync] Synced ${result.syncedCount} tasks from server');

        // Ensure TaskController is notified of the sync
        if (Get.isRegistered<TaskController>()) {
          final taskController = Get.find<TaskController>();
          taskController.loadTasks();
          print(
            '[LeadSync] Notified TaskController to refresh UI after task sync',
          );
        }

        return LeadSyncResult.success(result.syncedCount, result.failedCount);
      } else {
        print('[LeadSync] Failed to sync tasks: ${result.error}');
        return LeadSyncResult.error(result.error ?? 'Unknown error');
      }
    } catch (e) {
      print('[LeadSync] Error syncing tasks from server: $e');
      return LeadSyncResult.error(e.toString());
    }
  }

  /// Sync local changes to server (LEADS ONLY - status options are admin-managed)
  Future<LeadSyncResult> _syncLocalChangesToServer() async {
    final authed =
        Get.isRegistered<AuthService>() && AuthService.instance.isAuthenticated;
    if (!authed) return LeadSyncResult.error('Not authenticated');
    try {
      print('[LeadSync] Syncing local lead changes to server');

      final unsyncedLeads = _leadRepo.getUnsyncedLeads();

      int successCount = 0;
      int failureCount = 0;

      // Sync leads only (status options are admin-managed, read-only on mobile)
      if (unsyncedLeads.isNotEmpty) {
        // Disabled until backend adds /v1/leads/batch
        failureCount += unsyncedLeads.length;
        print('[LeadSync] Skipping lead batch sync - endpoint not implemented');
      } else {
        print('[LeadSync] No unsynced leads to sync');
      }

      // Note: Status options are NOT synced from mobile - admin panel is source of truth
      print(
        '[LeadSync] Status options are admin-managed - mobile is read-only',
      );

      return LeadSyncResult.success(successCount, failureCount);
    } catch (e) {
      print('[LeadSync] Error syncing local changes: $e');
      return LeadSyncResult.error(e.toString());
    }
  }

  /// Sync a single lead immediately
  Future<bool> syncLeadImmediately(Lead lead) async {
    if (!_networkService.isConnected) {
      print('[LeadSync] Cannot sync lead - no network connection');
      return false;
    }

    try {
      print('[LeadSync] Syncing lead immediately: ${lead.id}');

      final response = await _apiService.syncLead(lead);
      if (response.isSuccess) {
        await _leadRepo.markLeadSynced(lead.id);
        _updatePendingSyncCount();
        return true;
      } else {
        await _leadRepo.markLeadSynced(lead.id, error: response.error);
        print('[LeadSync] Failed to sync lead: ${response.error}');
        return false;
      }
    } catch (e) {
      await _leadRepo.markLeadSynced(lead.id, error: e.toString());
      print('[LeadSync] Error syncing lead: $e');
      return false;
    }
  }

  /// Update lead on server
  Future<bool> updateLeadOnServer(Lead lead) async {
    if (!_networkService.isConnected) {
      print('[LeadSync] Cannot update lead - no network connection');
      return false;
    }

    try {
      print('[LeadSync] Updating lead on server: ${lead.id}');

      // Check if lead is already synced (has server ID)
      if (lead.isSynced) {
        // Lead exists on server, update it
        final response = await _apiService.updateLead(lead);
        if (response.isSuccess) {
          await _leadRepo.markLeadSynced(lead.id);
          _updatePendingSyncCount();
          return true;
        } else {
          await _leadRepo.markLeadSynced(lead.id, error: response.error);
          print('[LeadSync] Failed to update lead: ${response.error}');
          return false;
        }
      } else {
        // Try to attach to an existing server lead by phone
        try {
          final existing = await _apiService.getLeads(
            searchQuery: lead.phoneNumber,
          );
          if (existing.isSuccess && existing.data != null) {
            final match = existing.data!.firstWhere(
              (l) => l.phoneNumber == lead.phoneNumber,
              orElse: () => Lead(
                id: '',
                firstName: '',
                lastName: '',
                phoneNumber: '',
                status: '',
                callStatus: '',
              ),
            );
            if (match.id.isNotEmpty) {
              // Adopt server id and update
              final clientTempId = lead.id;
              lead.id = match.id;
              lead.isSynced = true;
              final upd = await _apiService.updateLead(lead);
              if (upd.isSuccess) {
                // replace local key if needed
                if (clientTempId != match.id) {
                  try {
                    await _leadRepo.deleteLead(clientTempId);
                  } catch (_) {}
                }
                await _leadRepo.saveLead(upd.data!);
                // Recalculate task completion for this lead
                await _recalculateTaskCompletionForLead(upd.data!.id);
                _updatePendingSyncCount();
                return true;
              }
            }
          }
        } catch (_) {}

        // Fallback: create on server
        print(
          '[LeadSync] Lead not synced, creating on server first: ${lead.id}',
        );
        final createResponse = await _apiService.syncLead(lead);
        if (createResponse.isSuccess) {
          // Update local DB: replace UUID-keyed record with server-id record
          final serverLead = createResponse.data!;
          final clientTempId = lead.metadata?['clientTempId'];
          if (clientTempId != null &&
              clientTempId is String &&
              clientTempId.isNotEmpty) {
            try {
              await _leadRepo.deleteLead(clientTempId);
            } catch (_) {}
          }
          await _leadRepo.saveLead(serverLead);
          // Recalculate task completion for this lead
          await _recalculateTaskCompletionForLead(serverLead.id);
          _updatePendingSyncCount();
          return true;
        } else {
          await _leadRepo.markLeadSynced(lead.id, error: createResponse.error);
          print('[LeadSync] Failed to create lead: ${createResponse.error}');
          return false;
        }
      }
    } catch (e) {
      await _leadRepo.markLeadSynced(lead.id, error: e.toString());
      print('[LeadSync] Error updating lead: $e');
      return false;
    }
  }

  /// Manually trigger sync
  Future<LeadSyncResult> manualSync() async {
    print('[LeadSync] Manual sync triggered');
    return await syncAllData();
  }

  /// Get sync statistics
  Map<String, dynamic> getSyncStatistics() {
    final leadStats = _leadRepo.getLeadStatistics();
    return {
      ...leadStats,
      'autoSyncEnabled': _autoSyncEnabled.value,
      'isSyncing': _isSyncing,
      'networkConnected': _networkService.isConnected,
      'connectionType': _networkService.connectionType,
    };
  }

  /// Reset sync status for all data (for testing)
  Future<void> resetSyncStatus() async {
    final leads = _leadRepo.getAllLeads();
    final statusOptions = _leadRepo.getAllStatusOptions();

    for (final lead in leads) {
      lead.isSynced = false;
      lead.syncedAt = null;
      lead.syncAttempts = 0;
      lead.syncError = null;
      await _leadRepo.updateLead(lead);
    }

    for (final option in statusOptions) {
      option.isSynced = false;
      option.syncedAt = null;
      await _leadRepo.updateStatusOption(option);
    }

    _updatePendingSyncCount();
    print(
      '[LeadSync] Reset sync status for ${leads.length} leads and ${statusOptions.length} status options',
    );
  }

  @override
  void onClose() {
    _stopPeriodicSync();
    super.onClose();
  }
}

/// Result of a lead sync operation
class LeadSyncResult {
  final bool success;
  final int? successCount;
  final int? failureCount;
  final String? error;
  final LeadSyncResultType type;

  LeadSyncResult._({
    required this.success,
    this.successCount,
    this.failureCount,
    this.error,
    required this.type,
  });

  factory LeadSyncResult.success(int successCount, int failureCount) {
    return LeadSyncResult._(
      success: true,
      successCount: successCount,
      failureCount: failureCount,
      type: LeadSyncResultType.success,
    );
  }

  factory LeadSyncResult.error(String error) {
    return LeadSyncResult._(
      success: false,
      error: error,
      type: LeadSyncResultType.error,
    );
  }

  factory LeadSyncResult.noConnection() {
    return LeadSyncResult._(
      success: false,
      error: 'No network connection',
      type: LeadSyncResultType.noConnection,
    );
  }

  factory LeadSyncResult.alreadyInProgress() {
    return LeadSyncResult._(
      success: false,
      error: 'Sync already in progress',
      type: LeadSyncResultType.alreadyInProgress,
    );
  }

  @override
  String toString() {
    if (success) {
      return 'LeadSyncResult: Success ($successCount synced, $failureCount failed)';
    } else {
      return 'LeadSyncResult: Error - $error';
    }
  }
}

enum LeadSyncResultType { success, error, noConnection, alreadyInProgress }
