import 'package:flutter/material.dart';
import '../main.dart';
import '../models/employee.dart';
import '../models/shift.dart';
import 'package:nurse_tracking_app/services/session.dart';
import '../widgets/tasks_dialog.dart';

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
  int? _activeShiftId; // Stores the ID of the RPC-determined active shift

  // Date filter state
  String _selectedDateFilter =
      'Next Scheduled'; // 'Today', 'This Week', 'Next Scheduled', 'All'

  // Status filter state
  final Set<String> _selectedStatuses = {}; // Empty means show all

  @override
  void initState() {
    super.initState();
    _loadShifts();
  }

  Future<void> _loadShifts() async {
    try {
      debugPrint('🔍 SHIFT PAGE: Loading shifts...');
      setState(() => _isLoading = true);

      final empId = await SessionManager.getEmpId();
      debugPrint('🧠 SessionManager returned EMP_ID = $empId');

      if (empId == null) {
        debugPrint('❌ ERROR: empId is NULL');
        setState(() => _isLoading = false);
        return;
      }

      final countResponse =
          await supabase.from('shift').select('count').single();

      debugPrint('📊 Total rows in SHIFT table = ${countResponse['count']}');

      // Fetch shifts for emp_id
      debugPrint(
          '📡 Running query: SELECT * FROM shift WHERE emp_id = $empId ORDER BY date, shift_start_time');

      // 1. Fetch Active Shift ID via RPC (Single Source of Truth)
      try {
        final activeShiftResponse =
            await supabase.rpc('get_active_shift', params: {'p_emp_id': empId});
        debugPrint('🔥 RPC Active Shift Response: $activeShiftResponse');

        if (activeShiftResponse != null) {
          if (activeShiftResponse is List && activeShiftResponse.isNotEmpty) {
            _activeShiftId = activeShiftResponse[0]['shift_id'];
          } else if (activeShiftResponse is Map) {
            _activeShiftId = activeShiftResponse['shift_id'];
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error fetching active shift RPC in ShiftPage: $e');
      }

      // 2. Fetch All Shifts
      final response = await supabase
          .from('shift')
          .select()
          .eq('emp_id', empId)
          .order('date')
          .order('shift_start_time');

      debugPrint('📥 Raw fetched rows = ${response.length}');

      // Get unique client IDs
      final clientIds = response
          .where((s) => s['client_id'] != null)
          .map((s) => s['client_id'] as int)
          .toSet()
          .toList();

      debugPrint('📋 Unique client IDs to fetch: $clientIds');

      // Fetch all clients in bulk
      Map<int, Map<String, dynamic>> clientsMap = {};
      if (clientIds.isNotEmpty) {
        try {
          debugPrint('🔍 Attempting to fetch clients with IDs: $clientIds');

          final clientsResponse = await supabase
              .from('client')
              .select(
                  'client_id, name, patient_location, address_line1, city, province, service_type')
              .inFilter('client_id', clientIds);

          debugPrint('👥 Fetched ${clientsResponse.length} clients');
          debugPrint('👥 Client response data: $clientsResponse');

          for (var client in clientsResponse) {
            clientsMap[client['client_id']] = client;
            debugPrint(
                '  ✅ Loaded client ${client['client_id']}: ${client['name']}');
          }
        } catch (e, stack) {
          debugPrint('⚠️ Error fetching clients: $e');
          debugPrint('⚠️ Stack trace: $stack');
        }
      }

      // Parse shifts and attach client data
      final shifts = <Shift>[];
      for (var json in response) {
        final clientId = json['client_id'] as int?;
        final clientData = clientId != null ? clientsMap[clientId] : null;

        // Add client data to JSON
        if (clientData != null) {
          json['client_name'] = clientData['name'];
          json['client_service_type'] = clientData['service_type'];

          // Build location string from available data
          final locationParts = <String>[];
          if (clientData['patient_location'] != null &&
              clientData['patient_location'].toString().isNotEmpty) {
            locationParts.add(clientData['patient_location']);
          } else {
            // Fallback to address fields
            if (clientData['address_line1'] != null &&
                clientData['address_line1'].toString().isNotEmpty) {
              locationParts.add(clientData['address_line1']);
            }
            if (clientData['city'] != null &&
                clientData['city'].toString().isNotEmpty) {
              locationParts.add(clientData['city']);
            }
            if (clientData['province'] != null &&
                clientData['province'].toString().isNotEmpty) {
              locationParts.add(clientData['province']);
            }
          }

          json['client_location'] =
              locationParts.isNotEmpty ? locationParts.join(', ') : null;
          debugPrint(
              '✅ Attached client data for shift ${json['shift_id']}: ${clientData['name']} at ${json['client_location']}');
        }

        shifts.add(Shift.fromJson(json));
      }

      setState(() {
        _allShifts = shifts;
        _applyFilters();
        _isLoading = false;
      });

      debugPrint('✅ Parsed shifts count = ${_allShifts.length}');
    } catch (error) {
      debugPrint('❌ ERROR loading shifts: $error');

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
    } else if (_selectedDateFilter == 'Next Scheduled') {
      List<Shift> nextShifts = [];
      Shift? activeShift;

      // 1. Find and separate Active Shift (RPC Authority)
      if (_activeShiftId != null) {
        try {
          activeShift =
              _allShifts.firstWhere((s) => s.shiftId == _activeShiftId);
        } catch (_) {
          // Active shift might not be in the loaded list if pagination was used,
          // but here we load all, so it should be there.
        }
      }

      // 2. Filter the rest (Standard Future Logic)
      nextShifts = _allShifts.where((shift) {
        // Exclude the active shift as we add it explicitly at the top
        if (shift.shiftId == _activeShiftId) return false;

        if (shift.date == null) return false;
        try {
          final shiftDate = DateTime.parse(shift.date!);
          final shiftDateOnly =
              DateTime(shiftDate.year, shiftDate.month, shiftDate.day);

          // Include today and future dates
          if (shiftDateOnly.isBefore(today)) {
            return false;
          }

          // Show all shifts from today onwards
          return true;
        } catch (_) {
          return false;
        }
      }).toList();

      // Sort by date and time (earliest first)
      nextShifts.sort((a, b) {
        try {
          final dateA = DateTime.parse(a.date ?? '');
          final dateB = DateTime.parse(b.date ?? '');

          final comparison = dateA.compareTo(dateB);
          if (comparison != 0) return comparison;

          // If same date, sort by start time
          final timeA = a.shiftStartTime ?? '';
          final timeB = b.shiftStartTime ?? '';
          return timeA.compareTo(timeB);
        } catch (_) {
          return 0;
        }
      });

      // 3. Combine: Active Shift (Top) + Remaining Future Shifts
      filtered = [if (activeShift != null) activeShift, ...nextShifts];
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
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildDateFilterChip('Next Scheduled', theme),
                          const SizedBox(width: 8),
                          _buildDateFilterChip('Today', theme),
                          const SizedBox(width: 8),
                          _buildDateFilterChip('This Week', theme),
                          const SizedBox(width: 8),
                          _buildDateFilterChip('All', theme),
                        ],
                      ),
                    ),
                  ),

                  // STATUS FILTER
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.3),
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
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.3)),
                                const SizedBox(height: 16),
                                Text(
                                  'No shifts found for selected filters',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.6),
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
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
      selectedColor: color.withValues(alpha: 0.2),
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
    final timeRange = shift.formattedTimeRange; // Use 12-hour format
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
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => TasksDialog(shift: shift),
          );
        },
        borderRadius: BorderRadius.circular(16),
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
                        Row(
                          children: [
                            _buildStatusTag(statusText, statusColor),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: Colors.grey.withValues(alpha: 0.2)),
                              ),
                              child: Text(
                                '#${shift.shiftId}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow('🗓', date, theme),
                        const SizedBox(height: 8),
                        _buildInfoRow('⏰', timeRange, theme),
                        // Client Name
                        if (shift.clientName != null &&
                            shift.clientName!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildInfoRow('👤', shift.clientName!, theme),
                        ],
                        // Client Location
                        if (shift.clientLocation != null &&
                            shift.clientLocation!.isNotEmpty) ...[
                          _buildInfoRow('📍', shift.clientLocation!, theme),
                        ],
                        // Service Type (from Client)
                        if (shift.clientServiceType != null &&
                            shift.clientServiceType!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildInfoRow('💼', shift.clientServiceType!, theme),
                        ],
                      ],
                    ),
                  ),
                  if (canComplete)
                    ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => TasksDialog(shift: shift),
                        );
                      },
                      icon: const Icon(Icons.list_alt_rounded, size: 18),
                      label: const Text('View Tasks'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade50,
                        foregroundColor: Colors.blue.shade700,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.blue.shade200),
                        ),
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
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.3),
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
      ),
    );
  }

  Widget _buildStatusTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
