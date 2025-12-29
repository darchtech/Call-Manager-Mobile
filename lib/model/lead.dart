import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'lead.g.dart';

@HiveType(typeId: 3)
class Lead extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String firstName;

  @HiveField(2)
  String lastName;

  @HiveField(3)
  String phoneNumber;

  @HiveField(4)
  String? email;

  @HiveField(5)
  String? company;

  @HiveField(24)
  String? class_;

  @HiveField(25)
  String? city;

  @HiveField(6)
  String status;

  @HiveField(7)
  String? remark;

  @HiveField(8)
  String callStatus;

  @HiveField(9)
  DateTime createdAt;

  @HiveField(10)
  DateTime updatedAt;

  @HiveField(11)
  DateTime? lastContactedAt;

  @HiveField(12)
  bool isSynced;

  @HiveField(13)
  DateTime? syncedAt;

  @HiveField(14)
  int syncAttempts;

  @HiveField(15)
  String? syncError;

  @HiveField(16)
  Map<String, dynamic>? metadata;

  @HiveField(17)
  String? assignedTo;

  @HiveField(18)
  String? source;

  @HiveField(19)
  int priority;

  @HiveField(20)
  DateTime? followUpDate;

  @HiveField(21)
  bool reminderScheduled;

  @HiveField(22)
  String? reminderMessage;

  @HiveField(23)
  int reminderIntervalDays;

  @HiveField(26)
  bool hasAnsweredCall;

  Lead({
    String? id,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    this.email,
    this.company,
    this.class_,
    this.city,
    required this.status,
    this.remark,
    required this.callStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.lastContactedAt,
    this.isSynced = false,
    this.syncedAt,
    this.syncAttempts = 0,
    this.syncError,
    this.metadata,
    this.assignedTo,
    this.source,
    this.priority = 0,
    this.followUpDate,
    this.reminderScheduled = false,
    this.reminderMessage,
    this.reminderIntervalDays = 7,
    this.hasAnsweredCall = false,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Update lead status
  void updateStatus(String newStatus, {String? remark}) {
    status = newStatus;
    if (remark != null) {
      this.remark = remark;
    }
    updatedAt = DateTime.now();
    isSynced = false;
    syncError = null;
  }

  /// Update call status
  void updateCallStatus(String newCallStatus) {
    callStatus = newCallStatus;
    // Only ever flip hasAnsweredCall from false -> true when we detect CONTACTED
    final category = Lead.mapCallStatusToCategory(newCallStatus);
    final becameContacted = (category == 'CONTACTED') && !hasAnsweredCall;
    if (becameContacted) {
      hasAnsweredCall = true;
      lastContactedAt = DateTime.now();
    }
    updatedAt = DateTime.now();
    isSynced = false;
    syncError = null;
  }

  /// Categorize call status for reporting/UI consistency
  /// Categories: CONTACTED, CALLED, NO ANSWER, NOT CONTACTED
  String get callStatusCategory {
    return Lead.mapCallStatusToCategory(callStatus);
  }

  /// Map granular call status strings into high-level categories
  static String mapCallStatusToCategory(String status) {
    final s = status.toUpperCase();

    // CONTACTED: Call was answered and connected (regardless of who ended it)
    if (s == 'CALLED' ||
        s == 'CALL_ENDED_CONNECTED' ||
        s == 'CALL_CONNECTED' ||
        s == 'CALL_ENDED_BY_CALLER' ||
        s == 'CALL_ENDED_BY_CALLEE') {
      return 'CONTACTED';
    }

    // NO ANSWER: Call rang but wasn't answered, or was busy
    if (s == 'CALL_NO_ANSWER' ||
        s == 'CALL_ENDED_NO_ANSWER' ||
        s == 'CALL_BUSY' ||
        s == 'MISSED') {
      return 'NO ANSWER';
    }

    // CALLED: Call was attempted but not connected (cancelled by caller before answer)
    if (s == 'CALL_DIALING' || s == 'CALL_CONNECTING') {
      return 'CALLED';
    }

    // NOT CONTACTED: Call was declined by callee before answer, or never attempted
    if (s == 'CALL_CANCELLED_BY_CALLER' ||
        s == 'CALL_DECLINED_BY_LEAD' ||
        s == 'CALL_DECLINED_BY_CALLEE' ||
        s == 'CALL_DECLINED_BY_CALLER' ||
        s == 'NOT CALLED' ||
        s == 'NOT_CONTACTED') {
      return 'NOT CONTACTED';
    }

    // Fallbacks
    if (s == 'NOT CALLED' || s == 'UNASSIGNED' || s.isEmpty) {
      return 'NOT CONTACTED';
    }

    return 'CALLED';
  }

  /// Add or update remark
  void updateRemark(String newRemark) {
    remark = newRemark;
    updatedAt = DateTime.now();
    isSynced = false;
    syncError = null;
  }

  /// Mark as synced
  void markSynced({String? error}) {
    isSynced = error == null;
    syncedAt = error == null ? DateTime.now() : null;
    syncAttempts += 1;
    syncError = error;
  }

  /// Convert to Map for API sync
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': phoneNumber,
      'email': email,
      'company': company,
      'class': class_,
      'city': city,
      'status': status,
      'remark': remark,
      'callStatus': callStatus,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastContactedAt': lastContactedAt?.toIso8601String(),
      'metadata': metadata,
      'assignedTo': assignedTo,
      'source': source,
      'priority': priority,
      'followUpDate': followUpDate?.toIso8601String(),
      'reminderScheduled': reminderScheduled,
      'reminderMessage': reminderMessage,
      'reminderIntervalDays': reminderIntervalDays,
      'hasAnsweredCall': hasAnsweredCall,
    };
  }

  /// Create from JSON (for API responses)
  static Lead fromJson(Map<String, dynamic> json) {
    return Lead(
      id: json['_id'] ?? json['id'],
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      phoneNumber: json['phoneNumber'],
      email: json['email'],
      company: json['company'],
      class_: json['class'],
      city: json['city'],
      status: json['status'],
      remark: json['remark'],
      callStatus: json['callStatus'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      lastContactedAt: json['lastContactedAt'] != null
          ? DateTime.parse(json['lastContactedAt'])
          : null,
      isSynced: true, // Assume synced if coming from API
      syncedAt: DateTime.now(),
      metadata: json['metadata']?.cast<String, dynamic>(),
      assignedTo: json['assignedTo'],
      source: json['source'],
      priority: json['priority'] ?? 0,
      followUpDate: json['followUpDate'] != null
          ? DateTime.parse(json['followUpDate'])
          : null,
      reminderScheduled: json['reminderScheduled'] ?? false,
      reminderMessage: json['reminderMessage'],
      reminderIntervalDays: json['reminderIntervalDays'] ?? 7,
      hasAnsweredCall:
          json['hasAnsweredCall'] ??
          (Lead.mapCallStatusToCategory(json['callStatus'] ?? '') ==
              'CONTACTED'),
    );
  }

  /// Get display name (firstName + lastName or phone number)
  String get displayName {
    final fullName = '$firstName $lastName'.trim();
    return fullName.isNotEmpty ? fullName : phoneNumber;
  }

  /// Get formatted phone number
  String get formattedPhoneNumber {
    // Basic phone number formatting
    final cleaned = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length >= 10) {
      return '${cleaned.substring(0, 3)}-${cleaned.substring(3, 6)}-${cleaned.substring(6)}';
    }
    return phoneNumber;
  }

  /// Check if lead needs follow-up
  bool get needsFollowUp {
    if (lastContactedAt == null) return true;
    final daysSinceContact = DateTime.now().difference(lastContactedAt!).inDays;
    return daysSinceContact >= reminderIntervalDays;
  }

  /// Set follow-up date and schedule reminder
  void setFollowUpDate(DateTime date, {String? message}) {
    followUpDate = date;
    reminderMessage = message;
    reminderScheduled = true;
    updatedAt = DateTime.now();
    isSynced = false;
    syncError = null;
  }

  /// Cancel follow-up reminder
  void cancelFollowUpReminder() {
    followUpDate = null;
    reminderScheduled = false;
    reminderMessage = null;
    updatedAt = DateTime.now();
    isSynced = false;
    syncError = null;
  }

  /// Update reminder interval
  void updateReminderInterval(int days) {
    reminderIntervalDays = days;
    updatedAt = DateTime.now();
    isSynced = false;
    syncError = null;
  }

  /// Check if follow-up is overdue
  bool get isFollowUpOverdue {
    if (followUpDate == null) return false;
    return DateTime.now().isAfter(followUpDate!);
  }

  /// Get days until follow-up
  int get daysUntilFollowUp {
    if (followUpDate == null) return -1;
    return followUpDate!.difference(DateTime.now()).inDays;
  }

  /// Get priority text
  String get priorityText {
    switch (priority) {
      case 3:
        return 'High';
      case 2:
        return 'Medium';
      case 1:
        return 'Low';
      default:
        return 'Normal';
    }
  }

  /// Get status color (for UI)
  String get statusColor {
    switch (status.toLowerCase()) {
      case 'contacted':
        return '#4CAF50'; // Green
      case 'not interested':
        return '#F44336'; // Red
      case 'follow up':
        return '#FF9800'; // Orange
      case 'qualified':
        return '#2196F3'; // Blue
      case 'converted':
        return '#9C27B0'; // Purple
      default:
        return '#757575'; // Grey
    }
  }

  @override
  String toString() {
    return 'Lead{id: $id, firstName: $firstName, lastName: $lastName, phoneNumber: $phoneNumber, status: $status, callStatus: $callStatus, synced: $isSynced}';
  }
}

@HiveType(typeId: 4)
class LeadStatus extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String type; // 'leadStatus' or 'callStatus'

  @HiveField(3)
  String? color;

  @HiveField(4)
  int order;

  @HiveField(5)
  bool isActive;

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  DateTime updatedAt;

  @HiveField(8)
  bool isSynced;

  @HiveField(9)
  DateTime? syncedAt;

  LeadStatus({
    String? id,
    required this.name,
    required this.type,
    this.color,
    this.order = 0,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isSynced = false,
    this.syncedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Convert to Map for API sync
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'color': color,
      'order': order,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create from JSON (for API responses)
  static LeadStatus fromJson(Map<String, dynamic> json) {
    return LeadStatus(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      color: json['color'],
      order: json['order'] ?? 0,
      isActive: json['isActive'] ?? true,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      isSynced: true,
      syncedAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'LeadStatus{id: $id, name: $name, type: $type, active: $isActive}';
  }
}
