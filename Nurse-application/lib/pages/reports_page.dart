import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../main.dart';
import '../models/employee.dart';
import '../models/shift.dart';
import '../models/daily_shift.dart';
import 'package:nurse_tracking_app/services/session.dart';

class ReportsPage extends StatefulWidget {
  final Employee employee;

  const ReportsPage({super.key, required this.employee});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  bool _loading = true;
  int _completed = 0;
  int _inProgress = 0;
  int _cancelled = 0;
  double _totalHours = 0;
  double _overtimeHours = 0;
  double _monthlyHours = 0;
  List<double> _dailyHours = [];
  List<String> _days = [];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final startOfMonth = DateFormat('yyyy-MM-dd')
          .format(DateTime(DateTime.now().year, DateTime.now().month, 1));

      final empId = await SessionManager.getEmpId();
      if (empId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Session expired. Please login again.')),
          );
        }
        setState(() {
          _loading = false;
        });
        return;
      }

      // Load shift data from shift table for status counts
      final shiftsResponse =
          await supabase.from('shift').select().eq('emp_id', empId);

      int completed = 0;
      int inProgress = 0;
      int cancelled = 0;

      for (final shiftData in shiftsResponse) {
        final shift = Shift.fromJson(shiftData);
        final status = shift.shiftStatus?.toLowerCase().replaceAll(' ', '_');

        if (status == 'completed') {
          completed++;
        } else if (status == 'in_progress') {
          inProgress++;
        } else if (status == 'cancelled') {
          cancelled++;
        }
      }

      // Load daily_shift summary data
      final dailyShiftsResponse =
          await supabase.from('daily_shift').select().eq('emp_id', empId);

      double totalHours = 0;
      double overtimeHours = 0;
      double monthlyHours = 0;

      for (final dailyShiftData in dailyShiftsResponse) {
        final dailyShift = DailyShift.fromJson(dailyShiftData);

        // Sum total hours (convert from bigint to double)
        if (dailyShift.dailyHrs != null) {
          totalHours += dailyShift.dailyHrs!.toDouble();

          // Check if it's today's shift
          if (dailyShift.shiftDate == today) {
            if (dailyShift.dailyHrs! > 8) {
              overtimeHours += dailyShift.dailyHrs!.toDouble() - 8;
            }
          }

          // Check if it's this month's shift
          if (dailyShift.shiftDate.compareTo(startOfMonth) >= 0) {
            monthlyHours += dailyShift.dailyHrs!.toDouble();
          }
        }
      }

      // Load daily hours for the past 7 days from daily_shift
      final startDate = DateTime.now().subtract(const Duration(days: 7));
      final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);

      final weeklyDailyShifts = await supabase
          .from('daily_shift')
          .select()
          .eq('emp_id', empId)
          .gte('shift_date', startDateStr);

      Map<String, double> dailyHoursMap = {};
      for (int i = 0; i < 7; i++) {
        final date = DateTime.now().subtract(Duration(days: i));
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        dailyHoursMap[dateStr] = 0.0;
      }

      for (final dailyShiftData in weeklyDailyShifts) {
        final dailyShift = DailyShift.fromJson(dailyShiftData);
        if (dailyShift.dailyHrs != null) {
          if (dailyHoursMap.containsKey(dailyShift.shiftDate)) {
            dailyHoursMap[dailyShift.shiftDate] =
                dailyHoursMap[dailyShift.shiftDate]! +
                    dailyShift.dailyHrs!.toDouble();
          }
        }
      }

      List<double> dailyHours = [];
      List<String> days = [];
      for (int i = 6; i >= 0; i--) {
        final date = DateTime.now().subtract(Duration(days: i));
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        final dayStr = DateFormat('E').format(date); // Mon, Tue, etc.
        days.add(dayStr);
        dailyHours.add(dailyHoursMap[dateStr] ?? 0.0);
      }

      setState(() {
        _completed = completed;
        _inProgress = inProgress;
        _cancelled = cancelled;
        _totalHours = totalHours;
        _overtimeHours = overtimeHours;
        _monthlyHours = monthlyHours;
        _dailyHours = dailyHours;
        _days = days;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading reports: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Reports'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KEY METRICS SECTION
                  Text(
                    'Key Metrics',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _SummaryCard(
                        title: "Total Hours",
                        value: "${_totalHours.toStringAsFixed(1)}h",
                        color: theme.colorScheme.primary,
                        icon: Icons.timer,
                      ),
                      const SizedBox(width: 12),
                      _SummaryCard(
                        title: "Overtime",
                        value: "${_overtimeHours.toStringAsFixed(1)}h",
                        color: Colors.orange,
                        icon: Icons.access_time_filled,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _SummaryCard(
                        title: "This Month",
                        value: "${_monthlyHours.toStringAsFixed(1)}h",
                        color: Colors.purple,
                        icon: Icons.calendar_month,
                      ),
                      const SizedBox(width: 12),
                      _SummaryCard(
                        title: "Completed",
                        value: "$_completed",
                        color: Colors.green,
                        icon: Icons.task_alt,
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // WEEKLY ACTIVITY SECTION
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Weekly Activity',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text('Hours Worked',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    child: Container(
                      height: 250,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white,
                            Colors.blue.shade50.withValues(alpha: 0.5),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: BarChart(
                        BarChartData(
                          barGroups: _getBarGroups(),
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  if (value.toInt() < _days.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        _days[value.toInt()],
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    );
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // SHIFT STATUS SECTION
                  Text(
                    'Shift Distribution',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 250,
                            child: PieChart(
                              PieChartData(
                                sections: _getPieSections(),
                                sectionsSpace: 4,
                                centerSpaceRadius: 50,
                                centerSpaceColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // PIE CHART LEGEND
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _LegendItem(
                                  color: Colors.green.shade400,
                                  label: 'Completed'),
                              _LegendItem(
                                  color: Colors.amber.shade400,
                                  label: 'In Progress'),
                              _LegendItem(
                                  color: Colors.red.shade400,
                                  label: 'Cancelled'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  List<PieChartSectionData> _getPieSections() {
    final total = _completed + _inProgress + _cancelled;
    if (total == 0) return [];
    return [
      PieChartSectionData(
        value: _completed.toDouble(),
        title: '$_completed',
        color: Colors.green.shade400,
        radius: 60,
        titleStyle:
            const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        value: _inProgress.toDouble(),
        title: '$_inProgress',
        color: Colors.amber.shade400,
        radius: 55,
        titleStyle:
            const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        value: _cancelled.toDouble(),
        title: '$_cancelled',
        color: Colors.red.shade400,
        radius: 50,
        titleStyle:
            const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
      ),
    ];
  }

  List<BarChartGroupData> _getBarGroups() {
    return List.generate(_dailyHours.length, (index) {
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: _dailyHours[index],
            color: Theme.of(context).colorScheme.primary,
            width: 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: 12, // Max hours expected
              color: Colors.grey.shade100,
            ),
          ),
        ],
      );
    });
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade100,
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey.shade900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}
