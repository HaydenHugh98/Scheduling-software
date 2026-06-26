import '../models/daily_record.dart';
import '../models/custom_shift_type.dart';
import 'notification_service_interface.dart';

class NotificationServiceWeb implements NotificationServiceInterface {
  @override
  Future<void> init() async {}

  @override
  Future<void> showShiftReminder(
    DailyRecord record,
    CustomShiftType shift,
    int minutesBefore,
  ) async {}

  @override
  Future<void> showOvertimeReminder(
    DailyRecord record,
    CustomShiftType shift,
    int overtimeThreshold,
  ) async {}

  @override
  Future<void> cancelAllNotifications() async {}
}