import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/custom_shift_type.dart';
import '../utils/color_picker.dart';

class ShiftManagementScreen extends StatefulWidget {
  const ShiftManagementScreen({super.key});

  @override
  State<ShiftManagementScreen> createState() => _ShiftManagementScreenState();
}

class _ShiftManagementScreenState extends State<ShiftManagementScreen> {
  final TextEditingController _nameController = TextEditingController();
  String _selectedColorHex = '#4CAF50';
  String _defaultStart = '08:00';
  String _defaultEnd = '18:00';
  int _restMinutes = 150;
  String _tempTime = '';

  bool _isEditing = false;
  String? _editingShiftId;
  String _editingOldName = '';

  @override
  void initState() {
    super.initState();
    _resetForm();
  }

  void _resetForm() {
    _nameController.clear();
    _selectedColorHex = '#4CAF50';
    _defaultStart = '08:00';
    _defaultEnd = '18:00';
    _restMinutes = 150;
    _isEditing = false;
    _editingShiftId = null;
    _editingOldName = '';
  }

  void _pickColor() async {
    final picked = await showSimpleColorPicker(context);
    if (picked != null) {
      setState(() {
        _selectedColorHex = colorToHex(picked);
      });
    }
  }

  void _selectTime(bool isStart) async {
    final current = isStart ? _defaultStart : _defaultEnd;
    final parts = current.split(':');
    final initial = current.isNotEmpty && parts.length == 2
        ? DateTime(2000, 1, 1, int.parse(parts[0]), int.parse(parts[1]))
        : DateTime(2000, 1, 1, 8, 0);
    _tempTime = current;
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
                        _defaultStart = _tempTime;
                      } else {
                        _defaultEnd = _tempTime;
                      }
                    });
                  },
                ),
              ],
            ),
            Expanded(
              child: CupertinoTimerPicker(
                mode: CupertinoTimerPickerMode.hm,
                initialTimerDuration: Duration(hours: initial.hour, minutes: initial.minute),
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

  void _startEdit(CustomShiftType shift) {
    setState(() {
      _isEditing = true;
      _editingShiftId = shift.id;
      _editingOldName = shift.name;
      _nameController.text = shift.name;
      _selectedColorHex = shift.colorHex;
      _defaultStart = shift.defaultStart;
      _defaultEnd = shift.defaultEnd;
      _restMinutes = shift.restMinutes;
    });
  }

  void _cancelEdit() {
    _resetForm();
  }

  void _addShift() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入班次名称')),
      );
      return;
    }

    final app = Provider.of<AppProvider>(context, listen: false);

    final activeShifts = app.getActiveShiftTypes();
    final exists = activeShifts.any((s) => s.name == _nameController.text.trim());
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该班次已存在，请使用不同的名称')),
      );
      return;
    }

    final newShift = CustomShiftType(
      id: 'shift_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      colorHex: _selectedColorHex,
      defaultStart: _defaultStart,
      defaultEnd: _defaultEnd,
      restMinutes: _restMinutes,
      isDefault: false,
      version: 1,
      isActive: true,
    );

    await app.saveShiftType(newShift);
    _resetForm();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已添加班次 ${newShift.name}')),
    );
  }

  void _saveEdit() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入班次名称')),
      );
      return;
    }

    final app = Provider.of<AppProvider>(context, listen: false);

    final activeShifts = app.getActiveShiftTypes();
    final exists = activeShifts.any((s) => 
      s.name == _nameController.text.trim() && 
      s.id != _editingShiftId
    );
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该班次已存在，请使用不同的名称')),
      );
      return;
    }

    try {
      final newShift = await app.editShiftType(
        _editingShiftId!,
        _nameController.text.trim(),
        _selectedColorHex,
        _defaultStart,
        _defaultEnd,
        _restMinutes,
      );
      _resetForm();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已更新班次，新版本 v${newShift.version} 已创建'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _deleteShift(CustomShiftType shift) async {
    if (shift.isDefault) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('系统预置班次不能删除')),
      );
      return;
    }

    final app = Provider.of<AppProvider>(context, listen: false);
    
    try {
      await app.deleteShiftType(shift.id);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已删除 ${shift.name}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppProvider>(context);
    final activeShifts = app.getActiveShiftTypes();
    final inactiveShifts = app.getInactiveShiftTypes();

    return Scaffold(
      appBar: AppBar(
        title: const Text('班次管理'),
        backgroundColor: Colors.blue.shade50,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.black54),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('💡 班次版本说明'),
                  content: const SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('📌 编辑班次时会创建新版本，旧版本自动归档为历史。'),
                        SizedBox(height: 8),
                        Text('📌 历史排班继续使用旧版本数据，不受影响。'),
                        SizedBox(height: 8),
                        Text('📌 新排班使用当前活跃版本。'),
                        SizedBox(height: 8),
                        Text('📌 有排班引用的班次不可删除。'),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('知道了'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ---- 添加/编辑表单 ----
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade50,
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      _isEditing ? '✏️ 编辑班次（创建新版本）' : '➕ 添加新班次',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (_isEditing)
                      TextButton(
                        onPressed: _cancelEdit,
                        child: const Text('取消编辑'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '班次名称',
                    border: OutlineInputBorder(),
                    hintText: '例如：早班、晚班、行政班...',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('颜色：', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _pickColor,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(int.parse(_selectedColorHex.replaceFirst('#', '0xFF'))),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade400, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedColorHex,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
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
                              const Icon(Icons.access_time, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(
                                _defaultStart.isEmpty ? '开始时间' : _defaultStart,
                                style: TextStyle(
                                  color: _defaultStart.isEmpty ? Colors.grey : Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                              const Icon(Icons.access_time, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(
                                _defaultEnd.isEmpty ? '结束时间' : _defaultEnd,
                                style: TextStyle(
                                  color: _defaultEnd.isEmpty ? Colors.grey : Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('休息时间：', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 20),
                            onPressed: () {
                              setState(() {
                                if (_restMinutes >= 10) _restMinutes -= 10;
                              });
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_restMinutes ~/ 60}h ${_restMinutes % 60}m',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 20),
                            onPressed: () {
                              setState(() {
                                if (_restMinutes < 240) _restMinutes += 10;
                              });
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isEditing ? _saveEdit : _addShift,
                    icon: Icon(_isEditing ? Icons.save : Icons.add),
                    label: Text(_isEditing ? '保存新版本' : '添加班次'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade100,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                if (_isEditing)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '⚠️ 将创建新版本，历史排班不受影响',
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ---- 班次列表 ----
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                if (activeShifts.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '📌 当前使用',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ),
                  ...activeShifts.map((shift) => _buildShiftTile(shift, app)),
                ],

                if (inactiveShifts.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '📂 历史版本',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ),
                  ...inactiveShifts.map((shift) => _buildShiftTile(shift, app)),
                ],

                if (activeShifts.isEmpty && inactiveShifts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        '暂无班次，请添加',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftTile(CustomShiftType shift, AppProvider app) {
    final isActive = shift.isActive;
    final hasRecords = app.getRecordsForDateRange(
      DateTime(2020, 1, 1),
      DateTime.now(),
    ).any((r) => r.shiftTypeId == shift.id);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Color(int.parse(shift.colorHex.replaceFirst('#', '0xFF'))),
            shape: BoxShape.circle,
          ),
        ),
        title: Row(
          children: [
            Text(
              shift.name,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 8),
            if (!isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'v${shift.version} 旧',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            if (shift.isDefault)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '默认',
                  style: TextStyle(color: Colors.orange.shade700, fontSize: 10),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '${shift.defaultStart} - ${shift.defaultEnd}  '
          '休息: ${shift.restMinutes ~/ 60}h ${shift.restMinutes % 60}m'
          '${shift.version > 1 ? '  v${shift.version}' : ''}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive)
              IconButton(
                icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                onPressed: () => _startEdit(shift),
                tooltip: '编辑（创建新版本）',
              ),
            if (!isActive && !shift.isDefault)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                onPressed: () => _deleteShift(shift),
                tooltip: '删除',
              ),
            if (isActive && shift.isDefault)
              const Chip(
                label: Text('默认'),
                backgroundColor: Colors.grey,
                labelStyle: TextStyle(color: Colors.white, fontSize: 10),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ],
        ),
      ),
    );
  }
}