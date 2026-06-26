import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/daily_record.dart';
import '../models/custom_shift_type.dart';
import '../models/user.dart';
import '../models/reminder_settings.dart';
import '../database/db_provider.dart';

enum ViewMode { month, week, day }

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  ViewMode _viewMode = ViewMode.month;
  DateTime _baseDate = DateTime.now();

  String _getRestShiftId(AppProvider app) {
    final shifts = app.getAllShiftTypes();
    final rest = shifts.firstWhere((s) => s.name == '休息', orElse: () => shifts.first);
    return rest.id;
  }

  void _changeViewMode(ViewMode mode) {
    setState(() {
      _viewMode = mode;
      if (_viewMode == ViewMode.day) {
        _baseDate = DateTime.now();
      } else if (_viewMode == ViewMode.week) {
        _baseDate = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
      } else {
        _baseDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
      }
    });
  }

  void _navigateLeft() {
    setState(() {
      if (_viewMode == ViewMode.month) {
        _baseDate = DateTime(_baseDate.year, _baseDate.month - 1, 1);
      } else if (_viewMode == ViewMode.week) {
        _baseDate = _baseDate.subtract(const Duration(days: 7));
      } else {
        _baseDate = _baseDate.subtract(const Duration(days: 1));
      }
    });
  }

  void _navigateRight() {
    setState(() {
      if (_viewMode == ViewMode.month) {
        _baseDate = DateTime(_baseDate.year, _baseDate.month + 1, 1);
      } else if (_viewMode == ViewMode.week) {
        _baseDate = _baseDate.add(const Duration(days: 7));
      } else {
        _baseDate = _baseDate.add(const Duration(days: 1));
      }
    });
  }

  void _navigateToday() {
    setState(() {
      if (_viewMode == ViewMode.month) {
        _baseDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
      } else if (_viewMode == ViewMode.week) {
        _baseDate = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
      } else {
        _baseDate = DateTime.now();
      }
    });
  }

  String _getTitle() {
    if (_viewMode == ViewMode.month) {
      return DateFormat('yyyy年MM月').format(_baseDate);
    } else if (_viewMode == ViewMode.week) {
      final start = _baseDate;
      final end = start.add(const Duration(days: 6));
      return '${DateFormat('MM月dd日').format(start)} - ${DateFormat('MM月dd日').format(end)}';
    } else {
      return DateFormat('yyyy年MM月dd日').format(_baseDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppProvider>(context);
    final user = app.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          user?.isMe == true ? '我的排班' : '排班总览',
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SegmentedButton<ViewMode>(
              segments: const [
                ButtonSegment(value: ViewMode.month, label: Text('月')),
                ButtonSegment(value: ViewMode.week, label: Text('周')),
                ButtonSegment(value: ViewMode.day, label: Text('员工')),
              ],
              selected: {_viewMode},
              onSelectionChanged: (Set<ViewMode> newSelection) {
                _changeViewMode(newSelection.first);
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _navigateLeft,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              TextButton(
                onPressed: _navigateToday,
                child: Text(
                  _getTitle(),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _navigateRight,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
      body: _buildBody(app),
    );
  }

  Widget _buildBody(AppProvider app) {
    switch (_viewMode) {
      case ViewMode.month:
        return _buildMonthView(app);
      case ViewMode.week:
        return _buildWeekView(app);
      case ViewMode.day:
        return _buildDayView(app);
    }
  }

  // ==================== 月视图 ====================
  Widget _buildMonthView(AppProvider app) {
    final user = app.currentUser;
    if (user == null) return const Center(child: Text('请选择用户'));

    final restShiftId = _getRestShiftId(app);
    final records = app.getRecordsForMonth(_baseDate.year, _baseDate.month);
    final firstDay = DateTime(_baseDate.year, _baseDate.month, 1);
    final daysInMonth = DateTime(_baseDate.year, _baseDate.month + 1, 0).day;
    final startWeekday = firstDay.weekday; // 1=周一

    // ---- 星期标题（中文） ----
    final weekDays = ['一', '二', '三', '四', '五', '六', '日'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          // 星期标题行
          Row(
            children: weekDays.map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          // 日期网格
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.1,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: 42,
            itemBuilder: (context, index) {
              final day = index - startWeekday + 2;
              if (day < 1 || day > daysInMonth) {
                return Container();
              }
              final date = DateTime(_baseDate.year, _baseDate.month, day);
              final record = records.firstWhere(
                (r) => r.date.year == date.year &&
                    r.date.month == date.month &&
                    r.date.day == date.day,
                orElse: () => DailyRecord(
                  id: '',
                  userId: user.id,
                  date: date,
                  shiftTypeId: '',
                  startTime: null,
                  endTime: null,
                  partnerIds: null,
                  overtimeMinutes: 0,
                  memo: null,
                  memoCompleted: false,
                ),
              );
              final isToday = date.year == DateTime.now().year &&
                  date.month == DateTime.now().month &&
                  date.day == DateTime.now().day;

              return _buildDayCell(date, record, isToday, app);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(DateTime date, DailyRecord record, bool isToday, AppProvider app) {
    final bool hasShiftRecord = record.id.isNotEmpty && record.shiftTypeId.isNotEmpty;
    CustomShiftType? shift;
    if (hasShiftRecord) {
      shift = app.getShiftType(record.shiftTypeId);
    }
    final bool hasValidShift = hasShiftRecord && shift != null;
    final bool isRest = hasValidShift && shift.name == '休息';

    Color? bgColor;
    if (isRest) {
      bgColor = Colors.grey.shade300;
    } else if (hasValidShift && !isRest) {
      bgColor = Color(int.parse(shift!.colorHex.replaceFirst('#', '0xFF'))).withOpacity(0.25);
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor ?? Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isToday ? Border.all(color: Colors.blue, width: 2) : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${date.day}',
            style: TextStyle(
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              color: isToday ? Colors.blue : null,
            ),
          ),
          if (isRest)
            const Text(
              '休',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          if (hasValidShift && !isRest)
            Text(
              shift!.name.substring(0, 1),
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          if (record.overtimeMinutes > 0)
            const Text('➕', style: TextStyle(fontSize: 8)),
        ],
      ),
    );
  }

  // ==================== 周视图（修复版：整合搭班和休息时显示同事） ====================
  Widget _buildWeekView(AppProvider app) {
    final user = app.currentUser;
    if (user == null) return const Center(child: Text('请选择用户'));

    final restShiftId = _getRestShiftId(app);
    final startOfWeek = _baseDate;
    final records = app.getRecordsForDateRange(
      startOfWeek,
      startOfWeek.add(const Duration(days: 6)),
    );

    final me = app.currentUser;
    final String myId = me?.id ?? '';
    final settings = app.getReminderSettings();

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: 7,
      itemBuilder: (context, index) {
        final date = startOfWeek.add(Duration(days: index));
        final record = records.firstWhere(
          (r) => r.date.year == date.year &&
              r.date.month == date.month &&
              r.date.day == date.day,
          orElse: () => DailyRecord(
            id: '',
            userId: user.id,
            date: date,
            shiftTypeId: '',
            startTime: null,
            endTime: null,
            partnerIds: null,
            overtimeMinutes: 0,
            memo: null,
            memoCompleted: false,
          ),
        );
        final isToday = date.year == DateTime.now().year &&
            date.month == DateTime.now().month &&
            date.day == DateTime.now().day;

        return _buildWeekItem(date, record, isToday, app, myId, settings);
      },
    );
  }

  Widget _buildWeekItem(
    DateTime date,
    DailyRecord record,
    bool isToday,
    AppProvider app,
    String myId,
    ReminderSettings settings,
  ) {
    final bool hasShiftRecord = record.id.isNotEmpty && record.shiftTypeId.isNotEmpty;
    CustomShiftType? shift;
    if (hasShiftRecord) {
      shift = app.getShiftType(record.shiftTypeId);
    }
    final bool hasValidShift = hasShiftRecord && shift != null;
    final bool isRest = hasValidShift && shift.name == '休息';

    // ---- 判断本人是否上班或休息 ----
    final me = app.currentUser;
    bool iAmWorking = false;
    bool iAmResting = false;
    if (me != null) {
      final myRecord = app.getRecordForDate(date);
      if (myRecord != null && myRecord.shiftTypeId.isNotEmpty) {
        final myShift = app.getShiftType(myRecord.shiftTypeId);
        if (myShift != null) {
          if (myShift.name == '休息') {
            iAmResting = true;
          } else {
            iAmWorking = true;
          }
        }
      } else if (myRecord == null || myRecord.shiftTypeId.isEmpty) {
        iAmResting = true;
      }
    }

    // ---- 决定是否显示同事列表 ----
    bool shouldShowColleagues = false;
    String colleagueListTitle = '';
    if (iAmWorking) {
      // 我上班：显示搭班同事
      shouldShowColleagues = true;
      colleagueListTitle = '👥 搭班同事：';
    } else if (iAmResting && settings.showColleaguesWhenResting) {
      // 我休息且开关开启：显示当班同事
      shouldShowColleagues = true;
      colleagueListTitle = '📋 当班同事：';
    }

    // ---- 获取同事列表 ----
    List<Map<String, dynamic>> colleagues = [];
    if (shouldShowColleagues) {
      final allColleagues = app.getWorkingColleagues(date);
      colleagues = allColleagues.where((c) {
        final user = c['user'] as User;
        return user.id != myId;
      }).toList();
    }

    // ---- 手动搭伴 ----
    List<User?> partners = [];
    if (record.partnerIds != null && record.partnerIds!.isNotEmpty) {
      partners = record.partnerIds!.map((id) => DBProvider.getUser(id)).toList();
    }

    // ---- 小圆点 ----
    Color? dotColor;
    if (hasValidShift && !isRest) {
      dotColor = Color(int.parse(shift!.colorHex.replaceFirst('#', '0xFF')));
    } else if (isRest) {
      dotColor = Colors.grey;
    } else {
      dotColor = Colors.transparent;
    }

    Color? cardColor = isToday ? Colors.blue.shade50 : null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- 第一行：日期 + 班次 + 工时 ----
            Row(
              children: [
                Text(
                  DateFormat('E dd').format(date),
                  style: TextStyle(
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    color: isToday ? Colors.blue : null,
                  ),
                ),
                const SizedBox(width: 12),
                if (dotColor != Colors.transparent)
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                Text(
                  isRest ? '休息' : (hasValidShift ? shift!.name : '未排班'),
                  style: TextStyle(
                    color: hasValidShift ? null : Colors.grey,
                    fontWeight: isRest ? FontWeight.normal : FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (hasValidShift && !isRest)
                  Text(
                    '${_calculateWorkHours(record, shift).toStringAsFixed(1)}h',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
              ],
            ),
            // ---- 第二行：同事列表（搭班或当班） ----
            if (shouldShowColleagues && colleagues.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                decoration: BoxDecoration(
                  color: iAmWorking ? Colors.green.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text(
                        colleagueListTitle,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: iAmWorking ? Colors.green : Colors.blue,
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: colleagues.map((item) {
                        final user = item['user'] as User;
                        final shift = item['shift'] as CustomShiftType;
                        final record = item['record'] as DailyRecord;
                        return Chip(
                          avatar: CircleAvatar(
                            radius: 10,
                            backgroundColor: Color(int.parse(
                                user.avatarColor?.replaceFirst('#', '0xFF') ?? '0xFF4CAF50')),
                            child: Text(
                              user.name.substring(0, 1),
                              style: const TextStyle(color: Colors.white, fontSize: 8),
                            ),
                          ),
                          label: Text(
                            '${user.name}(${shift.name} ${record.startTime ?? shift.defaultStart}-${record.endTime ?? shift.defaultEnd})',
                          ),
                          labelStyle: const TextStyle(fontSize: 11),
                          backgroundColor: iAmWorking ? Colors.green.shade100 : Colors.blue.shade100,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
            // ---- 手动搭伴 ----
            if (partners.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: partners.map((partner) {
                  if (partner == null) return const SizedBox.shrink();
                  return Chip(
                    avatar: CircleAvatar(
                      radius: 10,
                      backgroundColor: Color(int.parse(
                          partner.avatarColor?.replaceFirst('#', '0xFF') ?? '0xFF4CAF50')),
                      child: Text(
                        partner.name.substring(0, 1),
                        style: const TextStyle(color: Colors.white, fontSize: 8),
                      ),
                    ),
                    label: Text('🤝 ${partner.name}'),
                    labelStyle: const TextStyle(fontSize: 11),
                    backgroundColor: Colors.orange.shade50,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  double _calculateWorkHours(DailyRecord record, CustomShiftType? shift) {
    if (shift == null || shift.name == '休息') return 0;
    final startStr = record.startTime ?? shift.defaultStart;
    final endStr = record.endTime ?? shift.defaultEnd;
    if (startStr.isEmpty || endStr.isEmpty) return 0;
    try {
      final start = DateFormat('HH:mm').parse(startStr);
      final end = DateFormat('HH:mm').parse(endStr);
      double hours = end.difference(start).inMinutes / 60.0;
      if (hours < 0) hours += 24;
      final restHours = shift.restMinutes / 60.0;
      hours -= restHours;
      if (hours < 0) hours = 0;
      return hours;
    } catch (e) {
      return 0;
    }
  }

  // ==================== 员工日视图 ====================
  Widget _buildDayView(AppProvider app) {
    final users = app.getAllUsers();
    if (users.isEmpty) return const Center(child: Text('请先添加同事'));

    final me = app.currentUser;
    if (me == null) return const Center(child: Text('请先设置本人'));

    final myRecord = app.getRecordForDate(_baseDate);
    bool iAmWorking = false;
    if (myRecord != null && myRecord.shiftTypeId.isNotEmpty) {
      final myShift = app.getShiftType(myRecord.shiftTypeId);
      if (myShift != null && myShift.name != '休息') {
        iAmWorking = true;
      }
    }

    final records = app.getRecordsForDate(_baseDate);
    final restShiftId = _getRestShiftId(app);

    final Map<String, DailyRecord?> userRecordMap = {};
    for (var user in users) {
      final record = records.firstWhere(
        (r) => r.userId == user.id,
        orElse: () => DailyRecord(
          id: '',
          userId: user.id,
          date: _baseDate,
          shiftTypeId: '',
          startTime: null,
          endTime: null,
          partnerIds: null,
          overtimeMinutes: 0,
          memo: null,
          memoCompleted: false,
        ),
      );
      userRecordMap[user.id] = record;
    }

    final isToday = _baseDate.year == DateTime.now().year &&
        _baseDate.month == DateTime.now().month &&
        _baseDate.day == DateTime.now().day;

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final record = userRecordMap[user.id];
        final shift = record != null ? app.getShiftType(record.shiftTypeId) : null;
        final isMe = user.id == me.id;

        final bool hasShift = record != null && record.shiftTypeId.isNotEmpty && shift != null && shift.name != '休息';

        bool isWorkingTogether = false;
        if (!isMe && record != null && iAmWorking && hasShift) {
          isWorkingTogether = true;
        }

        bool isManualPartner = false;
        if (!isMe && record != null && record.partnerIds != null) {
          isManualPartner = record.partnerIds!.contains(me.id);
        }

        String subtitle = '';
        if (hasShift) {
          subtitle = '${shift!.name}  ${record?.startTime ?? shift.defaultStart} - ${record?.endTime ?? shift.defaultEnd}';
        } else {
          subtitle = '未安排';
        }

        List<String> tags = [];
        if (isWorkingTogether) tags.add('👥 搭班');
        if (isManualPartner) tags.add('🤝 搭伴');
        if (tags.isNotEmpty) subtitle += '  (${tags.join(' ')})';

        String overtimeText = '';
        if (record != null && record.overtimeMinutes > 0) {
          overtimeText = '加班${record.overtimeMinutes}min';
        }

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          color: isToday ? Colors.blue.shade50 : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Color(int.parse(
                  user.avatarColor?.replaceFirst('#', '0xFF') ?? '0xFF4CAF50')),
              child: Text(
                user.name.substring(0, 1),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(
              isMe ? '${user.name} (我)' : user.name,
              style: TextStyle(
                fontWeight: isMe ? FontWeight.bold : FontWeight.w500,
                color: isWorkingTogether && !isMe ? Colors.green : null,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: TextStyle(
                color: hasShift ? null : Colors.grey,
              ),
            ),
            trailing: overtimeText.isNotEmpty
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: shift != null && hasShift
                          ? Color(int.parse(shift.colorHex.replaceFirst('#', '0xFF')))
                          : Colors.grey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      overtimeText,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }
}