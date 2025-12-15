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
  List<Shift> _allShifts = [];
  List<Shift> _filteredShifts = [];
  bool _isLoading = true;

  // Date filter state
  String _selectedDateFilter = 'All'; // 'Today', 'This Week', 'All'

  // Status filter state
  Set<String> _selectedStatuses = {}; // Empty means show all

  @override
  void initState() {
    super.initState();
    _loadShifts();
  }

  Future<void> _loadShifts() async {
    try {
      print('🔍 SHIFT PAGE: Loading shifts...');
      setState(() => _isLoading = true);

      final empId = await SessionManager.getEmpId();
      print('🧠 SessionManager returned EMP_ID = $empId');

      if (empId == null) {
        print('❌ ERROR: empId is NULL');
        setState(() => _isLoading = false);
        return;
      }

      // Count rows in shift table
      final countResponse =
          await supabase.from('shift').select('count').single();

      print('📊 Total rows in SHIFT table = ${countResponse['count']}');

      // Fetch shifts for emp_id
      print('📡 Running query: SELECT * FROM shift WHERE emp_id = $empId');

      final response = await supabase
          .from('shift')
          .select()
          .eq('emp_id', empId)
          .order('date')
          .order('shift_start_time');

      print('📥 Raw fetched rows = ${response.length}');
      print('📥 Raw shift data = $response');

      final shifts =
          response.map<Shift>((json) => Shift.fromJson(json)).toList();

      setState(() {
        _allShifts = shifts;
        _applyFilters();
        _isLoading = false;
      });

      print('✅ Parsed shifts count = ${_allShifts.length}');
    } catch (error) {
      print('❌ ERROR loading shifts: $error');

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

  void _applyFilters() {
    List<Shift> filtered = List.from(_allShifts);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_selectedDateFilter == 'Today') {
      filtered = filtered.where((shift) {
        if (shift.date == null) return false;
        try {
          final shiftDate = DateTime.parse(shift.date!);
          final shiftDateOnly =
              DateTime(shiftDate.year, shiftDate.month, shiftDate.day);
          return shiftDateOnly.isAtSameMomentAs(today);
        } catch (_) {
          return false;
        }
      }).toList();
    } else if (_selectedDateFilter == 'This Week') {
      final daysFromMonday = now.weekday - 1;
      final monday = today.subtract(Duration(days: daysFromMonday));
      final sunday = monday.add(const Duration(days: 6));

      filtered = filtered.where((shift) {
        if (shift.date == null) return false;
        try {
          final shiftDate = DateTime.parse(shift.date!);
          final shiftDateOnly =
              DateTime(shiftDate.year, shiftDate.month, shiftDate.day);
          return shiftDateOnly.compareTo(monday) >= 0 &&
              shiftDateOnly.compareTo(sunday) <= 0;
        } catch (_) {
          return false;
        }
      }).toList();
    }

    if (_selectedStatuses.isNotEmpty) {
      filtered = filtered.where((shift) {
        final status = shift.shiftStatus?.toLowerCase().replaceAll(' ', '_');
        return status != null && _selectedStatuses.contains(status);
      }).toList();
    }

    setState(() {
      _filteredShifts = filtered;
    });
  }

  void _onDateFilterChanged(String filter) {
    setState(() {
      _selectedDateFilter = filter;
    });
    _applyFilters();
  }

  void _onStatusFilterToggled(String status) {
    final normalized = status.toLowerCase().replaceAll(' ', '_');
    setState(() {
      if (_selectedStatuses.contains(normalized)) {
        _selectedStatuses.remove(normalized);
      } else {
        _selectedStatuses.add(normalized);
      }
    });
    _applyFilters();
  }

  Future<void> _updateShiftStatus(Shift shift, String newStatus) async {
    try {
      await supabase
          .from('shift')
          .update({'shift_status': newStatus}).eq('shift_id', shift.shiftId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Shift status updated to ${newStatus.replaceAll('_', ' ')}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      await _loadShifts();
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shift Dashboard'),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadShifts,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // DATE FILTER
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildDateFilterChip('Today', theme),
                        _buildDateFilterChip('This Week', theme),
                        _buildDateFilterChip('All', theme),
                      ],
                    ),
                  ),

                  // STATUS FILTER
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant.withOpacity(0.3),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildStatusChip(
                              'scheduled', 'Scheduled', Colors.orange),
                          const SizedBox(width: 8),
                          _buildStatusChip(
                              'in_progress', 'In Progress', Colors.blue),
                          const SizedBox(width: 8),
                          _buildStatusChip(
                              'completed', 'Completed', Colors.green),
                          const SizedBox(width: 8),
                          _buildStatusChip(
                              'cancelled', 'Cancelled', Colors.red),
                        ],
                      ),
                    ),
                  ),

                  // SHIFT LIST
                  Expanded(
                    child: _filteredShifts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.calendar_today_outlined,
                                    size: 64,
                                    color:
                                        colorScheme.onSurface.withOpacity(0.3)),
                                const SizedBox(height: 16),
                                Text(
                                  'No shifts found for selected filters',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color:
                                        colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredShifts.length,
                            itemBuilder: (context, index) {
                              return _buildShiftCard(
                                  _filteredShifts[index], theme);
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDateFilterChip(String label, ThemeData theme) {
    final isSelected = _selectedDateFilter == label;
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () => _onDateFilterChanged(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? colorScheme.onPrimary
                : colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status, String label, Color color) {
    final normalized = status.toLowerCase().replaceAll(' ', '_');
    final isSelected = _selectedStatuses.contains(normalized);

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _onStatusFilterToggled(status),
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,
      labelStyle: TextStyle(
        color: isSelected ? color : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? color : Colors.grey[300]!,
        width: isSelected ? 2 : 1,
      ),
    );
  }

  Widget _buildShiftCard(Shift shift, ThemeData theme) {
    final date = shift.date ?? 'No date';
    final start = shift.shiftStartTime ?? 'No start time';
    final end = shift.shiftEndTime ?? 'No end time';
    final statusColor = shift.statusColor;
    final statusText = shift.statusDisplayText;
    final normalized = shift.shiftStatus?.toLowerCase().replaceAll(' ', '_');
    final canComplete =
        normalized == 'scheduled' || normalized == 'in_progress';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatusTag(statusText, statusColor),
                      const SizedBox(height: 12),
                      _buildInfoRow('🗓', date, theme),
                      const SizedBox(height: 8),
                      _buildInfoRow('⏰', '$start - $end', theme),
                    ],
                  ),
                ),
                if (canComplete)
                  ElevatedButton.icon(
                    onPressed: () => _updateShiftStatus(shift, 'completed'),
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: const Text('Complete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),

            // Skills
            if (shift.skills != null && shift.skills!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _buildInfoRow('💡', 'Skills: ${shift.skills}', theme),
              ),

            // Progress Note
            if (shift.shiftProgressNote != null &&
                shift.shiftProgressNote!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _buildInfoRow('📝', shift.shiftProgressNote!, theme),
                ),
              ),

            const SizedBox(height: 12),

            // Duration & Overtime
            Row(
              children: [
                Expanded(
                  child: _buildInfoChip(
                    'Duration',
                    '${shift.durationHours?.toStringAsFixed(1) ?? 'N/A'}h',
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInfoChip(
                    'Overtime',
                    '${shift.overtimeHours?.toStringAsFixed(1) ?? 'N/A'}h',
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String icon, String text, ThemeData theme) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
