// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lead.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LeadAdapter extends TypeAdapter<Lead> {
  @override
  final int typeId = 3;

  @override
  Lead read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Lead(
      id: fields[0] as String?,
      firstName: fields[1] as String,
      lastName: fields[2] as String,
      phoneNumber: fields[3] as String,
      email: fields[4] as String?,
      company: fields[5] as String?,
      class_: fields[24] as String?,
      city: fields[25] as String?,
      status: fields[6] as String,
      remark: fields[7] as String?,
      callStatus: fields[8] as String,
      createdAt: fields[9] as DateTime?,
      updatedAt: fields[10] as DateTime?,
      lastContactedAt: fields[11] as DateTime?,
      isSynced: fields[12] as bool,
      syncedAt: fields[13] as DateTime?,
      syncAttempts: fields[14] as int,
      syncError: fields[15] as String?,
      metadata: (fields[16] as Map?)?.cast<String, dynamic>(),
      assignedTo: fields[17] as String?,
      source: fields[18] as String?,
      priority: fields[19] as int,
      followUpDate: fields[20] as DateTime?,
      reminderScheduled: fields[21] as bool,
      reminderMessage: fields[22] as String?,
      reminderIntervalDays: fields[23] as int,
      hasAnsweredCall: fields[26] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Lead obj) {
    writer
      ..writeByte(27)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.firstName)
      ..writeByte(2)
      ..write(obj.lastName)
      ..writeByte(3)
      ..write(obj.phoneNumber)
      ..writeByte(4)
      ..write(obj.email)
      ..writeByte(5)
      ..write(obj.company)
      ..writeByte(24)
      ..write(obj.class_)
      ..writeByte(25)
      ..write(obj.city)
      ..writeByte(6)
      ..write(obj.status)
      ..writeByte(7)
      ..write(obj.remark)
      ..writeByte(8)
      ..write(obj.callStatus)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.updatedAt)
      ..writeByte(11)
      ..write(obj.lastContactedAt)
      ..writeByte(12)
      ..write(obj.isSynced)
      ..writeByte(13)
      ..write(obj.syncedAt)
      ..writeByte(14)
      ..write(obj.syncAttempts)
      ..writeByte(15)
      ..write(obj.syncError)
      ..writeByte(16)
      ..write(obj.metadata)
      ..writeByte(17)
      ..write(obj.assignedTo)
      ..writeByte(18)
      ..write(obj.source)
      ..writeByte(19)
      ..write(obj.priority)
      ..writeByte(20)
      ..write(obj.followUpDate)
      ..writeByte(21)
      ..write(obj.reminderScheduled)
      ..writeByte(22)
      ..write(obj.reminderMessage)
      ..writeByte(23)
      ..write(obj.reminderIntervalDays)
      ..writeByte(26)
      ..write(obj.hasAnsweredCall);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class LeadStatusAdapter extends TypeAdapter<LeadStatus> {
  @override
  final int typeId = 4;

  @override
  LeadStatus read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LeadStatus(
      id: fields[0] as String?,
      name: fields[1] as String,
      type: fields[2] as String,
      color: fields[3] as String?,
      order: fields[4] as int,
      isActive: fields[5] as bool,
      createdAt: fields[6] as DateTime?,
      updatedAt: fields[7] as DateTime?,
      isSynced: fields[8] as bool,
      syncedAt: fields[9] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, LeadStatus obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.color)
      ..writeByte(4)
      ..write(obj.order)
      ..writeByte(5)
      ..write(obj.isActive)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.updatedAt)
      ..writeByte(8)
      ..write(obj.isSynced)
      ..writeByte(9)
      ..write(obj.syncedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeadStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
