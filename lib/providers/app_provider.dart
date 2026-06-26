import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/daily_record.dart';
import '../models/custom_shift_type.dart';
import '../models/reminder_settings.dart';
import '../database/db_provider.dart';
import '../services/notification_service.dart';

class AppProvider extends ChangeNotifier {
  User? _currentUser;
  DateTime _selectedDate = DateTime.now();
  DateTime _viewDate = DateTime.now();
  String _viewMode = 'month';

  User? get currentUser => _currentUser;
  DateTime get selectedDate => _selectedDate;
  DateTime get viewDate => _viewDate;
  String get viewMode => _viewMode;

  AppProvider() {
    _initCurrentUser();
  }

  void _initCurrentUser() {
    try {
      _currentUser = DBProvider.getMe();
    } catch (e) {
      final me = User(
        id: 'me_${DateTime.now().millisecondsSinceEpoch}',
        name: '我',
        isMe: true,
        avatarColor: '#4CAF50',
      );
      DBProvider.addUser(me);
      _currentUser = me;
    }
    notifyListeners();
  }

  // ---- 用户切换 ----
  void switchUser(User user) {
    _currentUser = user;
    notifyListeners();
  }

  void switchToMe() {
    _currentUser = DBProvider.getMe();
    notifyListeners();
  }

  // ---- 日期设置 ----
  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  void setViewDate(DateTime date) {
    _viewDate = date;
    notifyListeners();
  }

  void setViewMode(String mode) {
    _viewMode = mode;
    notifyListeners();
  }

  // ---- 提醒设置 ----
  ReminderSettings getReminderSettings() {
    return DBProvider.getReminderSettings();
  }

  Future<void> saveReminderSettings(ReminderSettings settings) async {
    await DBProvider.saveReminderSettings(settings);
    notifyListeners();
  }

  // ---- 记录查询（单用户） ----
  DailyRecord? getRecordForDate(DateTime date) {
    if (_currentUser == null) return null;
    return DBProvider.getRecordByUserAndDate(_currentUser!.id, date);
  }

  Map<String, dynamic> getRecordWithShift(DateTime date) {
    final record = getRecordForDate(date);
    CustomShiftType? shift;
    if (record != null) {
      shift = DBProvider.getShiftType(record.shiftTypeId);
    }
    return {
      'record': record,
      'shift': shift,
    };
  }

  Map<String, dynamic> getRecordWithPartners(DateTime date) {
    final record = getRecordForDate(date);
    List<User?> partners = [];
    if (record != null && record.partnerIds != null) {
      partners = record.partnerIds!.map((id) => DBProvider.getUser(id)).toList();
    }
    return {
      'record': record,
      'partners': partners,
    };
  }

  // ---- 获取当前用户的“搭班同事” ----
  List<Map<String, dynamic>> getWorkingColleagues(DateTime date) {
    if (_currentUser == null) return [];
    return DBProvider.getWorkingColleagues(_currentUser!.id, date);
  }

  // ---- 多用户查询 ----
  List<DailyRecord> getRecordsForDate(DateTime date) {
    return DBProvider.getRecordsByDate(date);
  }

  // ---- 统计方法 ----
  Map<String, dynamic> getStatsForDateRange(DateTime start, DateTime end) {
    if (_currentUser == null) return {};
    return DBProvider.getStats(_currentUser!.id, start, end);
  }

  Map<String, dynamic> getStatsForMonth(int year, int month) {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0);
    return getStatsForDateRange(start, end);
  }

  Map<String, dynamic> getStatsForWeek(DateTime date) {
    final start = date.subtract(Duration(days: date.weekday - 1));
    final end = start.add(const Duration(days: 6));
    return getStatsForDateRange(start, end);
  }

  Map<String, dynamic> getStatsForYear(int year) {
    final start = DateTime(year, 1, 1);
    final end = DateTime(year, 12, 31);
    return getStatsForDateRange(start, end);
  }

  // ---- 获取每日工时列表（仅正常工时） ----
  Map<DateTime, double> getDailyWorkHours(DateTime start, DateTime end) {
    if (_currentUser == null) return {};
    return DBProvider.getDailyWorkHours(_currentUser!.id, start, end);
  }

  // ---- 获取每日正常工时和加班工时（用于堆叠柱状图） ----
  Map<DateTime, Map<String, double>> getDailyWorkAndOvertime(DateTime start, DateTime end) {
    if (_currentUser == null) return {};
    return DBProvider.getDailyWorkAndOvertime(_currentUser!.id, start, end);
  }

  // ---- 判断当前用户当天是否上班 ----
  bool isMeWorking(DateTime date) {
    if (_currentUser == null) return false;
    final record = getRecordForDate(date);
    if (record == null) return false;
    if (record.shiftTypeId.isEmpty) return false;
    final shift = DBProvider.getShiftType(record.shiftTypeId);
    return shift != null && shift.name != '休息';
  }

  // ---- 批量保存排班（带提醒） ----
  Future<void> saveRecords(List<DailyRecord> records) async {
    await DBProvider.saveRecords(records);
    notifyListeners();

    // 触发提醒
    final settings = getReminderSettings();
    if (settings.enabled) {
      for (var record in records) {
        final shift = DBProvider.getShiftType(record.shiftTypeId);
        if (shift == null || shift.name == '休息') continue;

        await notificationService.showShiftReminder(
          record,
          shift,
          settings.minutesBefore,
        );

        if (settings.remindOvertime && record.overtimeMinutes > 0) {
          await notificationService.showOvertimeReminder(
            record,
            shift,
            settings.overtimeThreshold,
          );
        }
      }
    }
  }

  // ---- 单条保存排班 ----
  Future<void> saveRecord(DailyRecord record) async {
    await DBProvider.saveRecord(record);
    notifyListeners();

    final settings = getReminderSettings();
    if (settings.enabled) {
      final shift = DBProvider.getShiftType(record.shiftTypeId);
      if (shift != null && shift.name != '休息') {
        await notificationService.showShiftReminder(
          record,
          shift,
          settings.minutesBefore,
        );
        if (settings.remindOvertime && record.overtimeMinutes > 0) {
          await notificationService.showOvertimeReminder(
            record,
            shift,
            settings.overtimeThreshold,
          );
        }
      }
    }
  }

  Future<void> deleteRecord(String id) async {
    await DBProvider.deleteRecord(id);
    notifyListeners();
  }

  // ---- 用户管理 ----
  List<User> getAllUsers() {
    return DBProvider.getAllUsers();
  }

  Future<void> addUser(User user) async {
    await DBProvider.addUser(user);
    notifyListeners();
  }

  Future<void> deleteUser(String userId) async {
    await DBProvider.deleteUser(userId);
    if (_currentUser?.id == userId) {
      _initCurrentUser();
    }
    notifyListeners();
  }

  // ---- 自定义班次管理（原有） ----
  List<CustomShiftType> getAllShiftTypes() {
    return DBProvider.getAllShiftTypes();
  }

  CustomShiftType? getShiftType(String id) {
    if (id.isEmpty) return null;
    return DBProvider.getShiftType(id);
  }

  Future<void> saveShiftType(CustomShiftType type) async {
    await DBProvider.saveShiftType(type);
    notifyListeners();
  }

  Future<void> deleteShiftType(String id) async {
    await DBProvider.deleteShiftType(id);
    notifyListeners();
  }

  // ========== 新增：班次版本管理 ==========

  // ---- 获取当前使用的班次列表 ----
  List<CustomShiftType> getActiveShiftTypes() {
    return DBProvider.getActiveShiftTypes();
  }

  // ---- 获取历史班次列表 ----
  List<CustomShiftType> getInactiveShiftTypes() {
    return DBProvider.getInactiveShiftTypes();
  }

  // ---- 编辑班次（创建新版本） ----
  Future<CustomShiftType> editShiftType(
    String oldId,
    String newName,
    String newColorHex,
    String newDefaultStart,
    String newDefaultEnd,
    int newRestMinutes,
  ) async {
    final result = await DBProvider.editShiftType(
      oldId,
      newName,
      newColorHex,
      newDefaultStart,
      newDefaultEnd,
      newRestMinutes,
    );
    notifyListeners();
    return result;
  }

  // ---- 获取班次的显示名称（含版本信息） ----
  String getShiftDisplayName(String id) {
    return DBProvider.getShiftDisplayName(id);
  }

  // ---- 日历视图辅助 ----
  List<DailyRecord> getRecordsForMonth(int year, int month) {
    if (_currentUser == null) return [];
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0);
    return DBProvider.getRecordsByUserAndDateRange(
      _currentUser!.id,
      start,
      end,
    );
  }

  List<DailyRecord> getRecordsForDateRange(DateTime start, DateTime end) {
    if (_currentUser == null) return [];
    return DBProvider.getRecordsByUserAndDateRange(
      _currentUser!.id,
      start,
      end,
    );
  }
}