// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reminder_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReminderSettingsAdapter extends TypeAdapter<ReminderSettings> {
  @override
  final int typeId = 3;

  @override
  ReminderSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReminderSettings(
      enabled: fields[0] as bool,
      minutesBefore: fields[1] as int,
      remindOvertime: fields[2] as bool,
      overtimeThreshold: fields[3] as int,
      showColleaguesWhenResting: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ReminderSettings obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.enabled)
      ..writeByte(1)
      ..write(obj.minutesBefore)
      ..writeByte(2)
      ..write(obj.remindOvertime)
      ..writeByte(3)
      ..write(obj.overtimeThreshold)
      ..writeByte(4)
      ..write(obj.showColleaguesWhenResting);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
