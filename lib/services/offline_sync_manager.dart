import 'dart:async';
import 'package:get/get.dart';
import '../services/call_sync_service.dart';
import '../services/lead_sync_service.dart';
import '../services/network_service.dart';

class OfflineSyncManager extends GetxService {
  static OfflineSyncManager get instance => Get.find<OfflineSyncManager>();

  final NetworkService _networkService = NetworkService.instance;
  final CallSyncService _callSyncService = CallSyncService.instance;
  final LeadSyncService _leadSyncService = LeadSyncService.instance;

  Timer? _periodicSyncTimer;
  Timer? _retryTimer;
  bool _isInitialized = false;

  final RxBool _isSyncing = false.obs;
  final RxString _lastSyncStatus = 'Never synced'.obs;
  final RxInt _pendingSyncCount = 0.obs;
  final RxList<String> _syncErrors = <String>[].obs;

  bool get isSyncing => _isSyncing.value;
  String get lastSyncStatus => _lastSyncStatus.value;
  int get pendingSyncCount => _pendingSyncCount.value;
  List<String> get syncErrors => _syncErrors;

  @override
  Future<void> onInit() async {
    super.onInit();
    await _initialize();
  }

  /// Initialize the offline sync manager
  Future<void> _initialize() async {
    if (_isInitialized) return;

    try {
      print('[OfflineSync] Initializing offline sync manager...');

      // Start periodic sync
      _startPeriodicSync();

      // Listen for network connectivity changes
      _networkService.executeWhenConnected(() {
        _triggerSync();
      });

      // Initial sync if online
      if (_networkService.isConnected) {
        _triggerSync();
      }

      _isInitialized = true;
      print('[OfflineSync] Offline sync manager initialized');
    } catch (e) {
      print('[OfflineSync] Error initializing: $e');
    }
  }

  /// Start periodic sync timer
  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(
      const Duration(minutes: 10), // Sync every 10 minutes
      (_) => _triggerSync(),
    );
    print('[OfflineSync] Started periodic sync timer');
  }

  /// Stop periodic sync timer
  void _stopPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
    print('[OfflineSync] Stopped periodic sync timer');
  }

  /// Trigger sync when network is available
  void _triggerSync() {
    if (!_networkService.isConnected) {
      print('[OfflineSync] No network connection, sync skipped');
      return;
    }

    if (_isSyncing.value) {
      print('[OfflineSync] Sync already in progress, skipping');
      return;
    }

    _performSync();
  }

  /// Perform comprehensive sync
  Future<void> _performSync() async {
    if (_isSyncing.value) return;

    _isSyncing.value = true;
    _lastSyncStatus.value = 'Syncing...';
    _syncErrors.clear();

    try {
      print('[OfflineSync] Starting comprehensive sync...');

      // Sync call records
      final callResult = await _callSyncService.syncPendingRecords();
      print('[OfflineSync] Call sync result: ${callResult.toString()}');

      // Sync leads and status options
      final leadResult = await _leadSyncService.syncAllData();
      print('[OfflineSync] Lead sync result: ${leadResult.toString()}');

      // Update status
      final totalSuccess =
          (callResult.successCount ?? 0) + (leadResult.successCount ?? 0);
      final totalFailure =
          (callResult.failureCount ?? 0) + (leadResult.failureCount ?? 0);

      if (totalSuccess > 0 || totalFailure == 0) {
        _lastSyncStatus.value =
            'Last sync: ${DateTime.now().toString().substring(11, 19)}';
        _updatePendingSyncCount();
      } else {
        _lastSyncStatus.value = 'Sync failed';
        if (callResult.error != null)
          _syncErrors.add('Call sync: ${callResult.error}');
        if (leadResult.error != null)
          _syncErrors.add('Lead sync: ${leadResult.error}');
      }

      print(
        '[OfflineSync] Comprehensive sync completed: $totalSuccess success, $totalFailure failures',
      );
    } catch (e) {
      _lastSyncStatus.value = 'Sync error: ${e.toString()}';
      _syncErrors.add(e.toString());
      print('[OfflineSync] Error during sync: $e');
    } finally {
      _isSyncing.value = false;
    }
  }

  /// Update pending sync count
  void _updatePendingSyncCount() {
    // This would typically count unsynced items from both services
    // For now, we'll use a simple approach
    _pendingSyncCount.value = 0; // Will be updated by individual services
  }

  /// Force sync all data
  Future<void> forceSyncAll() async {
    if (!_networkService.isConnected) {
      print('[OfflineSync] Cannot force sync - no network connection');
      return;
    }

    print('[OfflineSync] Force sync triggered');
    await _performSync();
  }

  /// Sync specific data type
  Future<void> syncCallRecords() async {
    if (!_networkService.isConnected) {
      print('[OfflineSync] Cannot sync call records - no network connection');
      return;
    }

    try {
      _isSyncing.value = true;
      final result = await _callSyncService.syncPendingRecords();
      print('[OfflineSync] Call records sync result: ${result.toString()}');
    } finally {
      _isSyncing.value = false;
    }
  }

  /// Sync leads data
  Future<void> syncLeads() async {
    if (!_networkService.isConnected) {
      print('[OfflineSync] Cannot sync leads - no network connection');
      return;
    }

    try {
      _isSyncing.value = true;
      final result = await _leadSyncService.syncAllData();
      print('[OfflineSync] Leads sync result: ${result.toString()}');
    } finally {
      _isSyncing.value = false;
    }
  }

  /// Get sync statistics
  Map<String, dynamic> getSyncStatistics() {
    return {
      'isSyncing': _isSyncing.value,
      'lastSyncStatus': _lastSyncStatus.value,
      'pendingSyncCount': _pendingSyncCount.value,
      'syncErrors': _syncErrors,
      'networkConnected': _networkService.isConnected,
      'connectionType': _networkService.connectionType,
      'callSyncStats': _callSyncService.getSyncStatistics(),
      'leadSyncStats': _leadSyncService.getSyncStatistics(),
    };
  }

  /// Clear sync errors
  void clearSyncErrors() {
    _syncErrors.clear();
    _lastSyncStatus.value = 'Errors cleared';
  }

  /// Reset all sync status (for testing)
  Future<void> resetSyncStatus() async {
    try {
      await _callSyncService.resetSyncStatus();
      await _leadSyncService.resetSyncStatus();
      _updatePendingSyncCount();
      _syncErrors.clear();
      _lastSyncStatus.value = 'Sync status reset';
      print('[OfflineSync] Sync status reset for all data');
    } catch (e) {
      print('[OfflineSync] Error resetting sync status: $e');
    }
  }

  /// Enable/disable periodic sync
  void setPeriodicSyncEnabled(bool enabled) {
    if (enabled) {
      _startPeriodicSync();
    } else {
      _stopPeriodicSync();
    }
    print('[OfflineSync] Periodic sync ${enabled ? 'enabled' : 'disabled'}');
  }

  @override
  void onClose() {
    _stopPeriodicSync();
    _retryTimer?.cancel();
    super.onClose();
  }
}
