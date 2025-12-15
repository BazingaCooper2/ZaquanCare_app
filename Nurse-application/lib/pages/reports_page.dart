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
    return Scaffold(
      appBar: AppBar(title: const Text("Report")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _SummaryCard(
                        title: "Total Hours Worked",
                        value: "${_totalHours.toStringAsFixed(2)} h",
                        color: Colors.blue,
                      ),
                      _SummaryCard(
                        title: "Overtime Hours Today",
                        value: "${_overtimeHours.toStringAsFixed(2)} h",
                        color: Colors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _SummaryCard(
                        title: "Monthly Hours",
                        value: "${_monthlyHours.toStringAsFixed(2)} h",
                        color: Colors.purple,
                      ),
                      _SummaryCard(
                        title: "Completed Shifts",
                        value: "$_completed",
                        color: Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _SummaryCard(
                        title: "In Progress",
                        value: "$_inProgress",
                        color: Colors.amber,
                      ),
                      _SummaryCard(
                        title: "Cancelled",
                        value: "$_cancelled",
                        color: Colors.red,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const SizedBox.shrink(),
                  const SizedBox(height: 24),
                  const Text(
                    'Shift Status Distribution',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sections: _getPieSections(),
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Daily Hours (Last 7 Days)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: BarChart(
                      BarChartData(
                        barGroups: _getBarGroups(),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() < _days.length) {
                                  return Text(_days[value.toInt()],
                                      style: const TextStyle(fontSize: 12));
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: true),
                          ),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                      ),
                    ),
                  ),
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
        title: 'Completed\n$_completed',
        color: Colors.green,
        radius: 50,
      ),
      PieChartSectionData(
        value: _inProgress.toDouble(),
        title: 'In Progress\n$_inProgress',
        color: Colors.amber,
        radius: 50,
      ),
      PieChartSectionData(
        value: _cancelled.toDouble(),
        title: 'Cancelled\n$_cancelled',
        color: Colors.red,
        radius: 50,
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
            color: Colors.blue,
          ),
        ],
      );
    });
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(title,
                  style: const TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 8),
              Text(value,
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
