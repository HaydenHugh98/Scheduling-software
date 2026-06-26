// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DailyRecordAdapter extends TypeAdapter<DailyRecord> {
  @override
  final int typeId = 1;

  @override
  DailyRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyRecord(
      id: fields[0] as String,
      userId: fields[1] as String,
      date: fields[2] as DateTime,
      shiftTypeId: fields[3] as String,
      startTime: fields[4] as String?,
      endTime: fields[5] as String?,
      partnerIds: (fields[6] as List?)?.cast<String>(),
      overtimeMinutes: fields[7] as int,
      memo: fields[8] as String?,
      memoCompleted: fields[9] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, DailyRecord obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.shiftTypeId)
      ..writeByte(4)
      ..write(obj.startTime)
      ..writeByte(5)
      ..write(obj.endTime)
      ..writeByte(6)
      ..write(obj.partnerIds)
      ..writeByte(7)
      ..write(obj.overtimeMinutes)
      ..writeByte(8)
      ..write(obj.memo)
      ..writeByte(9)
      ..write(obj.memoCompleted);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
