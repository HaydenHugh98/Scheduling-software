import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/daily_record.dart';
import '../models/custom_shift_type.dart';
import 'notification_service_interface.dart';

class NotificationServiceMobile implements NotificationServiceInterface {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  @override
  Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings);
  }

  @override
  Future<void> showShiftReminder(
    DailyRecord record,
    CustomShiftType shift,
    int minutesBefore,
  ) async {
    final now = DateTime.now();
    final startTime = _parseTime(record.startTime ?? shift.defaultStart);
    final reminderTime = DateTime(
      record.date.year,
      record.date.month,
      record.date.day,
      startTime.hour,
      startTime.minute,
    ).subtract(Duration(minutes: minutesBefore));

    if (reminderTime.isBefore(now)) return;

    final tz.TZDateTime scheduledTime = tz.TZDateTime.from(reminderTime, tz.local);

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'shift_reminder_channel',
      '排班提醒',
      channelDescription: '排班开始前提醒',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      record.id.hashCode,
      '排班提醒',
      '${shift.name} 将于 ${DateFormat('HH:mm').format(reminderTime)} 开始',
      scheduledTime,
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidAllowWhileIdle: true,
    );
  }

  @override
  Future<void> showOvertimeReminder(
    DailyRecord record,
    CustomShiftType shift,
    int overtimeThreshold,
  ) async {
    if (record.overtimeMinutes < overtimeThreshold) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'overtime_reminder_channel',
      '加班提醒',
      channelDescription: '加班超时提醒',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      record.id.hashCode + 1,
      '加班提醒',
      '今日加班已达 ${record.overtimeMinutes} 分钟，超过设定阈值 ${overtimeThreshold} 分钟',
      details,
    );
  }

  @override
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  TimeOfDay _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length != 2) return const TimeOfDay(hour: 8, minute: 0);
      return TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    } catch (e) {
      return const TimeOfDay(hour: 8, minute: 0);
    }
  }
}