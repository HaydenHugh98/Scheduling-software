import '../models/daily_record.dart';
import '../models/custom_shift_type.dart';

abstract class NotificationServiceInterface {
  Future<void> init();
  Future<void> showShiftReminder(
    DailyRecord record,
    CustomShiftType shift,
    int minutesBefore,
  );
  Future<void> showOvertimeReminder(
    DailyRecord record,
    CustomShiftType shift,
    int overtimeThreshold,
  );
  Future<void> cancelAllNotifications();
}