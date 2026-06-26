import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/daily_record.dart';
import '../models/custom_shift_type.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  String _statsMode = 'week'; // 默认周
  DateTime _baseDate = DateTime.now(); // 用于周切换

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppProvider>(context);
    final user = app.currentUser;

    Map<String, dynamic> stats = {};
    String periodLabel = '';
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now();

    switch (_statsMode) {
      case 'year':
        stats = app.getStatsForYear(_baseDate.year);
        periodLabel = '${_baseDate.year}年';
        startDate = DateTime(_baseDate.year, 1, 1);
        endDate = DateTime(_baseDate.year, 12, 31);
        break;
      case 'month':
        stats = app.getStatsForMonth(_baseDate.year, _baseDate.month);
        periodLabel = '${_baseDate.year}年${_baseDate.month}月';
        startDate = DateTime(_baseDate.year, _baseDate.month, 1);
        endDate = DateTime(_baseDate.year, _baseDate.month + 1, 0);
        break;
      case 'week':
      default:
        stats = app.getStatsForWeek(_baseDate);
        final start = _baseDate.subtract(Duration(days: _baseDate.weekday - 1));
        final end = start.add(const Duration(days: 6));
        periodLabel =
            '${DateFormat('MM月dd日').format(start)} - ${DateFormat('MM月dd日').format(end)}';
        startDate = start;
        endDate = end;
        break;
    }

    final totalWorkHours = stats['totalWorkHours'] ?? 0.0;
    final totalOvertimeHours = stats['totalOvertimeHours'] ?? 0.0;
    final shiftCount = stats['shiftCount'] as Map<String, int>? ?? {};
    final workDays = stats['workDays'] ?? 0;
    final totalDays = stats['totalDays'] ?? 0;

    // ===== 关键：获取每日正常工时和加班工时（堆叠柱状图用） =====
    final dailyData = app.getDailyWorkAndOvertime(startDate, endDate);
    final sortedDates = dailyData.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          user?.isMe == true ? '我的统计' : '${user?.name}的统计',
        ),
        actions: [
          DropdownButton<String>(
            value: _statsMode,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'year', child: Text('年')),
              DropdownMenuItem(value: 'month', child: Text('月')),
              DropdownMenuItem(value: 'week', child: Text('周')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _statsMode = value;
                  _baseDate = DateTime.now(); // 重置到当前
                });
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- 时间导航（含左右箭头） ----
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      if (_statsMode == 'year') {
                        _baseDate = DateTime(_baseDate.year - 1, 1, 1);
                      } else if (_statsMode == 'month') {
                        _baseDate = DateTime(
                          _baseDate.year,
                          _baseDate.month - 1,
                          1,
                        );
                      } else {
                        _baseDate = _baseDate.subtract(const Duration(days: 7));
                      }
                    });
                  },
                ),
                Text(
                  periodLabel,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      if (_statsMode == 'year') {
                        _baseDate = DateTime(_baseDate.year + 1, 1, 1);
                      } else if (_statsMode == 'month') {
                        _baseDate = DateTime(
                          _baseDate.year,
                          _baseDate.month + 1,
                          1,
                        );
                      } else {
                        _baseDate = _baseDate.add(const Duration(days: 7));
                      }
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ---- 统计卡片 ----
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStatsCard(
                  '总工时',
                  '${totalWorkHours.toStringAsFixed(1)}h',
                  Icons.access_time,
                  Colors.blue,
                ),
                _buildStatsCard(
                  '加班时长',
                  '${totalOvertimeHours.toStringAsFixed(1)}h',
                  Icons.timer,
                  Colors.orange,
                ),
                _buildStatsCard(
                  '工作天数',
                  '$workDays 天',
                  Icons.calendar_today,
                  Colors.green,
                ),
                _buildStatsCard(
                  '总天数',
                  '$totalDays 天',
                  Icons.calendar_month,
                  Colors.purple,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ---- 饼图 ----
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📊 班次占比',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    AspectRatio(
                      aspectRatio: 1,
                      child: _buildPieChart(shiftCount, app),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: shiftCount.entries.map((entry) {
                        final shift = app.getShiftType(entry.key);
                        if (shift == null) return const SizedBox.shrink();
                        final color = Color(int.parse(shift.colorHex.replaceFirst('#', '0xFF')));
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${shift.name} (${entry.value}天)',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ---- 堆叠柱状图（正常 + 加班） ----
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📈 每日工时 (含加班)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 280,
                      child: _buildBarChart(sortedDates, dailyData),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLegendItem(Colors.blue, '正常'),
                        const SizedBox(width: 16),
                        _buildLegendItem(Colors.orange, '加班'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ---- 班次详情列表 ----
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📋 班次详情',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ...shiftCount.entries.map((entry) {
                      final shiftId = entry.key;
                      final count = entry.value;
                      final shift = app.getShiftType(shiftId);
                      if (count == 0 || shift == null) return const SizedBox.shrink();
                      final color = Color(int.parse(shift.colorHex.replaceFirst('#', '0xFF')));
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 60,
                              child: Text(
                                shift.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              child: LinearProgressIndicator(
                                value: totalDays > 0 ? count / totalDays : 0,
                                backgroundColor: Colors.grey.shade200,
                                color: color,
                                minHeight: 8,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$count 天',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (shiftCount.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            '暂无排班数据',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildStatsCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart(Map<String, int> shiftCount, AppProvider app) {
    final total = shiftCount.values.fold(0, (sum, count) => sum + count);
    if (total == 0) {
      return const Center(child: Text('暂无数据'));
    }

    final entries = shiftCount.entries.toList();
    final List<_PieData> pieData = [];
    double startAngle = -90.0;

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final shift = app.getShiftType(entry.key);
      if (shift == null) continue;
      final color = Color(int.parse(shift.colorHex.replaceFirst('#', '0xFF')));
      final sweepAngle = (entry.value / total) * 360.0;
      pieData.add(_PieData(
        color: color,
        sweepAngle: sweepAngle,
        startAngle: startAngle,
        label: shift.name,
        value: entry.value,
        total: total,
      ));
      startAngle += sweepAngle;
    }

    return CustomPaint(
      painter: _PieChartPainter(pieData),
      child: const SizedBox.expand(),
    );
  }

  // ---- 堆叠柱状图 ----
  Widget _buildBarChart(List<DateTime> dates, Map<DateTime, Map<String, double>> dailyData) {
    if (dates.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }
    // 计算最大值（正常+加班的总和）
    double maxTotal = 0;
    for (var date in dates) {
      final data = dailyData[date] ?? {'normal': 0.0, 'overtime': 0.0};
      final total = (data['normal'] ?? 0) + (data['overtime'] ?? 0);
      if (total > maxTotal) maxTotal = total;
    }
    if (maxTotal == 0) {
      return const Center(child: Text('暂无工时数据'));
    }

    return CustomPaint(
      painter: _BarChartPainter(dates, dailyData, maxTotal),
      child: const SizedBox.expand(),
    );
  }
}

// ===== 饼图数据类 =====
class _PieData {
  final Color color;
  final double sweepAngle;
  final double startAngle;
  final String label;
  final int value;
  final int total;
  _PieData({
    required this.color,
    required this.sweepAngle,
    required this.startAngle,
    required this.label,
    required this.value,
    required this.total,
  });
}

// ===== 饼图绘制器 =====
class _PieChartPainter extends CustomPainter {
  final List<_PieData> data;
  _PieChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.85;
    final rect = Rect.fromCircle(center: center, radius: radius);

    double currentAngle = -math.pi / 2; // 12点钟方向

    for (var item in data) {
      final sweepRad = item.sweepAngle * math.pi / 180;

      canvas.drawArc(
        rect,
        currentAngle,
        sweepRad,
        true,
        Paint()..color = item.color,
      );

      canvas.drawArc(
        rect,
        currentAngle,
        sweepRad,
        true,
        Paint()
          ..color = Colors.white.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      currentAngle += sweepRad;
    }

    // 中心圆
    final holeRadius = radius * 0.35;
    canvas.drawCircle(center, holeRadius, Paint()..color = Colors.white);

    final totalText = TextSpan(
      text: '${data.first.total}天',
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Color(0xFF333333),
      ),
    );
    final totalPainter = TextPainter(
      text: totalText,
      textDirection: ui.TextDirection.ltr,
    );
    totalPainter.layout();
    totalPainter.paint(
      canvas,
      Offset(center.dx - totalPainter.width / 2, center.dy - totalPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ===== 堆叠柱状图绘制器 =====
class _BarChartPainter extends CustomPainter {
  final List<DateTime> dates;
  final Map<DateTime, Map<String, double>> dailyData;
  final double maxTotal;

  _BarChartPainter(this.dates, this.dailyData, this.maxTotal);

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = size.width / dates.length * 0.55;
    final spacing = size.width / dates.length * 0.45;
    final leftPadding = (size.width - (barWidth * dates.length + spacing * (dates.length - 1))) / 2;
    final bottomY = size.height - 30;
    final topPadding = 25;

    // 网格线
    for (int i = 0; i <= 4; i++) {
      final y = bottomY - (i / 4) * (size.height - topPadding - bottomY);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = Colors.grey.shade200
          ..strokeWidth = 0.5,
      );
    }

    for (int i = 0; i < dates.length; i++) {
      final date = dates[i];
      final data = dailyData[date] ?? {'normal': 0.0, 'overtime': 0.0};
      final normal = data['normal'] ?? 0;
      final overtime = data['overtime'] ?? 0;
      final total = normal + overtime;

      if (total == 0) continue;

      final normalHeight = (normal / maxTotal) * (size.height - topPadding - bottomY);
      final overtimeHeight = (overtime / maxTotal) * (size.height - topPadding - bottomY);

      final x = leftPadding + i * (barWidth + spacing);
      final normalY = bottomY - normalHeight;
      final overtimeY = normalY - overtimeHeight;

      // 正常工时（蓝色）
      if (normal > 0) {
        final normalRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, normalY, barWidth, normalHeight),
          const Radius.circular(4),
        );
        canvas.drawRRect(normalRect, Paint()..color = Colors.blue);
      }

      // 加班工时（橙色，堆叠在正常之上）
      if (overtime > 0) {
        final overtimeRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, overtimeY, barWidth, overtimeHeight),
          const Radius.circular(4),
        );
        canvas.drawRRect(overtimeRect, Paint()..color = Colors.orange);
      }

      // 描边
      final totalRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, overtimeY, barWidth, normalHeight + overtimeHeight),
        const Radius.circular(4),
      );
      canvas.drawRRect(
        totalRect,
        Paint()
          ..color = Colors.white.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5,
      );

      // 底部日期
      final dateText = TextSpan(
        text: '${date.day}',
        style: const TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.w500),
      );
      final datePainter = TextPainter(
        text: dateText,
        textDirection: ui.TextDirection.ltr,
      );
      datePainter.layout();
      datePainter.paint(
        canvas,
        Offset(x + barWidth / 2 - datePainter.width / 2, bottomY + 6),
      );

      // 显示总工时数值（在柱顶上方）
      if (total > 0.1) {
        final valueText = TextSpan(
          text: '${total.toStringAsFixed(1)}h',
          style: const TextStyle(
            color: Color(0xFF333333),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        );
        final valuePainter = TextPainter(
          text: valueText,
          textDirection: ui.TextDirection.ltr,
        );
        valuePainter.layout();
        valuePainter.paint(
          canvas,
          Offset(x + barWidth / 2 - valuePainter.width / 2, overtimeY - 18),
        );
      }
    }

    // Y轴刻度（以maxTotal为最大值）
    for (int i = 0; i <= 4; i++) {
      final value = maxTotal * (i / 4);
      final y = bottomY - (i / 4) * (size.height - topPadding - bottomY);
      final label = TextSpan(
        text: value.toStringAsFixed(value < 1 ? 1 : 0),
        style: const TextStyle(color: Colors.grey, fontSize: 10),
      );
      final painter = TextPainter(
        text: label,
        textDirection: ui.TextDirection.ltr,
      );
      painter.layout();
      painter.paint(canvas, Offset(2, y - painter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}