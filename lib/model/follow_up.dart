import 'package:hive/hive.dart';
import '../utils/date_utils.dart' as AppDateUtils;

class FollowUp {
  final String id;
  final String leadId;
  final DateTime dueAt;
  final String? note;
  final String status;
  final String? createdBy;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  FollowUp({
    required this.id,
    required this.leadId,
    required this.dueAt,
    this.note,
    this.status = 'PENDING',
    this.createdBy,
    this.completedAt,
    this.cancelledAt,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FollowUp.fromJson(Map<String, dynamic> json) {
    // Handle nested leadId object from API response
    String leadIdString = '';
    if (json['leadId'] != null) {
      if (json['leadId'] is String) {
        leadIdString = json['leadId'];
      } else if (json['leadId'] is Map<String, dynamic>) {
        leadIdString = json['leadId']['_id'] ?? json['leadId']['id'] ?? '';
      }
    }

    // Handle nested createdBy object from API response
    String? createdByString;
    if (json['createdBy'] != null) {
      if (json['createdBy'] is String) {
        createdByString = json['createdBy'];
      } else if (json['createdBy'] is Map<String, dynamic>) {
        createdByString =
            json['createdBy']['name'] ??
            json['createdBy']['_id'] ??
            json['createdBy']['id'];
      }
    }

    return FollowUp(
      id: json['_id'] ?? json['id'] ?? '',
      leadId: leadIdString,
      dueAt: DateTime.parse(json['dueAt']),
      note: json['note'],
      status: json['status'] ?? 'PENDING',
      createdBy: createdByString,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      cancelledAt: json['cancelledAt'] != null
          ? DateTime.parse(json['cancelledAt'])
          : null,
      metadata: json['metadata'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'leadId': leadId,
      'dueAt': dueAt.toIso8601String(),
      'note': note,
      'status': status,
      'createdBy': createdBy,
      'completedAt': completedAt?.toIso8601String(),
      'cancelledAt': cancelledAt?.toIso8601String(),
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  FollowUp copyWith({
    String? id,
    String? leadId,
    DateTime? dueAt,
    String? note,
    String? status,
    String? createdBy,
    DateTime? completedAt,
    DateTime? cancelledAt,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FollowUp(
      id: id ?? this.id,
      leadId: leadId ?? this.leadId,
      dueAt: dueAt ?? this.dueAt,
      note: note ?? this.note,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get statusText {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 'Pending';
      case 'DONE':
        return 'Done';
      case 'CANCELLED':
        return 'Cancelled';
      default:
        return status;
    }
  }

  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isDone => status.toUpperCase() == 'DONE';
  bool get isCancelled => status.toUpperCase() == 'CANCELLED';

  // Resolution logic using metadata
  bool get isResolved {
    return metadata?['resolutionStatus'] == 'RESOLVED';
  }

  bool get isUnresolved {
    return !isResolved;
  }

  String get resolutionStatus {
    return metadata?['resolutionStatus'] ?? 'UNRESOLVED';
  }

  DateTime? get resolvedAt {
    final resolvedAtStr = metadata?['resolvedAt'];
    return resolvedAtStr != null ? DateTime.parse(resolvedAtStr) : null;
  }

  String? get resolvedBy => metadata?['resolvedBy'];
  String? get resolutionReason => metadata?['resolutionReason'];

  String get resolutionDisplayText {
    switch (resolutionStatus) {
      case 'RESOLVED':
        return 'Resolved';
      case 'UNRESOLVED':
        return 'Unresolved';
      default:
        return 'Unknown';
    }
  }

  String get formattedDueDate {
    return AppDateUtils.DateUtils.formatRelativeToIST(dueAt);
  }

  @override
  String toString() {
    return 'FollowUp(id: $id, leadId: $leadId, dueAt: $dueAt, status: $status)';
  }
}

/// Hive TypeAdapter for FollowUp (typeId: 7)
class FollowUpAdapter extends TypeAdapter<FollowUp> {
  @override
  final int typeId = 7;

  @override
  FollowUp read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      final key = reader.readByte();
      fields[key] = reader.read();
    }

    return FollowUp(
      id: fields[0] as String? ?? '',
      leadId: fields[1] as String? ?? '',
      dueAt: (fields[2] as DateTime?) ?? DateTime.now(),
      note: fields[3] as String?,
      status: fields[4] as String? ?? 'PENDING',
      createdBy: fields[5] as String?,
      completedAt: fields[6] as DateTime?,
      cancelledAt: fields[7] as DateTime?,
      metadata: (fields[8] as Map?)?.cast<String, dynamic>(),
      createdAt: (fields[9] as DateTime?) ?? DateTime.now(),
      updatedAt: (fields[10] as DateTime?) ?? DateTime.now(),
    );
  }

  @override
  void write(BinaryWriter writer, FollowUp obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.leadId)
      ..writeByte(2)
      ..write(obj.dueAt)
      ..writeByte(3)
      ..write(obj.note)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.createdBy)
      ..writeByte(6)
      ..write(obj.completedAt)
      ..writeByte(7)
      ..write(obj.cancelledAt)
      ..writeByte(8)
      ..write(obj.metadata)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.updatedAt);
  }
}
