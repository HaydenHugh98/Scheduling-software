import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/user.dart';
import '../utils/color_picker.dart';
import 'shift_management_screen.dart';
import 'settings_screen.dart';

class ColleaguesScreen extends StatefulWidget {
  const ColleaguesScreen({super.key});

  @override
  State<ColleaguesScreen> createState() => _ColleaguesScreenState();
}

class _ColleaguesScreenState extends State<ColleaguesScreen> {
  final TextEditingController _nameController = TextEditingController();
  Color _selectedColor = Colors.green;

  void _pickColor() async {
    final picked = await showSimpleColorPicker(context);
    if (picked != null) {
      setState(() {
        _selectedColor = picked;
      });
    }
  }

  void _addColleague() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入同事姓名')),
      );
      return;
    }

    final app = Provider.of<AppProvider>(context, listen: false);
    final colorHex = colorToHex(_selectedColor);
    final user = User(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      isMe: false,
      avatarColor: colorHex,
    );

    await app.addUser(user);
    _nameController.clear();
    setState(() {
      _selectedColor = Colors.green;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已添加同事 ${user.name}')),
    );
  }

  void _deleteColleague(User user) async {
    if (user.isMe) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('不能删除自己')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除同事 "${user.name}" 吗？\n该同事的所有排班记录也将被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final app = Provider.of<AppProvider>(context, listen: false);
              await app.deleteUser(user.id);
              Navigator.pop(context);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已删除 ${user.name}')),
              );
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppProvider>(context);
    final users = app.getAllUsers();
    final currentUser = app.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('同事管理'),
        actions: [
          // 设置按钮（闹钟/提醒设置）
          IconButton(
            icon: const Icon(Icons.notifications_active),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            tooltip: '提醒设置',
          ),
          // 班次管理按钮
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ShiftManagementScreen()),
              );
            },
            tooltip: '班次管理',
          ),
        ],
      ),
      body: Column(
        children: [
          // 添加同事
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade50,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '同事姓名',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _pickColor,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _selectedColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addColleague,
                  child: const Text('添加'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 用户列表
          Expanded(
            child: ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final isCurrent = currentUser?.id == user.id;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  color: isCurrent ? Colors.blue.shade50 : null,
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
                      user.name,
                      style: TextStyle(
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      user.isMe ? '本人' : '同事',
                      style: TextStyle(
                        color: user.isMe ? Colors.green : Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!user.isMe)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deleteColleague(user),
                          ),
                        if (!isCurrent)
                          IconButton(
                            icon: const Icon(Icons.swap_horiz),
                            onPressed: () {
                              app.switchUser(user);
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('已切换到 ${user.name} 的排班')),
                              );
                            },
                          ),
                        if (isCurrent)
                          const Chip(
                            label: Text('当前'),
                            backgroundColor: Colors.blue,
                            labelStyle: TextStyle(color: Colors.white, fontSize: 10),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}