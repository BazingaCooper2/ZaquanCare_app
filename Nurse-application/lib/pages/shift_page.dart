import 'package:flutter/material.dart';
import '../main.dart';
import '../models/employee.dart';
import '../models/shift.dart';
import 'package:nurse_tracking_app/services/session.dart';

class ShiftPage extends StatefulWidget {
  final Employee employee;

  const ShiftPage({super.key, required this.employee});

  @override
  State<ShiftPage> createState() => _ShiftPageState();
}

class _ShiftPageState extends State<ShiftPage> {
  List<Shift> _scheduled = [];
  List<Shift> _inProgress = [];
  List<Shift> _completed = [];
  List<Shift> _cancelled = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadShifts();
  }

  Future<void> _loadShifts() async {
    try {
      setState(() => _isLoading = true);

      final empId = await SessionManager.getEmpId();

      // 🔍 Debug line to verify which empId is being used
      print('🧠 Logged in empId from SessionManager: $empId');

      if (empId == null) {
        setState(() => _isLoading = false);
        return;
      }

      // ✅ Use correct column name `emp_id`
      final response = await supabase
          .from('shift')
          .select('*')
          // Cast empId safely if stored as string
          .eq('emp_id', int.tryParse(empId.toString()) ?? empId)
          .order('date')
          .order('shift_start_time');

      // ✅ Convert response to model list
      final shifts =
          response.map<Shift>((json) => Shift.fromJson(json)).toList();

      // ✅ Normalize shift status casing for grouping
      setState(() {
        _scheduled = shifts
            .where((s) => s.shiftStatus?.toLowerCase() == 'scheduled')
            .toList();
        _inProgress = shifts
            .where((s) =>
                s.shiftStatus?.toLowerCase() == 'in progress' ||
                s.shiftStatus?.toLowerCase() == 'in_progress')
            .toList();
        _completed = shifts
            .where((s) => s.shiftStatus?.toLowerCase() == 'completed')
            .toList();
        _cancelled = shifts
            .where((s) => s.shiftStatus?.toLowerCase() == 'cancelled')
            .toList();
        _isLoading = false;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading shifts: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateShiftStatus(Shift shift, String newStatus) async {
    try {
      await supabase
          .from('shift')
          .update({'shift_status': newStatus}).eq('shift_id', shift.shiftId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Shift status updated to ${newStatus.replaceAll('_', ' ')}'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      _loadShifts();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating shift status: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shifts'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadShifts),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection('Scheduled', _scheduled),
                  _buildSection('In Progress', _inProgress),
                  _buildSection('Completed', _completed),
                  _buildSection('Cancelled', _cancelled),
                ],
              ),
            ),
    );
  }

  Widget _buildSection(String title, List<Shift> shifts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        if (shifts.isEmpty)
          const Text('No shifts in this category')
        else
          ...shifts.map((shift) => _buildCard(shift)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCard(Shift shift) {
    final date = shift.date ?? 'No date';
    final start = shift.shiftStartTime ?? 'No start time';
    final end = shift.shiftEndTime ?? 'No end time';
    final duration = shift.durationHours?.toStringAsFixed(2) ?? 'N/A';
    final overtime = shift.overtimeHours?.toStringAsFixed(2) ?? 'N/A';
    final clientName = 'Client ID: ${shift.clientId ?? 'N/A'}';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clientName,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text('$date $start - $end'),
                      if (shift.skills != null && shift.skills!.isNotEmpty)
                        Text('Skills: ${shift.skills}'),
                      if (shift.tags != null && shift.tags!.isNotEmpty)
                        Text('Tags: ${shift.tags}'),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: shift.statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: shift.statusColor),
                      ),
                      child: Text(
                        shift.statusDisplayText,
                        style: TextStyle(
                          color: shift.statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (shift.shiftStatus?.toLowerCase() == 'scheduled' ||
                        shift.shiftStatus?.toLowerCase() == 'in progress' ||
                        shift.shiftStatus?.toLowerCase() == 'in_progress')
                      ElevatedButton(
                        onPressed: () => _updateShiftStatus(shift, 'completed'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                        ),
                        child: const Text('Complete',
                            style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child:
                      _buildInfoChip('Duration', '${duration}h', Colors.blue),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child:
                      _buildInfoChip('Overtime', '${overtime}h', Colors.orange),
                ),
              ],
            ),
            if (shift.shiftProgressNote != null &&
                shift.shiftProgressNote!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Progress Note: ${shift.shiftProgressNote}',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
