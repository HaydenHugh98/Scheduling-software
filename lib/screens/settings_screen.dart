import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/reminder_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late ReminderSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = Provider.of<AppProvider>(context, listen: false).getReminderSettings();
  }

  void _saveSettings() {
    final app = Provider.of<AppProvider>(context, listen: false);
    app.saveReminderSettings(_settings);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('设置已保存')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '🔔 排班提醒',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('启用排班提醒'),
            subtitle: const Text('在班次开始前提醒您'),
            value: _settings.enabled,
            onChanged: (val) {
              setState(() {
                _settings = _settings.copyWith(enabled: val);
              });
            },
          ),
          ListTile(
            title: const Text('提前提醒时间'),
            subtitle: Text('${_settings.minutesBefore} 分钟'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () {
                    if (_settings.minutesBefore > 5) {
                      setState(() {
                        _settings = _settings.copyWith(
                          minutesBefore: _settings.minutesBefore - 5,
                        );
                      });
                    }
                  },
                ),
                Text(
                  '${_settings.minutesBefore}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    if (_settings.minutesBefore < 120) {
                      setState(() {
                        _settings = _settings.copyWith(
                          minutesBefore: _settings.minutesBefore + 5,
                        );
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('加班提醒'),
            subtitle: const Text('加班达到设定时间时提醒'),
            value: _settings.remindOvertime,
            onChanged: (val) {
              setState(() {
                _settings = _settings.copyWith(remindOvertime: val);
              });
            },
          ),
          if (_settings.remindOvertime)
            ListTile(
              title: const Text('加班提醒阈值'),
              subtitle: Text('${_settings.overtimeThreshold} 分钟'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () {
                      if (_settings.overtimeThreshold > 10) {
                        setState(() {
                          _settings = _settings.copyWith(
                            overtimeThreshold: _settings.overtimeThreshold - 10,
                          );
                        });
                      }
                    },
                  ),
                  Text(
                    '${_settings.overtimeThreshold}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      if (_settings.overtimeThreshold < 300) {
                        setState(() {
                          _settings = _settings.copyWith(
                            overtimeThreshold: _settings.overtimeThreshold + 10,
                          );
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          const Divider(),
          // ---- 新增开关 ----
          SwitchListTile(
            title: const Text('休息时显示当班同事'),
            subtitle: const Text('周视图中，本人休息时显示当天当班同事列表'),
            value: _settings.showColleaguesWhenResting,
            onChanged: (val) {
              setState(() {
                _settings = _settings.copyWith(showColleaguesWhenResting: val);
              });
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '💡 提示：\n• 排班提醒会在班次开始前自动发送\n• 加班提醒在保存排班时触发\n• 休息时显示当班同事，方便您快速联系',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}