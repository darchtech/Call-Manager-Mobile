// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'call_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CallRecordAdapter extends TypeAdapter<CallRecord> {
  @override
  final int typeId = 0;

  @override
  CallRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CallRecord(
      id: fields[0] as String?,
      phoneNumber: fields[1] as String,
      contactName: fields[2] as String?,
      initiatedAt: fields[3] as DateTime,
      connectedAt: fields[4] as DateTime?,
      endedAt: fields[5] as DateTime?,
      status: fields[7] as String,
      source: fields[8] as CallSource,
      isOutgoing: fields[9] as bool,
      deviceInfo: fields[10] as String?,
      metadata: (fields[11] as Map?)?.cast<String, dynamic>(),
      isSynced: fields[12] as bool,
      syncedAt: fields[13] as DateTime?,
      syncAttempts: fields[14] as int,
      syncError: fields[15] as String?,
    )
      ..durationSeconds = fields[6] as int?
      ..outcomeLabel = fields[16] as String?;
  }

  @override
  void write(BinaryWriter writer, CallRecord obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.phoneNumber)
      ..writeByte(2)
      ..write(obj.contactName)
      ..writeByte(3)
      ..write(obj.initiatedAt)
      ..writeByte(4)
      ..write(obj.connectedAt)
      ..writeByte(5)
      ..write(obj.endedAt)
      ..writeByte(6)
      ..write(obj.durationSeconds)
      ..writeByte(7)
      ..write(obj.status)
      ..writeByte(8)
      ..write(obj.source)
      ..writeByte(9)
      ..write(obj.isOutgoing)
      ..writeByte(10)
      ..write(obj.deviceInfo)
      ..writeByte(11)
      ..write(obj.metadata)
      ..writeByte(12)
      ..write(obj.isSynced)
      ..writeByte(13)
      ..write(obj.syncedAt)
      ..writeByte(14)
      ..write(obj.syncAttempts)
      ..writeByte(15)
      ..write(obj.syncError)
      ..writeByte(16)
      ..write(obj.outcomeLabel);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CallRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CallSourceAdapter extends TypeAdapter<CallSource> {
  @override
  final int typeId = 2;

  @override
  CallSource read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return CallSource.app;
      case 1:
        return CallSource.system;
      case 2:
        return CallSource.unknown;
      default:
        return CallSource.app;
    }
  }

  @override
  void write(BinaryWriter writer, CallSource obj) {
    switch (obj) {
      case CallSource.app:
        writer.writeByte(0);
        break;
      case CallSource.system:
        writer.writeByte(1);
        break;
      case CallSource.unknown:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CallSourceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
