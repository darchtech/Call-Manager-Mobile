import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'call_record.g.dart';

@HiveType(typeId: 0)
class CallRecord extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String phoneNumber;

  @HiveField(2)
  String? contactName;

  @HiveField(3)
  DateTime initiatedAt;

  @HiveField(4)
  DateTime? connectedAt;

  @HiveField(5)
  DateTime? endedAt;

  @HiveField(6)
  int? durationSeconds;

  @HiveField(7)
  String status; // Store outcome label directly (e.g., "CALL_ENDED_BY_CALLER", "CALL_DECLINED_BY_CALLEE")

  @HiveField(8)
  CallSource source;

  @HiveField(9)
  bool isOutgoing;

  @HiveField(10)
  String? deviceInfo;

  @HiveField(11)
  Map<String, dynamic>? metadata;

  @HiveField(12)
  bool isSynced;

  @HiveField(13)
  DateTime? syncedAt;

  @HiveField(14)
  int syncAttempts;

  @HiveField(15)
  String? syncError;

  @HiveField(16)
  String? outcomeLabel; // Store the precise outcome from native (e.g., "CALL_ENDED_BY_CALLER")

  CallRecord({
    String? id,
    required this.phoneNumber,
    this.contactName,
    required this.initiatedAt,
    this.connectedAt,
    this.endedAt,
    Duration? duration,
    required this.status,
    required this.source,
    required this.isOutgoing,
    this.deviceInfo,
    this.metadata,
    this.isSynced = false,
    this.syncedAt,
    this.syncAttempts = 0,
    this.syncError,
  }) : id = id ?? const Uuid().v4(),
       durationSeconds = duration?.inSeconds;

  /// Get duration as Duration object
  Duration? get duration =>
      durationSeconds != null ? Duration(seconds: durationSeconds!) : null;

  /// Set duration from Duration object
  set duration(Duration? value) => durationSeconds = value?.inSeconds;

  /// Calculate duration based on connected and ended times
  void calculateDuration() {
    if (connectedAt != null && endedAt != null) {
      duration = endedAt!.difference(connectedAt!);
    }
  }

  /// Update call status and handle state transitions
  void updateStatus(String newStatus, {DateTime? timestamp}) {
    final now = timestamp ?? DateTime.now();
    status = newStatus;

    // Determine if this is a final state that should set endedAt
    final isFinalState = _isFinalState(newStatus);
    if (isFinalState) {
      endedAt ??= now;
      calculateDuration();
    } else if (newStatus == 'CALL_CONNECTED' || newStatus == 'CALL_ACTIVE') {
      connectedAt ??= now;
    }

    // Mark as not synced when updated
    isSynced = false;
    syncError = null;
  }

  /// Check if the status represents a final call state
  bool _isFinalState(String status) {
    return status == 'CALL_ENDED_CONNECTED' ||
        status == 'CALL_ENDED_BY_CALLER' ||
        status == 'CALL_ENDED_BY_CALLEE' ||
        status == 'CALL_DECLINED_BY_CALLEE' ||
        status == 'CALL_DECLINED_BY_CALLER' ||
        status == 'CALL_CANCELLED_BY_CALLER' ||
        status == 'CALL_BUSY' ||
        status == 'CALL_NO_ANSWER' ||
        status == 'CALL_MISSED' ||
        status == 'CALL_ENDED_NO_ANSWER';
  }

  /// Convert to Map for MongoDB/API sync
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phoneNumber': phoneNumber,
      'contactName': contactName,
      'initiatedAt': initiatedAt.toIso8601String(),
      'connectedAt': connectedAt?.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'duration': durationSeconds,
      'status': status,
      'source': source.name,
      'isOutgoing': isOutgoing,
      'deviceInfo': deviceInfo,
      'metadata': metadata,
      'createdAt': initiatedAt.toIso8601String(),
      'updatedAt': (endedAt ?? connectedAt ?? initiatedAt).toIso8601String(),
    };
  }

  /// Create from JSON (for API responses)
  static CallRecord fromJson(Map<String, dynamic> json) {
    return CallRecord(
      id: json['id'],
      phoneNumber: json['phoneNumber'],
      contactName: json['contactName'],
      initiatedAt: DateTime.parse(json['initiatedAt']),
      connectedAt: json['connectedAt'] != null
          ? DateTime.parse(json['connectedAt'])
          : null,
      endedAt: json['endedAt'] != null ? DateTime.parse(json['endedAt']) : null,
      duration: json['duration'] != null
          ? Duration(seconds: json['duration'])
          : null,
      status: json['status'],
      source: CallSource.values.firstWhere((e) => e.name == json['source']),
      isOutgoing: json['isOutgoing'],
      deviceInfo: json['deviceInfo'],
      metadata: json['metadata']?.cast<String, dynamic>(),
      isSynced: true, // Assume synced if coming from API
      syncedAt: DateTime.now(),
    );
  }

  /// Get human-readable status with precise role-aware text
  String get statusText {
    switch (status.toUpperCase()) {
      case 'CALL_DIALING':
      case 'CALL_CONNECTING':
        return 'Connecting';
      case 'CALL_RINGING':
        return 'Ringing';
      case 'CALL_CONNECTED':
      case 'CALL_ACTIVE':
        return 'Connected';
      case 'CALL_ENDED_CONNECTED':
        return isSuccessful ? 'Connected' : 'Call Ended';
      case 'CALL_ENDED_BY_CALLER':
        return 'Ended by Caller';
      case 'CALL_ENDED_BY_CALLEE':
        return 'Ended by Callee';
      case 'CALL_DECLINED_BY_CALLEE':
        return 'Declined by Callee';
      case 'CALL_DECLINED_BY_CALLER':
        return 'Declined by Caller';
      case 'CALL_CANCELLED_BY_CALLER':
        return 'Cancelled by Caller';
      case 'CALL_BUSY':
        return 'Busy';
      case 'CALL_NO_ANSWER':
      case 'CALL_ENDED_NO_ANSWER':
        return 'No Answer';
      case 'CALL_MISSED':
        return 'Missed';
      default:
        return status.replaceAll('CALL_', '').replaceAll('_', ' ');
    }
  }

  /// Get formatted duration
  String get formattedDuration {
    if (duration == null) return '00:00';
    final minutes = duration!.inMinutes;
    final seconds = duration!.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Check if call was successful (connected for some time)
  bool get isSuccessful {
    return (status == 'CALL_ENDED_CONNECTED' ||
            status == 'CALL_ENDED_BY_CALLER' ||
            status == 'CALL_ENDED_BY_CALLEE') &&
        duration != null &&
        duration!.inSeconds > 0;
  }

  @override
  String toString() {
    return 'CallRecord{id: $id, phoneNumber: $phoneNumber, status: $status, duration: $formattedDuration, synced: $isSynced}';
  }
}

@HiveType(typeId: 2)
enum CallSource {
  @HiveField(0)
  app, // Initiated from our app

  @HiveField(1)
  system, // Detected from system (phone state receiver)

  @HiveField(2)
  unknown,
}
