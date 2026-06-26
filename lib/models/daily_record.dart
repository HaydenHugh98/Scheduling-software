import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

part 'daily_record.g.dart';

@HiveType(typeId: 1)
class DailyRecord {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String userId;

  @HiveField(2)
  final DateTime date;

  @HiveField(3)
  final String shiftTypeId;

  @HiveField(4)
  final String? startTime;

  @HiveField(5)
  final String? endTime;

  @HiveField(6)
  final List<String>? partnerIds; // 改为 List，支持多个搭伴

  @HiveField(7)
  final int overtimeMinutes;

  @HiveField(8)
  final String? memo;

  @HiveField(9)
  final bool memoCompleted;

  DailyRecord({
    required this.id,
    required this.userId,
    required this.date,
    required this.shiftTypeId,
    this.startTime,
    this.endTime,
    this.partnerIds,
    this.overtimeMinutes = 0,
    this.memo,
    this.memoCompleted = false,
  });

  DailyRecord copyWith({
    String? id,
    String? userId,
    DateTime? date,
    String? shiftTypeId,
    String? startTime,
    String? endTime,
    List<String>? partnerIds,
    int? overtimeMinutes,
    String? memo,
    bool? memoCompleted,
  }) {
    return DailyRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      shiftTypeId: shiftTypeId ?? this.shiftTypeId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      partnerIds: partnerIds ?? this.partnerIds,
      overtimeMinutes: overtimeMinutes ?? this.overtimeMinutes,
      memo: memo ?? this.memo,
      memoCompleted: memoCompleted ?? this.memoCompleted,
    );
  }
}