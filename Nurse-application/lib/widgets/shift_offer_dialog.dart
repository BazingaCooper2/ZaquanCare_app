import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/shift_offer.dart';
import '../services/shift_api_service.dart';
import '../models/shift_offer_record.dart';

/// Dialog for displaying shift offers with Accept/Reject UI
class ShiftOfferDialog extends StatefulWidget {
  final ShiftOffer offer;
  final int empId;
  final ShiftApiService apiService;
  final VoidCallback? onAccepted;
  final VoidCallback? onRejected;

  const ShiftOfferDialog({
    Key? key,
    required this.offer,
    required this.empId,
    required this.apiService,
    this.onAccepted,
    this.onRejected,
  }) : super(key: key);

  @override
  State<ShiftOfferDialog> createState() => _ShiftOfferDialogState();
}

class _ShiftOfferDialogState extends State<ShiftOfferDialog> {
  bool _isProcessing = false;

  Future<void> _handleResponse(ShiftOfferResponse response) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    final success = await widget.apiService.respondToShiftOffer(
      empId: widget.empId,
      shiftId: widget.offer.shiftId,
      response: response,
    );

    if (!mounted) return;

    if (success) {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response == ShiftOfferResponse.accepted
                ? '✅ Shift accepted successfully!'
                : '❌ Shift rejected',
          ),
          backgroundColor: response == ShiftOfferResponse.accepted
              ? Colors.green
              : Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );

      // Call callbacks
      if (response == ShiftOfferResponse.accepted) {
        widget.onAccepted?.call();
      } else {
        widget.onRejected?.call();
      }

      // Close dialog
      Navigator.of(context).pop();
    } else {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Failed to send response. Please try again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );

      setState(() {
        _isProcessing = false;
      });
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('EEEE, MMM d, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(
            Icons.work_outline,
            color: theme.colorScheme.primary,
            size: 28,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'New Shift Available',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: _isProcessing
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(
                    Icons.calendar_today,
                    'Date',
                    _formatDate(widget.offer.date),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.access_time,
                    'Time',
                    '${widget.offer.startTime} - ${widget.offer.endTime}',
                  ),
                  if (widget.offer.locationName != null) ...[
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.location_on,
                      'Location',
                      widget.offer.locationName!,
                    ),
                  ],
                  if (widget.offer.clientName != null) ...[
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.person,
                      'Client',
                      widget.offer.clientName!,
                    ),
                  ],
                  if (widget.offer.serviceType != null) ...[
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.medical_services,
                      'Service Type',
                      widget.offer.serviceType!,
                    ),
                  ],
                  if (widget.offer.description != null) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      'Description',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.secondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.offer.description!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          theme.colorScheme.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'First to accept gets the shift!',
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      actions: _isProcessing
          ? null
          : [
              TextButton.icon(
                onPressed: () => _handleResponse(ShiftOfferResponse.rejected),
                icon: const Icon(Icons.close),
                label: const Text('Reject'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _handleResponse(ShiftOfferResponse.accepted),
                icon: const Icon(Icons.check),
                label: const Text('Accept'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.secondary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Helper function to show shift offer dialog
void showShiftOfferDialog({
  required BuildContext context,
  required ShiftOfferRecord offer,
  VoidCallback? onAccepted,
  VoidCallback? onRejected,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.new_releases, color: Theme.of(context).primaryColor),
          const SizedBox(width: 12),
          const Expanded(child: Text('New Shift Offer!')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dialogDetailRow('Client', offer.clientName),
            const SizedBox(height: 8),
            _dialogDetailRow('Date', offer.shiftDate ?? 'N/A'),
            const SizedBox(height: 8),
            _dialogDetailRow('Time', offer.shiftTimeDisplay),
            if (offer.clientAddress != null) ...[
              const SizedBox(height: 8),
              _dialogDetailRow('Address', offer.clientAddress!),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.timer, size: 16, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Act fast! This shift is available to multiple employees.',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: onRejected ?? () => Navigator.pop(context),
          child: const Text('Dismiss', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: onAccepted ?? () => Navigator.pop(context),
          child: const Text('View & Accept'),
        ),
      ],
    ),
  );
}

Widget _dialogDetailRow(String label, String value) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.grey,
          fontWeight: FontWeight.w500,
        ),
      ),
      Text(
        value,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}
