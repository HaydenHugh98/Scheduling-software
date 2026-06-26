import 'package:hive/hive.dart';

part 'reminder_settings.g.dart';

@HiveType(typeId: 3)
class ReminderSettings {
  @HiveField(0)
  final bool enabled;

  @HiveField(1)
  final int minutesBefore;

  @HiveField(2)
  final bool remindOvertime;

  @HiveField(3)
  final int overtimeThreshold;

  @HiveField(4)
  final bool showColleaguesWhenResting; // 新增：休息时显示当班同事

  ReminderSettings({
    this.enabled = true,
    this.minutesBefore = 30,
    this.remindOvertime = true,
    this.overtimeThreshold = 60,
    this.showColleaguesWhenResting = false, // 默认关闭
  });

  ReminderSettings copyWith({
    bool? enabled,
    int? minutesBefore,
    bool? remindOvertime,
    int? overtimeThreshold,
    bool? showColleaguesWhenResting,
  }) {
    return ReminderSettings(
      enabled: enabled ?? this.enabled,
      minutesBefore: minutesBefore ?? this.minutesBefore,
      remindOvertime: remindOvertime ?? this.remindOvertime,
      overtimeThreshold: overtimeThreshold ?? this.overtimeThreshold,
      showColleaguesWhenResting: showColleaguesWhenResting ?? this.showColleaguesWhenResting,
    );
  }
}