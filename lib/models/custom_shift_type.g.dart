// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'custom_shift_type.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CustomShiftTypeAdapter extends TypeAdapter<CustomShiftType> {
  @override
  final int typeId = 2;

  @override
  CustomShiftType read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CustomShiftType(
      id: fields[0] as String,
      name: fields[1] as String,
      colorHex: fields[2] as String,
      defaultStart: fields[3] as String,
      defaultEnd: fields[4] as String,
      isDefault: fields[5] as bool,
      restMinutes: fields[6] as int,
      version: fields[7] as int,
      isActive: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, CustomShiftType obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.colorHex)
      ..writeByte(3)
      ..write(obj.defaultStart)
      ..writeByte(4)
      ..write(obj.defaultEnd)
      ..writeByte(5)
      ..write(obj.isDefault)
      ..writeByte(6)
      ..write(obj.restMinutes)
      ..writeByte(7)
      ..write(obj.version)
      ..writeByte(8)
      ..write(obj.isActive);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomShiftTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
