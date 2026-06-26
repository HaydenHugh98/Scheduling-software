import 'package:hive/hive.dart';

part 'custom_shift_type.g.dart';

@HiveType(typeId: 2)
class CustomShiftType {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String colorHex;

  @HiveField(3)
  final String defaultStart;

  @HiveField(4)
  final String defaultEnd;

  @HiveField(5)
  final bool isDefault;

  @HiveField(6)
  final int restMinutes;

  @HiveField(7)  // 新增：版本号
  final int version;

  @HiveField(8)  // 新增：是否当前使用
  final bool isActive;

  CustomShiftType({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.defaultStart,
    required this.defaultEnd,
    this.isDefault = false,
    this.restMinutes = 0,
    this.version = 1,
    this.isActive = true,
  });

  CustomShiftType copyWith({
    String? id,
    String? name,
    String? colorHex,
    String? defaultStart,
    String? defaultEnd,
    bool? isDefault,
    int? restMinutes,
    int? version,
    bool? isActive,
  }) {
    return CustomShiftType(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      defaultStart: defaultStart ?? this.defaultStart,
      defaultEnd: defaultEnd ?? this.defaultEnd,
      isDefault: isDefault ?? this.isDefault,
      restMinutes: restMinutes ?? this.restMinutes,
      version: version ?? this.version,
      isActive: isActive ?? this.isActive,
    );
  }
}