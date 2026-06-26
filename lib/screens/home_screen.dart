import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/daily_record.dart';
import '../models/custom_shift_type.dart';
import '../models/user.dart';
import '../database/db_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isEditing = false;
  bool _isBatchMode = false;
  DateTime? _batchStartDate;
  DateTime? _batchEndDate;
  DailyRecord? _editingRecord;

  String _selectedShiftTypeId = '';
  String _startTime = '';
  String _endTime = '';
  List<String> _selectedPartnerIds = [];
  String _memo = '';
  int _overtimeMinutes = 0;
  bool _memoCompleted = false;

  String _tempTime = '';
  int _tempHours = 0;
  int _tempMinutes = 0;

  bool _isMemoEditing = false;
  final TextEditingController _memoController = TextEditingController();
  String _currentMemo = '';
  bool _currentMemoCompleted = false;

  double _dragStartX = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _loadRecordForDate();
    _loadMemoForDate();
  }

  void _loadRecordForDate() {
    final app = Provider.of<AppProvider>(context, listen: false);
    final record = app.getRecordForDate(_selectedDate);
    setState(() {
      _editingRecord = record;
      if (record != null) {
        _selectedShiftTypeId = record.shiftTypeId;
        _startTime = record.startTime ?? '';
        _endTime = record.endTime ?? '';
        _selectedPartnerIds = record.partnerIds ?? [];
        _overtimeMinutes = record.overtimeMinutes;
      } else {
        // 只取活跃的班次作为默认
        final activeShifts = app.getActiveShiftTypes();
        _selectedShiftTypeId = activeShifts.isNotEmpty ? activeShifts.first.id : '';
        _startTime = '';
        _endTime = '';
        _selectedPartnerIds = [];
        _overtimeMinutes = 0;
      }
    });
  }

  void _loadMemoForDate() {
    final app = Provider.of<AppProvider>(context, listen: false);
    final record = app.getRecordForDate(_selectedDate);
    setState(() {
      _currentMemo = record?.memo ?? '';
      _currentMemoCompleted = record?.memoCompleted ?? false;
      _memoController.text = _currentMemo;
    });
  }

  void _saveMemo() async {
    final app = Provider.of<AppProvider>(context, listen: false);
    final user = app.currentUser;
    if (user == null) return;

    final record = app.getRecordForDate(_selectedDate);
    if (record != null) {
      final updated = record.copyWith(
        memo: _memoController.text.isNotEmpty ? _memoController.text : null,
        memoCompleted: _currentMemoCompleted,
      );
      await app.saveRecord(updated);
    } else if (_memoController.text.isNotEmpty) {
      final newRecord = DailyRecord(
        id: 'record_${DateTime.now().millisecondsSinceEpoch}',
        userId: user.id,
        date: _selectedDate,
        shiftTypeId: '',
        memo: _memoController.text.isNotEmpty ? _memoController.text : null,
        memoCompleted: _currentMemoCompleted,
      );
      await app.saveRecord(newRecord);
    }
    setState(() {
      _isMemoEditing = false;
      _currentMemo = _memoController.text;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('备忘录已保存'), duration: Duration(milliseconds: 800)),
    );
  }

  void _toggleMemoComplete(bool? val) {
    setState(() {
      _currentMemoCompleted = val ?? false;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadData();
    }
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    _loadData();
  }

  void _goToToday() {
    setState(() {
      _selectedDate = DateTime.now();
    });
    _loadData();
  }

  void _toggleBatchMode() {
    setState(() {
      _isBatchMode = !_isBatchMode;
      if (_isBatchMode) {
        _batchStartDate = _selectedDate;
        _batchEndDate = _selectedDate;
      } else {
        _batchStartDate = null;
        _batchEndDate = null;
      }
    });
  }

  Future<void> _selectBatchDate(bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_batchStartDate ?? _selectedDate) : (_batchEndDate ?? _selectedDate),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _batchStartDate = picked;
          if (_batchEndDate != null && _batchEndDate!.isBefore(picked)) {
            _batchEndDate = picked;
          }
        } else {
          _batchEndDate = picked;
          if (_batchStartDate != null && _batchStartDate!.isAfter(picked)) {
            _batchStartDate = picked;
          }
        }
      });
    }
  }

  void _applyBatch() async {
    if (_batchStartDate == null || _batchEndDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择日期范围'), duration: Duration(milliseconds: 800)),
      );
      return;
    }
    if (_selectedShiftTypeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择班次'), duration: Duration(milliseconds: 800)),
      );
      return;
    }

    final app = Provider.of<AppProvider>(context, listen: false);
    final user = app.currentUser;
    if (user == null) return;

    final List<DailyRecord> records = [];
    DateTime current = _batchStartDate!;
    while (!current.isAfter(_batchEndDate!)) {
      final existing = app.getRecordForDate(current);
      if (existing != null && existing.shiftTypeId.isNotEmpty) {
        current = current.add(const Duration(days: 1));
        continue;
      }

      final newRecord = DailyRecord(
        id: 'record_${DateTime.now().millisecondsSinceEpoch}_${current.millisecondsSinceEpoch}',
        userId: user.id,
        date: current,
        shiftTypeId: _selectedShiftTypeId,
        startTime: _startTime.isNotEmpty ? _startTime : null,
        endTime: _endTime.isNotEmpty ? _endTime : null,
        partnerIds: _selectedPartnerIds.isNotEmpty ? _selectedPartnerIds : null,
        overtimeMinutes: _overtimeMinutes,
        memo: null,
        memoCompleted: false,
      );
      records.add(newRecord);
      current = current.add(const Duration(days: 1));
    }

    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('所选日期已有排班，无需重复添加'), duration: Duration(milliseconds: 800)),
      );
      return;
    }

    await app.saveRecords(records);
    setState(() {
      _isBatchMode = false;
      _batchStartDate = null;
      _batchEndDate = null;
    });
    _loadData();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已为 ${records.length} 天添加排班'), duration: Duration(milliseconds: 800)),
    );
  }

  void _selectTime(bool isStart) async {
    final currentTime = isStart ? _startTime : _endTime;
    final initialDateTime = currentTime.isNotEmpty
        ? DateFormat('HH:mm').parse(currentTime)
        : DateTime(2000, 1, 1, 8, 0);
    _tempTime = currentTime;
    await showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 260,
        color: Colors.white,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: const Text('取消'),
                  onPressed: () => Navigator.pop(context),
                ),
                CupertinoButton(
                  child: const Text('确定'),
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      if (isStart) {
                        _startTime = _tempTime;
                      } else {
                        _endTime = _tempTime;
                      }
                    });
                  },
                ),
              ],
            ),
            Expanded(
              child: CupertinoTimerPicker(
                mode: CupertinoTimerPickerMode.hm,
                initialTimerDuration: Duration(
                  hours: initialDateTime.hour,
                  minutes: initialDateTime.minute,
                ),
                onTimerDurationChanged: (duration) {
                  _tempTime =
                      '${duration.inHours.remainder(24).toString().padLeft(2, '0')}:${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}';
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectOvertime() async {
    int hours = _overtimeMinutes ~/ 60;
    int minutes = _overtimeMinutes % 60;
    _tempHours = hours;
    _tempMinutes = minutes;
    await showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 260,
        color: Colors.white,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: const Text('取消'),
                  onPressed: () => Navigator.pop(context),
                ),
                CupertinoButton(
                  child: const Text('确定'),
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _overtimeMinutes = _tempHours * 60 + _tempMinutes;
                    });
                  },
                ),
              ],
            ),
            Expanded(
              child: CupertinoTimerPicker(
                mode: CupertinoTimerPickerMode.hm,
                initialTimerDuration: Duration(hours: hours, minutes: minutes),
                onTimerDurationChanged: (duration) {
                  _tempHours = duration.inHours.remainder(24);
                  _tempMinutes = duration.inMinutes.remainder(60);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== 修复：只显示活跃的班次 =====
  void _showShiftPicker() {
    final app = Provider.of<AppProvider>(context, listen: false);
    final shifts = app.getActiveShiftTypes(); // 只取活跃班次
    showModalBottomSheet(
      context: context,
      builder: (context) => Wrap(
        children: shifts.map((shift) {
          return ListTile(
            leading: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Color(int.parse(shift.colorHex.replaceFirst('#', '0xFF'))),
                shape: BoxShape.circle,
              ),
            ),
            title: Text(shift.name),
            onTap: () {
              setState(() {
                _selectedShiftTypeId = shift.id;
                if (shift.name != '休息') {
                  _startTime = shift.defaultStart;
                  _endTime = shift.defaultEnd;
                } else {
                  _startTime = '';
                  _endTime = '';
                }
              });
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  void _saveAndNext() async {
    final app = Provider.of<AppProvider>(context, listen: false);
    final user = app.currentUser;
    if (user == null) return;

    if (_selectedShiftTypeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择班次'), duration: Duration(milliseconds: 800)),
      );
      return;
    }

    final id = _editingRecord?.id ?? 'record_${DateTime.now().millisecondsSinceEpoch}';
    final record = DailyRecord(
      id: id,
      userId: user.id,
      date: _selectedDate,
      shiftTypeId: _selectedShiftTypeId,
      startTime: _startTime.isNotEmpty ? _startTime : null,
      endTime: _endTime.isNotEmpty ? _endTime : null,
      partnerIds: _selectedPartnerIds.isNotEmpty ? _selectedPartnerIds : null,
      overtimeMinutes: _overtimeMinutes,
      memo: _currentMemo.isNotEmpty ? _currentMemo : null,
      memoCompleted: _currentMemoCompleted,
    );

    await app.saveRecord(record);

    final nextDay = _selectedDate.add(const Duration(days: 1));
    final nextRecord = app.getRecordForDate(nextDay);

    setState(() {
      _selectedDate = nextDay;
      _editingRecord = nextRecord;
      _isEditing = true;
      if (nextRecord != null && nextRecord.shiftTypeId.isNotEmpty) {
        _selectedShiftTypeId = nextRecord.shiftTypeId;
        _startTime = nextRecord.startTime ?? '';
        _endTime = nextRecord.endTime ?? '';
        _selectedPartnerIds = nextRecord.partnerIds ?? [];
        _overtimeMinutes = nextRecord.overtimeMinutes;
      } else {
        final activeShifts = app.getActiveShiftTypes();
        _selectedShiftTypeId = activeShifts.isNotEmpty ? activeShifts.first.id : '';
        _startTime = '';
        _endTime = '';
        _selectedPartnerIds = [];
        _overtimeMinutes = 0;
      }
    });
    _loadMemoForDate();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已保存，正在编辑 ${DateFormat('MM月dd日').format(nextDay)}'),
        duration: Duration(milliseconds: 800),
      ),
    );
  }

  void _saveOnly() async {
    final app = Provider.of<AppProvider>(context, listen: false);
    final user = app.currentUser;
    if (user == null) return;

    if (_selectedShiftTypeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择班次'), duration: Duration(milliseconds: 800)),
      );
      return;
    }

    final id = _editingRecord?.id ?? 'record_${DateTime.now().millisecondsSinceEpoch}';
    final record = DailyRecord(
      id: id,
      userId: user.id,
      date: _selectedDate,
      shiftTypeId: _selectedShiftTypeId,
      startTime: _startTime.isNotEmpty ? _startTime : null,
      endTime: _endTime.isNotEmpty ? _endTime : null,
      partnerIds: _selectedPartnerIds.isNotEmpty ? _selectedPartnerIds : null,
      overtimeMinutes: _overtimeMinutes,
      memo: _currentMemo.isNotEmpty ? _currentMemo : null,
      memoCompleted: _currentMemoCompleted,
    );

    await app.saveRecord(record);
    setState(() {
      _isEditing = false;
      _selectedDate = DateTime.now();
      _editingRecord = record;
    });
    _loadData();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('保存成功'), duration: Duration(milliseconds: 800)),
    );
  }

  void _deleteRecord() async {
    if (_editingRecord == null) return;
    final app = Provider.of<AppProvider>(context, listen: false);
    await app.deleteRecord(_editingRecord!.id);
    setState(() {
      _editingRecord = null;
      _isEditing = false;
      _selectedDate = DateTime.now();
      final activeShifts = app.getActiveShiftTypes();
      _selectedShiftTypeId = activeShifts.isNotEmpty ? activeShifts.first.id : '';
      _startTime = '';
      _endTime = '';
      _selectedPartnerIds = [];
      _overtimeMinutes = 0;
    });
    _loadData();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已删除'), duration: Duration(milliseconds: 800)),
    );
  }

  void _editOvertime(DailyRecord record) async {
    int hours = record.overtimeMinutes ~/ 60;
    int minutes = record.overtimeMinutes % 60;
    _tempHours = hours;
    _tempMinutes = minutes;
    await showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 260,
        color: Colors.white,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: const Text('取消'),
                  onPressed: () => Navigator.pop(context),
                ),
                CupertinoButton(
                  child: const Text('确定'),
                  onPressed: () {
                    Navigator.pop(context);
                    final newMinutes = _tempHours * 60 + _tempMinutes;
                    final updated = record.copyWith(overtimeMinutes: newMinutes);
                    final app = Provider.of<AppProvider>(context, listen: false);
                    app.saveRecord(updated);
                    setState(() {
                      _editingRecord = updated;
                      _overtimeMinutes = newMinutes;
                    });
                  },
                ),
              ],
            ),
            Expanded(
              child: CupertinoTimerPicker(
                mode: CupertinoTimerPickerMode.hm,
                initialTimerDuration: Duration(hours: hours, minutes: minutes),
                onTimerDurationChanged: (duration) {
                  _tempHours = duration.inHours.remainder(24);
                  _tempMinutes = duration.inMinutes.remainder(60);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getShiftIcon(String shiftName) {
    switch (shiftName) {
      case '早班': return '🌅';
      case '中班': return '☀️';
      case '晚班': return '🌙';
      case '休息': return '😴';
      default: return '📅';
    }
  }

  double _calculateWorkHours(DailyRecord record, CustomShiftType shift) {
    if (shift.name == '休息') return 0;
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

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppProvider>(context);
    final user = app.currentUser;
    final recordWithShift = app.getRecordWithShift(_selectedDate);
    final record = recordWithShift['record'] as DailyRecord?;
    final shift = recordWithShift['shift'] as CustomShiftType?;

    final colleagues = app.getWorkingColleagues(_selectedDate);
    final filteredColleagues = colleagues.where((c) => c['user']!.id != user?.id).toList();

    final bool isToday = _selectedDate.year == DateTime.now().year &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.day == DateTime.now().day;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 20),
              onPressed: () => _changeDate(-1),
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
            ),
            Text(
              '排班 - ${DateFormat('yyyy年MM月dd日').format(_selectedDate)}',
              style: const TextStyle(fontSize: 16),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 20),
              onPressed: () => _changeDate(1),
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
            ),
            if (!isToday)
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: GestureDetector(
                  onTap: _goToToday,
                  child: const Text(
                    '回到今日',
                    style: TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
            if (_isBatchMode)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '批量模式',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
          ),
          if (!_isEditing)
            IconButton(
              icon: Icon(_isBatchMode ? Icons.close : Icons.batch_prediction),
              onPressed: _toggleBatchMode,
              tooltip: _isBatchMode ? '退出批量模式' : '批量排班',
            ),
          if (!_isEditing && record != null && record.shiftTypeId.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                  _selectedShiftTypeId = record.shiftTypeId;
                  _startTime = record.startTime ?? '';
                  _endTime = record.endTime ?? '';
                  _selectedPartnerIds = record.partnerIds ?? [];
                  _overtimeMinutes = record.overtimeMinutes;
                });
              },
            ),
          if (!_isEditing && record != null && record.shiftTypeId.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteRecord,
            ),
        ],
      ),
      body: GestureDetector(
        onHorizontalDragStart: (details) {
          _dragStartX = details.localPosition.dx;
        },
        onHorizontalDragEnd: (details) {
          final dx = details.primaryVelocity ?? 0;
          if (dx > 0) {
            _changeDate(-1);
          } else if (dx < 0) {
            _changeDate(1);
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(int.parse(
                        user?.avatarColor?.replaceFirst('#', '0xFF') ?? '0xFF4CAF50')),
                    child: Text(
                      user?.name.substring(0, 1) ?? '我',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? '我',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          user?.isMe == true ? '📌 本人' : '👥 同事',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  if (user != null && !user.isMe)
                    TextButton(
                      onPressed: () {
                        app.switchToMe();
                        _loadData();
                      },
                      child: const Text('切换到本人'),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _isEditing
                      ? _buildEditForm()
                      : _isBatchMode
                          ? _buildBatchForm()
                          : _buildDisplayCard(record, shift, filteredColleagues),
                ),
              ),

              const SizedBox(height: 16),

              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '📝 备忘录',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          if (!_isMemoEditing)
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isMemoEditing = true;
                                  _memoController.text = _currentMemo;
                                });
                              },
                              child: Text(_currentMemo.isEmpty ? '添加' : '编辑'),
                            ),
                        ],
                      ),
                      if (_isMemoEditing) ...[
                        TextField(
                          controller: _memoController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            hintText: '输入备忘录内容...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Checkbox(
                              value: _currentMemoCompleted,
                              onChanged: _toggleMemoComplete,
                            ),
                            const Text('已完成'),
                            const Spacer(),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isMemoEditing = false;
                                  _memoController.text = _currentMemo;
                                });
                              },
                              child: const Text('取消'),
                            ),
                            ElevatedButton(
                              onPressed: _saveMemo,
                              child: const Text('保存'),
                            ),
                          ],
                        ),
                      ] else if (_currentMemo.isNotEmpty) ...[
                        Row(
                          children: [
                            Checkbox(
                              value: _currentMemoCompleted,
                              onChanged: _toggleMemoComplete,
                            ),
                            Expanded(
                              child: Text(
                                _currentMemo,
                                style: TextStyle(
                                  decoration: _currentMemoCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            '暂无备忘录',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '⏱️ 加班统计',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '本月加班: ${(app.getStatsForMonth(_selectedDate.year, _selectedDate.month)['totalOvertimeHours'] ?? 0).toStringAsFixed(1)} 小时',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 20),
                          Text(
                            '本周加班: ${(app.getStatsForWeek(_selectedDate)['totalOvertimeHours'] ?? 0).toStringAsFixed(1)} 小时',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: !_isEditing && !_isBatchMode
          ? FloatingActionButton.extended(
              onPressed: () {
                setState(() {
                  _isEditing = true;
                  if (record != null && record.shiftTypeId.isNotEmpty) {
                    _selectedShiftTypeId = record.shiftTypeId;
                    _startTime = record.startTime ?? '';
                    _endTime = record.endTime ?? '';
                    _selectedPartnerIds = record.partnerIds ?? [];
                    _overtimeMinutes = record.overtimeMinutes;
                  } else {
                    final activeShifts = app.getActiveShiftTypes();
                    _selectedShiftTypeId = activeShifts.isNotEmpty ? activeShifts.first.id : '';
                    _startTime = '';
                    _endTime = '';
                    _selectedPartnerIds = [];
                    _overtimeMinutes = 0;
                  }
                });
              },
              icon: Icon(record == null || record.shiftTypeId.isEmpty ? Icons.add : Icons.edit),
              label: Text(record == null || record.shiftTypeId.isEmpty ? '添加排班' : '编辑排班'),
            )
          : null,
    );
  }

  Widget _buildBatchForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📅 批量排班',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _selectBatchDate(true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        _batchStartDate != null
                            ? DateFormat('MM月dd日').format(_batchStartDate!)
                            : '开始日期',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text('~'),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => _selectBatchDate(false),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        _batchEndDate != null
                            ? DateFormat('MM月dd日').format(_batchEndDate!)
                            : '结束日期',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildShiftSelector(),
        const SizedBox(height: 12),
        _buildTimeSelector(),
        const SizedBox(height: 12),
        _buildPartnerSelector(),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _applyBatch,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.orange,
                ),
                child: const Text('应用批量排班'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: _toggleBatchMode,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('取消'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDisplayCard(
    DailyRecord? record,
    CustomShiftType? shift,
    List<Map<String, dynamic>> colleagues,
  ) {
    if (record == null || record.shiftTypeId.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text(
            '今日未排班',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    if (shift == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text(
            '今日未排班',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    final isRest = shift.name == '休息';
    final partners = record.partnerIds != null
        ? record.partnerIds!.map((id) => DBProvider.getUser(id)).where((u) => u != null).toList()
        : [];
    final filteredColleagues =
        colleagues.where((c) => c['user']!.id != Provider.of<AppProvider>(context).currentUser?.id).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Color(int.parse(shift.colorHex.replaceFirst('#', '0xFF'))),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _getShiftIcon(shift.name),
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shift.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (!isRest)
                    Text(
                      '${record.startTime ?? shift.defaultStart} - ${record.endTime ?? shift.defaultEnd}',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                ],
              ),
            ),
            if (!isRest)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Color(int.parse(shift.colorHex.replaceFirst('#', '0xFF'))),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_calculateWorkHours(record, shift).toStringAsFixed(1)}h',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
          ],
        ),
        if (partners.isNotEmpty) ...[
          const Divider(),
          Row(
            children: [
              const Icon(Icons.people, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: partners.map((partner) {
                    return Chip(
                      avatar: CircleAvatar(
                        radius: 10,
                        backgroundColor: Color(int.parse(
                            partner!.avatarColor?.replaceFirst('#', '0xFF') ?? '0xFF4CAF50')),
                        child: Text(
                          partner.name.substring(0, 1),
                          style: const TextStyle(color: Colors.white, fontSize: 8),
                        ),
                      ),
                      label: Text(partner.name),
                      labelStyle: const TextStyle(fontSize: 12),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
        if (filteredColleagues.isNotEmpty) ...[
          const Divider(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.people_alt, size: 16, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: filteredColleagues.map((item) {
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
                          '${user.name}(${shift.name} ${record.startTime ?? shift.defaultStart}-${record.endTime ?? shift.defaultEnd})'),
                      labelStyle: const TextStyle(fontSize: 11),
                      backgroundColor: Colors.green.shade50,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
        if (record.overtimeMinutes > 0) ...[
          const Divider(),
          Row(
            children: [
              const Icon(Icons.access_time, size: 16, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                '加班: ${record.overtimeMinutes ~/ 60}h ${record.overtimeMinutes % 60}m',
                style: const TextStyle(fontSize: 14, color: Colors.orange),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 16),
                onPressed: () => _editOvertime(record),
              ),
            ],
          ),
        ] else
          TextButton(
            onPressed: () => _editOvertime(record),
            child: const Text('添加加班'),
          ),
      ],
    );
  }

  // ===== 编辑表单 =====
  Widget _buildEditForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '✏️ 编辑排班',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildShiftSelector(),
        const SizedBox(height: 12),
        _buildTimeSelector(),
        const SizedBox(height: 12),
        _buildPartnerSelector(),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _saveAndNext,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('保存并下一天'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _isEditing = false;
                    _selectedDate = DateTime.now();
                  });
                  _loadData();
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('取消'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: _saveOnly,
                child: const Text('仅保存（不跳转）'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ===== 班次选择器（修复：只显示活跃班次，但保留历史班次的显示） =====
  Widget _buildShiftSelector() {
    final app = Provider.of<AppProvider>(context);
    final activeShifts = app.getActiveShiftTypes();
    
    // 判断当前选中的班次是否是活跃的
    final bool isActive = activeShifts.any((s) => s.id == _selectedShiftTypeId);
    
    // 构建下拉选项：活跃班次 + 如果当前选中的是历史班次，添加一个不可选的显示项
    final List<DropdownMenuItem<String>> items = [];
    
    // 如果当前选中的是历史班次，先添加一个不可选的占位项
    if (!isActive && _selectedShiftTypeId.isNotEmpty) {
      final historicalShift = app.getShiftType(_selectedShiftTypeId);
      if (historicalShift != null) {
        items.add(
          DropdownMenuItem<String>(
            value: historicalShift.id,
            enabled: false,
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Color(int.parse(historicalShift.colorHex.replaceFirst('#', '0xFF'))),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${historicalShift.name} (历史版本 v${historicalShift.version})',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      }
    }
    
    // 添加活跃班次
    for (var shift in activeShifts) {
      items.add(
        DropdownMenuItem<String>(
          value: shift.id,
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Color(int.parse(shift.colorHex.replaceFirst('#', '0xFF'))),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(shift.name),
            ],
          ),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      value: _selectedShiftTypeId.isNotEmpty ? _selectedShiftTypeId : null,
      decoration: const InputDecoration(
        labelText: '班次',
        border: OutlineInputBorder(),
      ),
      items: items,
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedShiftTypeId = value;
            final shift = activeShifts.firstWhere((s) => s.id == value, orElse: () => activeShifts.first);
            if (shift.name != '休息') {
              _startTime = shift.defaultStart;
              _endTime = shift.defaultEnd;
            } else {
              _startTime = '';
              _endTime = '';
            }
          });
        }
      },
    );
  }

  Widget _buildTimeSelector() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _selectTime(true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, size: 16),
                  const SizedBox(width: 8),
                  Text(_startTime.isEmpty ? '开始时间' : _startTime),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => _selectTime(false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, size: 16),
                  const SizedBox(width: 8),
                  Text(_endTime.isEmpty ? '结束时间' : _endTime),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPartnerSelector() {
    final app = Provider.of<AppProvider>(context);
    final users = app.getAllUsers();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('搭伴同事 (可选，点击切换)', style: TextStyle(fontSize: 14)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: users.where((u) => u.id != app.currentUser?.id).map((u) {
            final isSelected = _selectedPartnerIds.contains(u.id);
            return FilterChip(
              label: Text(u.name),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedPartnerIds.add(u.id);
                  } else {
                    _selectedPartnerIds.remove(u.id);
                  }
                });
              },
              avatar: CircleAvatar(
                radius: 10,
                backgroundColor: Color(int.parse(
                    u.avatarColor?.replaceFirst('#', '0xFF') ?? '0xFF4CAF50')),
                child: Text(
                  u.name.substring(0, 1),
                  style: const TextStyle(color: Colors.white, fontSize: 8),
                ),
              ),
            );
          }).toList(),
        ),
        if (_selectedPartnerIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '已选: ${_selectedPartnerIds.map((id) => users.firstWhere((u) => u.id == id).name).join('、')}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
      ],
    );
  }
}