import 'dart:async';
import 'package:get/get.dart';
import '../model/call_record.dart';
import 'call_database_service.dart';
import 'api_service.dart';
import 'network_service.dart';

class CallSyncService extends GetxService {
  static CallSyncService get instance => Get.find<CallSyncService>();

  final CallDatabaseService _dbService = CallDatabaseService.instance;
  late final ApiService _apiService;
  late final NetworkService _networkService;

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

    // Load settings
    _autoSyncEnabled.value = _dbService.autoSyncEnabled;
    _updatePendingSyncCount();

    // Start periodic sync if auto-sync is enabled
    if (_autoSyncEnabled.value) {
      _startPeriodicSync();
    }

    // Listen for network connectivity changes
    // Note: Listen to connectivity changes via NetworkService's public getter
  }

  /// Start periodic sync timer
  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(
      const Duration(minutes: 5), // Sync every 5 minutes
      (_) => _scheduleSyncWhenConnected(),
    );
    print('[Sync] Started periodic sync timer');
  }

  /// Stop periodic sync timer
  void _stopPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
    print('[Sync] Stopped periodic sync timer');
  }

  /// Schedule sync when network is available
  void _scheduleSyncWhenConnected() {
    _networkService.executeWhenConnected(() {
      syncPendingRecords();
    });
  }

  /// Update pending sync count
  void _updatePendingSyncCount() {
    _pendingSyncCount.value = _dbService.getUnsyncedCallRecords().length;
  }

  /// Enable/disable auto sync
  void setAutoSyncEnabled(bool enabled) {
    _autoSyncEnabled.value = enabled;
    _dbService.autoSyncEnabled = enabled;

    if (enabled) {
      _startPeriodicSync();
      _scheduleSyncWhenConnected();
    } else {
      _stopPeriodicSync();
    }

    print('[Sync] Auto sync ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Sync all pending call records
  Future<SyncResult> syncPendingRecords() async {
    if (_isSyncing) {
      print('[Sync] Sync already in progress, skipping');
      return SyncResult.alreadyInProgress();
    }

    if (!_networkService.isConnected) {
      print('[Sync] No network connection, sync skipped');
      return SyncResult.noConnection();
    }

    _isSyncing = true;
    _lastSyncStatus.value = 'Syncing...';

    try {
      final unsyncedRecords = _dbService.getUnsyncedCallRecords();

      if (unsyncedRecords.isEmpty) {
        _lastSyncStatus.value = 'All records synced';
        print('[Sync] No records to sync');
        return SyncResult.success(0, 0);
      }

      print('[Sync] Starting sync of ${unsyncedRecords.length} records');

      int successCount = 0;
      int failureCount = 0;

      // Try batch sync first (more efficient)
      if (unsyncedRecords.length > 1) {
        final batchResult = await _syncBatch(unsyncedRecords);
        if (batchResult) {
          successCount = unsyncedRecords.length;
          _lastSyncStatus.value = 'Synced $successCount records';
          _updatePendingSyncCount();
          _dbService.lastSyncTime = DateTime.now();
          return SyncResult.success(successCount, failureCount);
        } else {
          print('[Sync] Batch sync failed, falling back to individual sync');
        }
      }

      // Fall back to individual sync
      for (final record in unsyncedRecords) {
        final result = await _syncSingleRecord(record);
        if (result) {
          successCount++;
        } else {
          failureCount++;
        }

        // Add small delay to avoid overwhelming the server
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final statusMessage =
          'Synced $successCount/${unsyncedRecords.length} records';
      _lastSyncStatus.value = statusMessage;
      _updatePendingSyncCount();

      if (successCount > 0) {
        _dbService.lastSyncTime = DateTime.now();
      }

      print('[Sync] Completed: $statusMessage');
      return SyncResult.success(successCount, failureCount);
    } catch (e) {
      _lastSyncStatus.value = 'Sync failed: ${e.toString()}';
      print('[Sync] Error during sync: $e');
      return SyncResult.error(e.toString());
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync a batch of records
  Future<bool> _syncBatch(List<CallRecord> records) async {
    try {
      final response = await _apiService.syncCallRecordsBatch(records);

      if (response.isSuccess) {
        // Mark all records as synced
        for (final record in records) {
          await _dbService.markCallRecordSynced(record.id);
        }
        print('[Sync] Batch sync successful: ${records.length} records');
        return true;
      } else {
        print('[Sync] Batch sync failed: ${response.error}');
        return false;
      }
    } catch (e) {
      print('[Sync] Batch sync error: $e');
      return false;
    }
  }

  /// Sync a single record
  Future<bool> _syncSingleRecord(CallRecord record) async {
    try {
      final response = await _apiService.syncCallRecord(record);

      if (response.isSuccess) {
        await _dbService.markCallRecordSynced(record.id);
        print('[Sync] Record synced successfully: ${record.id}');
        return true;
      } else {
        await _dbService.markCallRecordSynced(record.id, error: response.error);
        print('[Sync] Record sync failed: ${record.id} - ${response.error}');
        return false;
      }
    } catch (e) {
      await _dbService.markCallRecordSynced(record.id, error: e.toString());
      print('[Sync] Record sync error: ${record.id} - $e');
      return false;
    }
  }

  /// Force sync a specific record
  Future<bool> forceSyncRecord(CallRecord record) async {
    if (!_networkService.isConnected) {
      print('[Sync] Cannot force sync - no network connection');
      return false;
    }

    print('[Sync] Force syncing record: ${record.id}');
    return await _syncSingleRecord(record);
  }

  /// Manually trigger sync
  Future<SyncResult> manualSync() async {
    print('[Sync] Manual sync triggered');
    return await syncPendingRecords();
  }

  /// Get sync statistics
  Map<String, dynamic> getSyncStatistics() {
    final dbStats = _dbService.getCallStatistics();
    return {
      ...dbStats,
      'lastSyncTime': _dbService.lastSyncTime?.toIso8601String(),
      'autoSyncEnabled': _autoSyncEnabled.value,
      'isSyncing': _isSyncing,
      'networkConnected': _networkService.isConnected,
      'connectionType': _networkService.connectionType,
    };
  }

  /// Reset sync status for all records (for testing)
  Future<void> resetSyncStatus() async {
    final records = _dbService.getAllCallRecords();
    for (final record in records) {
      record.isSynced = false;
      record.syncedAt = null;
      record.syncAttempts = 0;
      record.syncError = null;
      await _dbService.updateCallRecord(record);
    }
    _updatePendingSyncCount();
    print('[Sync] Reset sync status for ${records.length} records');
  }

  @override
  void onClose() {
    _stopPeriodicSync();
    super.onClose();
  }
}

/// Result of a sync operation
class SyncResult {
  final bool success;
  final int? successCount;
  final int? failureCount;
  final String? error;
  final SyncResultType type;

  SyncResult._({
    required this.success,
    this.successCount,
    this.failureCount,
    this.error,
    required this.type,
  });

  factory SyncResult.success(int successCount, int failureCount) {
    return SyncResult._(
      success: true,
      successCount: successCount,
      failureCount: failureCount,
      type: SyncResultType.success,
    );
  }

  factory SyncResult.error(String error) {
    return SyncResult._(
      success: false,
      error: error,
      type: SyncResultType.error,
    );
  }

  factory SyncResult.noConnection() {
    return SyncResult._(
      success: false,
      error: 'No network connection',
      type: SyncResultType.noConnection,
    );
  }

  factory SyncResult.alreadyInProgress() {
    return SyncResult._(
      success: false,
      error: 'Sync already in progress',
      type: SyncResultType.alreadyInProgress,
    );
  }

  @override
  String toString() {
    if (success) {
      return 'SyncResult: Success ($successCount synced, $failureCount failed)';
    } else {
      return 'SyncResult: Error - $error';
    }
  }
}

enum SyncResultType { success, error, noConnection, alreadyInProgress }
