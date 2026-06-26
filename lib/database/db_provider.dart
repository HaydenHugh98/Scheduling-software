import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/user.dart';
import '../models/daily_record.dart';
import '../models/custom_shift_type.dart';
import '../models/reminder_settings.dart';

class DBProvider {
  static const String userBoxName = 'users';
  static const String recordBoxName = 'records';
  static const String shiftTypeBoxName = 'shiftTypes';
  static const String reminderBoxName = 'reminderSettings';

  static Box<User>? _userBox;
  static Box<DailyRecord>? _recordBox;
  static Box<CustomShiftType>? _shiftTypeBox;
  static Box<ReminderSettings>? _reminderBox;

  static Box<User> get userBox {
    if (_userBox == null) throw Exception('Database not initialized');
    return _userBox!;
  }

  static Box<DailyRecord> get recordBox {
    if (_recordBox == null) throw Exception('Database not initialized');
    return _recordBox!;
  }

  static Box<CustomShiftType> get shiftTypeBox {
    if (_shiftTypeBox == null) throw Exception('Database not initialized');
    return _shiftTypeBox!;
  }

  static Box<ReminderSettings> get reminderBox {
    if (_reminderBox == null) throw Exception('Database not initialized');
    return _reminderBox!;
  }

  static Future<void> init() async {
    await Hive.initFlutter();

    Hive.registerAdapter(UserAdapter());
    Hive.registerAdapter(DailyRecordAdapter());
    Hive.registerAdapter(CustomShiftTypeAdapter());
    Hive.registerAdapter(ReminderSettingsAdapter());

    _userBox = await Hive.openBox<User>(userBoxName);
    _recordBox = await Hive.openBox<DailyRecord>(recordBoxName);
    _shiftTypeBox = await Hive.openBox<CustomShiftType>(shiftTypeBoxName);
    _reminderBox = await Hive.openBox<ReminderSettings>(reminderBoxName);

    if (_userBox!.isEmpty) {
      final me = User(
        id: 'me_${DateTime.now().millisecondsSinceEpoch}',
        name: '我',
        isMe: true,
        avatarColor: '#4CAF50',
      );
      await _userBox!.put(me.id, me);
    }

    // ---- 迁移提醒设置，增加 showColleaguesWhenResting 字段 ----
    await _migrateReminderSettings();

    await _initDefaultShiftTypes();
    await _migrateOldRecords();
    await _migrateShiftTypes();
  }

  static Future<void> _migrateReminderSettings() async {
    final settings = _reminderBox!.get('settings');
    if (settings != null) {
      if (settings.showColleaguesWhenResting == null) {
        final updated = settings.copyWith(showColleaguesWhenResting: false);
        await _reminderBox!.put('settings', updated);
      }
    } else {
      await _reminderBox!.put('settings', ReminderSettings());
    }
  }

  // ---- 初始化默认班次（新内容） ----
  static Future<void> _initDefaultShiftTypes() async {
    if (_shiftTypeBox!.isEmpty) {
      final defaults = [
        CustomShiftType(
          id: 'shift_main_${DateTime.now().millisecondsSinceEpoch}',
          name: '主班',
          colorHex: '#4CAF50',
          defaultStart: '08:00',
          defaultEnd: '18:00',
          isDefault: true,
          restMinutes: 150,
          version: 1,
          isActive: true,
        ),
        CustomShiftType(
          id: 'shift_night_${DateTime.now().millisecondsSinceEpoch}',
          name: '大夜',
          colorHex: '#1A237E',
          defaultStart: '20:00',
          defaultEnd: '08:00',
          isDefault: true,
          restMinutes: 0,
          version: 1,
          isActive: true,
        ),
        CustomShiftType(
          id: 'shift_small_night_${DateTime.now().millisecondsSinceEpoch}',
          name: '小夜',
          colorHex: '#6A1B9A',
          defaultStart: '18:00',
          defaultEnd: '08:00',
          isDefault: true,
          restMinutes: 360,
          version: 1,
          isActive: true,
        ),
        CustomShiftType(
          id: 'shift_responsible_${DateTime.now().millisecondsSinceEpoch}',
          name: '责护',
          colorHex: '#00897B',
          defaultStart: '08:00',
          defaultEnd: '18:00',
          isDefault: true,
          restMinutes: 150,
          version: 1,
          isActive: true,
        ),
        CustomShiftType(
          id: 'shift_morning_${DateTime.now().millisecondsSinceEpoch}',
          name: '早班',
          colorHex: '#FF9800',
          defaultStart: '08:00',
          defaultEnd: '15:00',
          isDefault: true,
          restMinutes: 0,
          version: 1,
          isActive: true,
        ),
        CustomShiftType(
          id: 'shift_afternoon_${DateTime.now().millisecondsSinceEpoch}',
          name: '中班',
          colorHex: '#2196F3',
          defaultStart: '12:00',
          defaultEnd: '20:00',
          isDefault: true,
          restMinutes: 0,
          version: 1,
          isActive: true,
        ),
        CustomShiftType(
          id: 'shift_88_${DateTime.now().millisecondsSinceEpoch}',
          name: '白88班',
          colorHex: '#F57C00',
          defaultStart: '08:00',
          defaultEnd: '20:00',
          isDefault: true,
          restMinutes: 0,
          version: 1,
          isActive: true,
        ),
        CustomShiftType(
          id: 'shift_rest_${DateTime.now().millisecondsSinceEpoch}',
          name: '休息',
          colorHex: '#9E9E9E',
          defaultStart: '',
          defaultEnd: '',
          isDefault: true,
          restMinutes: 0,
          version: 1,
          isActive: true,
        ),
      ];
      for (var type in defaults) {
        await _shiftTypeBox!.put(type.id, type);
      }
    }
  }

  // ---- 迁移旧数据（添加 version 和 isActive） ----
  static Future<void> _migrateShiftTypes() async {
    final allShifts = getAllShiftTypes();
    bool needUpdate = false;
    
    for (var shift in allShifts) {
      if (shift.version == 0 || shift.isActive == null) {
        final updated = shift.copyWith(
          version: 1,
          isActive: true,
        );
        await _shiftTypeBox!.put(updated.id, updated);
        needUpdate = true;
      }
    }
    
    final activeShifts = getActiveShiftTypes();
    final nameMap = <String, List<CustomShiftType>>{};
    for (var s in activeShifts) {
      nameMap.putIfAbsent(s.name, () => []).add(s);
    }
    
    for (var entry in nameMap.entries) {
      if (entry.value.length > 1) {
        for (int i = 1; i < entry.value.length; i++) {
          final updated = entry.value[i].copyWith(isActive: false);
          await _shiftTypeBox!.put(updated.id, updated);
          needUpdate = true;
        }
      }
    }
  }

  // ---- 迁移旧记录（兼容旧数据） ----
  static Future<void> _migrateOldRecords() async {
    final allRecords = _recordBox!.values.toList();
    for (var record in allRecords) {
      if (!record.shiftTypeId.startsWith('shift_')) {
        final defaultShifts = getAllShiftTypes();
        final enumToId = <String, String>{};
        for (var shift in defaultShifts) {
          enumToId[shift.name] = shift.id;
        }
        final newId = enumToId[record.shiftTypeId];
        if (newId != null) {
          final updated = record.copyWith(shiftTypeId: newId);
          await _recordBox!.put(updated.id, updated);
        }
      }
    }
  }

  // ---- 提醒设置 ----
  static ReminderSettings getReminderSettings() {
    return _reminderBox!.get('settings') ?? ReminderSettings();
  }

  static Future<void> saveReminderSettings(ReminderSettings settings) async {
    await _reminderBox!.put('settings', settings);
  }

  // ---- 用户操作 ----
  static Future<void> addUser(User user) async {
    await userBox.put(user.id, user);
  }

  static Future<void> deleteUser(String userId) async {
    final user = userBox.get(userId);
    if (user != null && user.isMe) {
      throw Exception('不能删除自己');
    }
    await userBox.delete(userId);
    final keys = recordBox.keys
        .where((key) => recordBox.get(key)?.userId == userId)
        .toList();
    for (var key in keys) {
      await recordBox.delete(key);
    }
  }

  static List<User> getAllUsers() {
    return userBox.values.toList();
  }

  static User? getUser(String id) {
    return userBox.get(id);
  }

  static User getMe() {
    return userBox.values.firstWhere((u) => u.isMe);
  }

  // ---- 批量保存排班 ----
  static Future<void> saveRecords(List<DailyRecord> records) async {
    for (var record in records) {
      await _recordBox!.put(record.id, record);
    }
  }

  // ---- 排班记录操作 ----
  static Future<void> saveRecord(DailyRecord record) async {
    await _recordBox!.put(record.id, record);
  }

  static Future<void> deleteRecord(String id) async {
    await _recordBox!.delete(id);
  }

  static List<DailyRecord> getRecordsByUser(String userId) {
    return _recordBox!.values.where((r) => r.userId == userId).toList();
  }

  static List<DailyRecord> getRecordsByUserAndDateRange(
    String userId,
    DateTime start,
    DateTime end,
  ) {
    return _recordBox!.values.where((r) {
      if (r.userId != userId) return false;
      final d = r.date;
      return d.isAfter(start.subtract(const Duration(days: 1))) &&
          d.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }

  static DailyRecord? getRecordByUserAndDate(String userId, DateTime date) {
    final records = _recordBox!.values.where((r) {
      if (r.userId != userId) return false;
      final d = r.date;
      return d.year == date.year && d.month == date.month && d.day == date.day;
    }).toList();
    return records.isEmpty ? null : records.first;
  }

  // ---- 按日期获取所有用户的记录 ----
  static List<DailyRecord> getRecordsByDate(DateTime date) {
    return _recordBox!.values.where((r) {
      final d = r.date;
      return d.year == date.year && d.month == date.month && d.day == date.day;
    }).toList();
  }

  // ---- 获取某天某用户的“搭班同事” ----
  static List<Map<String, dynamic>> getWorkingColleagues(
    String userId,
    DateTime date,
  ) {
    final allRecords = getRecordsByDate(date);
    final myRecord = getRecordByUserAndDate(userId, date);
    if (myRecord == null || myRecord.shiftTypeId.isEmpty) return [];

    final colleagues = <Map<String, dynamic>>[];
    for (var record in allRecords) {
      if (record.userId == userId) continue;
      if (record.shiftTypeId.isEmpty) continue;
      final shift = getShiftType(record.shiftTypeId);
      if (shift == null || shift.name == '休息') continue;
      final user = getUser(record.userId);
      if (user == null) continue;
      colleagues.add({
        'user': user,
        'shift': shift,
        'record': record,
      });
    }
    return colleagues;
  }

  // ---- 统计功能 ----
  static Map<String, dynamic> getStats(
    String userId,
    DateTime start,
    DateTime end,
  ) {
    final records = getRecordsByUserAndDateRange(userId, start, end);
    double totalWorkHours = 0;
    int totalOvertimeMinutes = 0;
    Map<String, int> shiftCount = {};

    for (var r in records) {
      if (r.shiftTypeId.isEmpty) continue;
      final shift = getShiftType(r.shiftTypeId);
      if (shift == null) continue;
      if (shift.name != '休息') {
        final startStr = r.startTime ?? shift.defaultStart;
        final endStr = r.endTime ?? shift.defaultEnd;
        if (startStr.isNotEmpty && endStr.isNotEmpty) {
          try {
            final startTime = DateFormat('HH:mm').parse(startStr);
            final endTime = DateFormat('HH:mm').parse(endStr);
            double hours = endTime.difference(startTime).inMinutes / 60.0;
            if (hours < 0) hours += 24;
            final restHours = shift.restMinutes / 60.0;
            hours -= restHours;
            if (hours < 0) hours = 0;
            totalWorkHours += hours;
          } catch (e) {
            // ignore
          }
        }
        totalOvertimeMinutes += r.overtimeMinutes;
      }
      shiftCount[r.shiftTypeId] = (shiftCount[r.shiftTypeId] ?? 0) + 1;
    }

    return {
      'totalWorkHours': totalWorkHours,
      'totalOvertimeHours': totalOvertimeMinutes / 60.0,
      'totalOvertimeMinutes': totalOvertimeMinutes,
      'shiftCount': shiftCount,
      'totalDays': records.length,
      'workDays': records.where((r) {
        if (r.shiftTypeId.isEmpty) return false;
        final shift = getShiftType(r.shiftTypeId);
        return shift != null && shift.name != '休息';
      }).length,
    };
  }

  // ---- 获取搭伴列表 ----
  static List<User?> getPartnersForRecord(DailyRecord record) {
    if (record.partnerIds == null || record.partnerIds!.isEmpty) return [];
    return record.partnerIds!.map((id) => getUser(id)).toList();
  }

  // ---- 自定义班次管理（增强版） ----
  static List<CustomShiftType> getAllShiftTypes() {
    return _shiftTypeBox!.values.toList();
  }

  static CustomShiftType? getShiftType(String id) {
    if (id.isEmpty) return null;
    return _shiftTypeBox!.get(id);
  }

  static Future<void> saveShiftType(CustomShiftType type) async {
    await _shiftTypeBox!.put(type.id, type);
  }

  // ---- 编辑班次（创建新版本） ----
  static Future<CustomShiftType> editShiftType(
    String oldId,
    String newName,
    String newColorHex,
    String newDefaultStart,
    String newDefaultEnd,
    int newRestMinutes,
  ) async {
    final oldShift = getShiftType(oldId);
    if (oldShift == null) {
      throw Exception('班次不存在');
    }

    final allShifts = getAllShiftTypes();
    int maxVersion = 1;
    for (var s in allShifts) {
      if (s.name == newName) {
        if (s.version > maxVersion) maxVersion = s.version;
      }
    }

    final newShift = CustomShiftType(
      id: 'shift_${DateTime.now().millisecondsSinceEpoch}',
      name: newName,
      colorHex: newColorHex,
      defaultStart: newDefaultStart,
      defaultEnd: newDefaultEnd,
      isDefault: oldShift.isDefault,
      restMinutes: newRestMinutes,
      version: maxVersion + 1,
      isActive: true,
    );

    final updatedOld = oldShift.copyWith(isActive: false);
    await _shiftTypeBox!.put(updatedOld.id, updatedOld);
    await _shiftTypeBox!.put(newShift.id, newShift);

    return newShift;
  }

  // ---- 获取当前使用的班次列表 ----
  static List<CustomShiftType> getActiveShiftTypes() {
    return _shiftTypeBox!.values.where((s) => s.isActive == true).toList();
  }

  // ---- 获取历史班次列表（非活跃） ----
  static List<CustomShiftType> getInactiveShiftTypes() {
    return _shiftTypeBox!.values.where((s) => s.isActive == false).toList();
  }

  // ---- 获取班次的所有历史版本 ----
  static List<CustomShiftType> getVersionsOfShift(String name) {
    return _shiftTypeBox!.values.where((s) => s.name == name).toList()
      ..sort((a, b) => a.version.compareTo(b.version));
  }

  // ---- 删除班次（增强版：检查引用） ----
  static Future<void> deleteShiftType(String id) async {
    final type = _shiftTypeBox!.get(id);
    if (type == null) throw Exception('班次不存在');
    
    if (type.isDefault) {
      throw Exception('不能删除系统预置班次');
    }

    final used = _recordBox!.values.any((r) => r.shiftTypeId == id);
    if (used) {
      throw Exception('该班次已被排班使用，请先修改相关排班');
    }

    await _shiftTypeBox!.delete(id);
  }

  // ---- 获取某个ID对应的版本显示名称 ----
  static String getShiftDisplayName(String id) {
    final shift = getShiftType(id);
    if (shift == null) return '未知班次';
    if (shift.isActive) {
      return shift.name;
    } else {
      return '${shift.name} (v${shift.version} 旧)';
    }
  }

  // ---- 获取每日工时列表 ----
  static Map<DateTime, double> getDailyWorkHours(
    String userId,
    DateTime start,
    DateTime end,
  ) {
    final records = getRecordsByUserAndDateRange(userId, start, end);
    final Map<DateTime, double> dailyHours = {};
    for (var r in records) {
      if (r.shiftTypeId.isEmpty) continue;
      final shift = getShiftType(r.shiftTypeId);
      if (shift == null || shift.name == '休息') continue;
      final startStr = r.startTime ?? shift.defaultStart;
      final endStr = r.endTime ?? shift.defaultEnd;
      if (startStr.isEmpty || endStr.isEmpty) continue;
      try {
        final startT = DateFormat('HH:mm').parse(startStr);
        final endT = DateFormat('HH:mm').parse(endStr);
        double hours = endT.difference(startT).inMinutes / 60.0;
        if (hours < 0) hours += 24;
        final restHours = shift.restMinutes / 60.0;
        hours -= restHours;
        if (hours < 0) hours = 0;
        final dateKey = DateTime(r.date.year, r.date.month, r.date.day);
        dailyHours[dateKey] = (dailyHours[dateKey] ?? 0) + hours;
      } catch (e) {
        // ignore
      }
    }
    return dailyHours;
  }

  static Map<DateTime, Map<String, double>> getDailyWorkAndOvertime(
    String userId,
    DateTime start,
    DateTime end,
  ) {
    final records = getRecordsByUserAndDateRange(userId, start, end);
    final Map<DateTime, Map<String, double>> dailyData = {};
    for (var r in records) {
      if (r.shiftTypeId.isEmpty) continue;
      final shift = getShiftType(r.shiftTypeId);
      if (shift == null || shift.name == '休息') continue;
      final startStr = r.startTime ?? shift.defaultStart;
      final endStr = r.endTime ?? shift.defaultEnd;
      if (startStr.isEmpty || endStr.isEmpty) continue;
      try {
        final startT = DateFormat('HH:mm').parse(startStr);
        final endT = DateFormat('HH:mm').parse(endStr);
        double hours = endT.difference(startT).inMinutes / 60.0;
        if (hours < 0) hours += 24;
        final restHours = shift.restMinutes / 60.0;
        hours -= restHours;
        if (hours < 0) hours = 0;
        final overtimeHours = r.overtimeMinutes / 60.0;
        final dateKey = DateTime(r.date.year, r.date.month, r.date.day);
        dailyData[dateKey] ??= {'normal': 0.0, 'overtime': 0.0};
        dailyData[dateKey]!['normal'] = (dailyData[dateKey]!['normal'] ?? 0) + hours;
        dailyData[dateKey]!['overtime'] = (dailyData[dateKey]!['overtime'] ?? 0) + overtimeHours;
      } catch (e) {
        // ignore
      }
    }
    return dailyData;
  }
}