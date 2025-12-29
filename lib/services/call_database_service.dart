import 'package:hive_flutter/hive_flutter.dart';
import '../model/call_record.dart';

class CallDatabaseService {
  static const String _callBoxName = 'call_records';
  static const String _settingsBoxName = 'app_settings';

  static Box<CallRecord>? _callBox;
  static Box? _settingsBox;

  static CallDatabaseService? _instance;

  CallDatabaseService._();

  static CallDatabaseService get instance {
    _instance ??= CallDatabaseService._();
    return _instance!;
  }

  /// Initialize Hive database
  static Future<void> initialize() async {
    await Hive.initFlutter();

    // Register adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(CallRecordAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(CallSourceAdapter());
    }

    // Open boxes
    _callBox = await Hive.openBox<CallRecord>(_callBoxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);

    print(
      '[CallDB] Database initialized with ${_callBox!.length} call records',
    );
  }

  /// Get call records box
  Box<CallRecord> get callBox {
    if (_callBox == null || !_callBox!.isOpen) {
      throw Exception(
        'Call database not initialized. Call initialize() first.',
      );
    }
    return _callBox!;
  }

  /// Get settings box
  Box get settingsBox {
    if (_settingsBox == null || !_settingsBox!.isOpen) {
      throw Exception(
        'Settings database not initialized. Call initialize() first.',
      );
    }
    return _settingsBox!;
  }

  /// Save a call record
  Future<void> saveCallRecord(CallRecord record) async {
    try {
      await callBox.put(record.id, record);
      print('[CallDB] Saved call record: ${record.id} - ${record.phoneNumber}');
    } catch (e) {
      print('[CallDB] Error saving call record: $e');
      rethrow;
    }
  }

  /// Get a call record by ID
  CallRecord? getCallRecord(String id) {
    return callBox.get(id);
  }

  /// Get all call records
  List<CallRecord> getAllCallRecords() {
    return callBox.values.toList();
  }

  /// Get call records with pagination
  List<CallRecord> getCallRecords({
    int? limit,
    int? offset,
    bool sortByNewest = true,
  }) {
    var records = callBox.values.toList();

    // Sort by initiation time
    records.sort((a, b) {
      final comparison = a.initiatedAt.compareTo(b.initiatedAt);
      return sortByNewest ? -comparison : comparison;
    });

    // Apply pagination
    if (offset != null) {
      records = records.skip(offset).toList();
    }
    if (limit != null) {
      records = records.take(limit).toList();
    }

    return records;
  }

  /// Get call records by phone number
  List<CallRecord> getCallRecordsByNumber(String phoneNumber) {
    // Extract last 10 digits from the search phone number
    final searchDigits =
        phoneNumber.replaceAll(RegExp(r'[^\d]'), '').length >= 10
        ? phoneNumber
              .replaceAll(RegExp(r'[^\d]'), '')
              .substring(
                phoneNumber.replaceAll(RegExp(r'[^\d]'), '').length - 10,
              )
        : phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    return callBox.values.where((record) {
      // Extract last 10 digits from stored phone number
      final storedDigits =
          record.phoneNumber.replaceAll(RegExp(r'[^\d]'), '').length >= 10
          ? record.phoneNumber
                .replaceAll(RegExp(r'[^\d]'), '')
                .substring(
                  record.phoneNumber.replaceAll(RegExp(r'[^\d]'), '').length -
                      10,
                )
          : record.phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

      return storedDigits == searchDigits;
    }).toList()..sort((a, b) => b.initiatedAt.compareTo(a.initiatedAt));
  }

  /// Get call records by status
  List<CallRecord> getCallRecordsByStatus(String status) {
    return callBox.values.where((record) => record.status == status).toList()
      ..sort((a, b) => b.initiatedAt.compareTo(a.initiatedAt));
  }

  /// Get unsynced call records
  List<CallRecord> getUnsyncedCallRecords() {
    return callBox.values.where((record) => !record.isSynced).toList()..sort(
      (a, b) => a.initiatedAt.compareTo(b.initiatedAt),
    ); // Oldest first for sync
  }

  /// Get call records within date range
  List<CallRecord> getCallRecordsByDateRange(DateTime start, DateTime end) {
    return callBox.values
        .where(
          (record) =>
              record.initiatedAt.isAfter(start) &&
              record.initiatedAt.isBefore(end),
        )
        .toList()
      ..sort((a, b) => b.initiatedAt.compareTo(a.initiatedAt));
  }

  /// Update a call record
  Future<void> updateCallRecord(CallRecord record) async {
    try {
      await callBox.put(record.id, record);
      print('[CallDB] Updated call record: ${record.id}');
    } catch (e) {
      print('[CallDB] Error updating call record: $e');
      rethrow;
    }
  }

  /// Delete a call record
  Future<void> deleteCallRecord(String id) async {
    try {
      await callBox.delete(id);
      print('[CallDB] Deleted call record: $id');
    } catch (e) {
      print('[CallDB] Error deleting call record: $e');
      rethrow;
    }
  }

  /// Mark call record as synced
  Future<void> markCallRecordSynced(String id, {String? error}) async {
    final record = getCallRecord(id);
    if (record != null) {
      record.isSynced = error == null;
      record.syncedAt = error == null ? DateTime.now() : null;
      record.syncAttempts += 1;
      record.syncError = error;
      await updateCallRecord(record);
    }
  }

  /// Get call statistics
  Map<String, dynamic> getCallStatistics() {
    final records = getAllCallRecords();

    final totalCalls = records.length;
    final outgoingCalls = records.where((r) => r.isOutgoing).length;
    final incomingCalls = totalCalls - outgoingCalls;
    final connectedCalls = records
        .where(
          (r) =>
              r.status == 'CALL_CONNECTED' ||
              r.status == 'CALL_ACTIVE' ||
              r.status == 'CALL_ENDED_CONNECTED' ||
              r.status == 'CALL_ENDED_BY_CALLER' ||
              r.status == 'CALL_ENDED_BY_CALLEE',
        )
        .length;
    final missedCalls = records
        .where(
          (r) =>
              r.status == 'CALL_NO_ANSWER' ||
              r.status == 'CALL_ENDED_NO_ANSWER' ||
              r.status == 'CALL_DECLINED_BY_LEAD' ||
              r.status == 'CALL_DECLINED_BY_CALLEE' ||
              r.status == 'CALL_DECLINED_BY_CALLER',
        )
        .length;

    final totalDuration = records
        .where((r) => r.duration != null)
        .fold<Duration>(Duration.zero, (sum, r) => sum + r.duration!);

    final avgDuration = connectedCalls > 0
        ? Duration(seconds: totalDuration.inSeconds ~/ connectedCalls)
        : Duration.zero;

    return {
      'totalCalls': totalCalls,
      'outgoingCalls': outgoingCalls,
      'incomingCalls': incomingCalls,
      'connectedCalls': connectedCalls,
      'missedCalls': missedCalls,
      'totalDuration': totalDuration.inSeconds,
      'avgDuration': avgDuration.inSeconds,
      'unsyncedCount': getUnsyncedCallRecords().length,
    };
  }

  /// Clear all call records (for testing/reset)
  Future<void> clearAllCallRecords() async {
    try {
      await callBox.clear();
      print('[CallDB] Cleared all call records');
    } catch (e) {
      print('[CallDB] Error clearing call records: $e');
      rethrow;
    }
  }

  /// Get/Set last sync timestamp
  DateTime? get lastSyncTime {
    final timestamp = settingsBox.get('lastSyncTime');
    return timestamp != null ? DateTime.parse(timestamp) : null;
  }

  set lastSyncTime(DateTime? time) {
    if (time != null) {
      settingsBox.put('lastSyncTime', time.toIso8601String());
    } else {
      settingsBox.delete('lastSyncTime');
    }
  }

  /// Get/Set sync settings
  bool get autoSyncEnabled {
    return settingsBox.get('autoSyncEnabled', defaultValue: true);
  }

  set autoSyncEnabled(bool enabled) {
    settingsBox.put('autoSyncEnabled', enabled);
  }

  /// Get database info
  Map<String, dynamic> getDatabaseInfo() {
    return {
      'callRecordsCount': callBox.length,
      'databasePath': callBox.path,
      'isOpen': callBox.isOpen,
      'lastSyncTime': lastSyncTime?.toIso8601String(),
      'autoSyncEnabled': autoSyncEnabled,
    };
  }

  /// Close database connections
  Future<void> close() async {
    await _callBox?.close();
    await _settingsBox?.close();
    print('[CallDB] Database connections closed');
  }
}
