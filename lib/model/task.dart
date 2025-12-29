import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

@HiveType(typeId: 5)
class Task extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String? description;

  @HiveField(3)
  String status; // e.g., 'open', 'inProgress', 'done'

  @HiveField(4)
  int priority; // 0=normal, 1=low, 2=medium, 3=high

  @HiveField(5)
  String? leadId;

  @HiveField(6)
  DateTime? dueAt;

  @HiveField(7)
  DateTime createdAt;

  @HiveField(8)
  DateTime updatedAt;

  @HiveField(9)
  bool isSynced;

  @HiveField(10)
  DateTime? syncedAt;

  // Optional progress/counts coming from API
  @HiveField(11)
  int? completedCount;

  @HiveField(12)
  int? totalCount;

  // Optional related lead ids array from API (besides primary leadId)
  @HiveField(13)
  List<String>? relatedLeadIds;

  Task({
    String? id,
    required this.title,
    this.description,
    this.status = 'open',
    this.priority = 0,
    this.leadId,
    this.dueAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isSynced = true,
    this.syncedAt,
    this.completedCount,
    this.totalCount,
    this.relatedLeadIds,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  // Update task status locally and mark for sync
  void updateStatus(String newStatus) {
    status = newStatus;
    updatedAt = DateTime.now();
    isSynced = false;
  }

  // Mark as synced (optional error is ignored in lightweight model)
  void markSynced({String? error}) {
    if (error == null) {
      isSynced = true;
      syncedAt = DateTime.now();
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status,
      'priority': priority,
      'leadId': leadId,
      'dueAt': dueAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'completedCount': completedCount,
      'totalCount': totalCount,
      'leadIds': relatedLeadIds,
    };
  }

  static Task fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] ?? json['_id'],
      title: json['title'],
      description: json['description'],
      status: json['status'] ?? 'open',
      priority: json['priority'] ?? 0,
      leadId: json['leadId'],
      dueAt: json['dueAt'] != null ? DateTime.parse(json['dueAt']) : null,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      isSynced: true,
      syncedAt: DateTime.now(),
      completedCount: json['completedCount'],
      totalCount: json['totalCount'],
      relatedLeadIds: json['leadIds'] is List
          ? (json['leadIds'] as List)
                .map(
                  (e) => e is String
                      ? e
                      : (e is Map<String, dynamic>
                            ? (e['_id'] ?? e['id'] ?? '').toString()
                            : e.toString()),
                )
                .where((id) => id.isNotEmpty)
                .toList()
          : null,
    );
  }
}

class TaskAdapter extends TypeAdapter<Task> {
  @override
  final int typeId = 5;

  @override
  Task read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Task(
      id: fields[0] as String?,
      title: fields[1] as String,
      description: fields[2] as String?,
      status: fields[3] as String,
      priority: fields[4] as int,
      leadId: fields[5] as String?,
      dueAt: fields[6] as DateTime?,
      createdAt: fields[7] as DateTime?,
      updatedAt: fields[8] as DateTime?,
      isSynced: fields[9] as bool,
      syncedAt: fields[10] as DateTime?,
      completedCount: fields[11] as int?,
      totalCount: fields[12] as int?,
      relatedLeadIds: (fields[13] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, Task obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.priority)
      ..writeByte(5)
      ..write(obj.leadId)
      ..writeByte(6)
      ..write(obj.dueAt)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt)
      ..writeByte(9)
      ..write(obj.isSynced)
      ..writeByte(10)
      ..write(obj.syncedAt)
      ..writeByte(11)
      ..write(obj.completedCount)
      ..writeByte(12)
      ..write(obj.totalCount)
      ..writeByte(13)
      ..write(obj.relatedLeadIds);
  }
}
