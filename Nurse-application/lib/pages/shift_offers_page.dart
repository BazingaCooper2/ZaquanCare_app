import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/shift_offer_record.dart';
import '../models/employee.dart';
import '../services/shift_offers_service.dart';
import '../main.dart';

class ShiftOffersPage extends StatefulWidget {
  final Employee employee;

  const ShiftOffersPage({super.key, required this.employee});

  @override
  State<ShiftOffersPage> createState() => _ShiftOffersPageState();
}

class _ShiftOffersPageState extends State<ShiftOffersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ShiftOfferRecord> _allOffers = [];
  List<ShiftOfferRecord> _pendingOffers = [];
  List<ShiftOfferRecord> _acceptedOffers = [];
  List<ShiftOfferRecord> _rejectedOffers = [];
  List<ShiftOfferRecord> _todayOffers = [];

  Map<String, int> _counts = {
    'total': 0,
    'pending': 0,
    'accepted': 0,
    'rejected': 0,
    'expired': 0,
    'today': 0,
  };

  double _acceptanceRate = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadOffers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOffers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      debugPrint(
          '🔄 REFRESHING OFFERS for EmpID: ${widget.employee.empId} ...');

      // detailed logging for debugging
      final all =
          await ShiftOffersService.fetchAllOffers(widget.employee.empId);
      debugPrint('📊 UI: Loaded ${all.length} total offers');

      final pending =
          await ShiftOffersService.fetchPendingOffers(widget.employee.empId);
      debugPrint('📊 UI: Loaded ${pending.length} pending offers');

      final accepted =
          await ShiftOffersService.fetchAcceptedOffers(widget.employee.empId);
      final rejected =
          await ShiftOffersService.fetchRejectedOffers(widget.employee.empId);
      final counts =
          await ShiftOffersService.getOfferCounts(widget.employee.empId);
      final rate =
          await ShiftOffersService.getAcceptanceRate(widget.employee.empId);

      final now = DateTime.now();
      final todayOffers = all.where((o) {
        if (o.sentAt == null) return false;
        return o.sentAt!.year == now.year &&
            o.sentAt!.month == now.month &&
            o.sentAt!.day == now.day;
      }).toList();

      counts['today'] = todayOffers.length;

      if (!mounted) return;

      setState(() {
        _allOffers = all;
        _pendingOffers = pending;
        _acceptedOffers = accepted;
        _rejectedOffers = rejected;
        _todayOffers = todayOffers;
        _counts = counts;
        _acceptanceRate = rate;
        _isLoading = false;
      });
    } catch (e, stack) {
      debugPrint('❌ UI Error loading offers: $e');
      debugPrint(stack.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading offers: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadOffers,
            ),
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Shift Offers'),
            Text(
              'Employee ID: ${widget.employee.empId}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: 'History (${_counts['total']})',
              icon: const Icon(Icons.history),
            ),
            Tab(
              text: 'Pending (${_counts['pending']})',
              icon: const Icon(Icons.pending_actions),
            ),
            Tab(
              text: 'Accepted (${_counts['accepted']})',
              icon: const Icon(Icons.check_circle_outline),
            ),
            Tab(
              text: 'Rejected (${_counts['rejected']})',
              icon: const Icon(Icons.cancel_outlined),
            ),
            Tab(
              text: 'Today (${_counts['today']})',
              icon: const Icon(Icons.today),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () => _runDiagnostic(context),
            tooltip: 'Debug DB',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOffers,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics Card
          _buildStatisticsCard(theme),

          // Tab Views
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOffersList(_allOffers, 'No offers yet'),
                      _buildOffersList(_pendingOffers, 'No pending offers'),
                      _buildOffersList(_acceptedOffers, 'No accepted offers'),
                      _buildOffersList(_rejectedOffers, 'No rejected offers'),
                      _buildOffersList(
                          _todayOffers, 'No offers received today'),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Offer Statistics',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Total',
                _counts['total'].toString(),
                Icons.assessment,
                Colors.white,
              ),
              _buildStatItem(
                'Pending',
                _counts['pending'].toString(),
                Icons.pending,
                Colors.orange.shade200,
              ),
              _buildStatItem(
                'Acceptance',
                '${_acceptanceRate.toStringAsFixed(1)}%',
                Icons.trending_up,
                Colors.green.shade200,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildOffersList(List<ShiftOfferRecord> offers, String emptyMessage) {
    if (offers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return AnimationLimiter(
      child: RefreshIndicator(
        onRefresh: _loadOffers,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: offers.length,
          itemBuilder: (context, index) {
            return AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 375),
              child: SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(
                  child: _buildOfferCard(offers[index]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildOfferCard(ShiftOfferRecord offer) {
    final theme = Theme.of(context);

    Color statusColor;
    Color statusBgColor;
    IconData statusIcon;

    switch (offer.status?.toLowerCase()) {
      case 'accepted':
        statusColor = Colors.green;
        statusBgColor = Colors.green.shade50;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusBgColor = Colors.red.shade50;
        statusIcon = Icons.cancel;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusBgColor = Colors.orange.shade50;
        statusIcon = Icons.pending;
        break;
      case 'expired':
        statusColor = Colors.grey;
        statusBgColor = Colors.grey.shade50;
        statusIcon = Icons.access_time;
        break;
      default:
        statusColor = Colors.blue;
        statusBgColor = Colors.blue.shade50;
        statusIcon = Icons.info;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: statusColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showOfferDetails(offer),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Offer ID and Order
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.tag,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Offer #${offer.offersId}',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (offer.offerOrder != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Order: ${offer.offerOrder}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          offer.statusDisplay,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Details Grid
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildInfoItem(
                      Icons.calendar_today,
                      'Shift Date',
                      offer.shiftDate ?? 'Unknown',
                      theme,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _buildInfoItem(
                      Icons.access_time,
                      'Time',
                      offer.shiftTimeDisplay,
                      theme,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: _buildInfoItem(
                      Icons.person_outline,
                      'Client',
                      offer.clientName,
                      theme,
                    ),
                  ),
                ],
              ),

              if (offer.clientAddress != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        offer.clientAddress!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.mark_email_read_outlined,
                      size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Received: ${offer.timeSinceSent}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),

              if (offer.responseTime != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.timer_outlined,
                        size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'Responded in ${offer.responseDuration}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
              if (offer.isPending) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _handleOfferAction(offer, 'accepted'),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Accept'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _handleOfferAction(offer, 'rejected'),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(color: Colors.red.shade200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleOfferAction(ShiftOfferRecord offer, String status) async {
    // Optimistic UI update could be done here, but for now we'll show loading
    setState(() => _isLoading = true);

    final success = await ShiftOffersService.updateOfferStatus(
      offersId: offer.offersId,
      status: status,
      shiftId: offer.shiftId,
      empId: offer.empId,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                status == 'accepted'
                    ? Icons.check_circle
                    : Icons.check_circle_outline,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text('Offer $status successfully'),
            ],
          ),
          backgroundColor:
              status == 'accepted' ? Colors.green : Colors.grey[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Reload to reflect changes in lists and counts
      _loadOffers();
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to update offer status'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildInfoItem(
      IconData icon, String label, String value, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }

  void _showOfferDetails(ShiftOfferRecord offer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.info_outline),
            const SizedBox(width: 8),
            Text('Offer #${offer.offersId}'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Offer ID', offer.offersId.toString()),
              _buildDetailRow('Status', offer.statusDisplay),
              const Divider(),
              const Text('Shift Details',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              _buildDetailRow('Date', offer.shiftDate ?? 'N/A'),
              _buildDetailRow('Time', offer.shiftTimeDisplay),
              _buildDetailRow('Shift ID', offer.shiftId?.toString() ?? 'N/A'),
              const Divider(),
              const Text('Client Details',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              _buildDetailRow('Client', offer.clientName),
              _buildDetailRow('Address', offer.clientAddress ?? 'N/A'),
              const Divider(),
              const Text('Timeline',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              _buildDetailRow('Sent At', offer.formattedSentAt),
              _buildDetailRow('Response Time', offer.formattedResponseTime),
              if (offer.responseTime != null)
                _buildDetailRow('Response Duration', offer.responseDuration),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runDiagnostic(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final sb = StringBuffer();
    sb.writeln('Diagnostic Report for EmpID: ${widget.employee.empId}');
    sb.writeln('--------------------------------------------------');

    try {
      // 1. Check basic connection / RLS visibility
      sb.writeln('1. Checking table access...');
      try {
        final countRes = await supabase
            .from('shift_offers')
            .select()
            .limit(1)
            .count(CountOption.exact);
        sb.writeln('   ✅ Access OK. Visible Total Rows: ${countRes.count}');
      } catch (e) {
        sb.writeln('   ❌ Test Failed. Possible RLS blocking.');
        sb.writeln('   Error: $e');
      }

      // 2. Check for ANY data (raw fetch)
      sb.writeln('\n2. Fetching any 1 row (no filter)...');
      try {
        final anyRow = await supabase.from('shift_offers').select().limit(1);
        if (anyRow.isNotEmpty) {
          sb.writeln('   ✅ Found data: ${anyRow[0].toString()}');
        } else {
          sb.writeln(
              '   ⚠️ No rows returned. Table might be empty or RLS hidden.');
        }
      } catch (e) {
        sb.writeln('   ❌ Error: $e');
      }

      // 3. Check for specific Employee data
      sb.writeln('\n3. Fetching for EmpID ${widget.employee.empId}...');
      try {
        final myRows = await supabase
            .from('shift_offers')
            .select()
            .eq('emp_id', widget.employee.empId)
            .limit(5);
        if (myRows.isNotEmpty) {
          sb.writeln('   ✅ Found ${myRows.length} rows for you.');
          sb.writeln('   First row status: ${myRows[0]['status']}');
        } else {
          sb.writeln('   ⚠️ No rows found for ID ${widget.employee.empId}.');
        }
      } catch (e) {
        sb.writeln('   ❌ Error: $e');
      }
    } catch (e) {
      sb.writeln('\n❌ Critical Error: $e');
    }

    if (context.mounted) {
      Navigator.pop(context); // close loading
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('DB Diagnostic'),
          content: SingleChildScrollView(
            child: Text(
              sb.toString(),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _loadOffers();
              },
              child: const Text('Retry Load'),
            ),
          ],
        ),
      );
    }
  }
}
