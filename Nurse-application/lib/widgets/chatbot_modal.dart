import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nurse_tracking_app/services/email_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nurse_tracking_app/services/chatbot_service.dart';
import 'package:nurse_tracking_app/services/session.dart';
import 'package:nurse_tracking_app/models/shift.dart';
import 'package:signature/signature.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/faq_data.dart';

class ChatbotModal extends StatefulWidget {
  const ChatbotModal({super.key});

  @override
  State<ChatbotModal> createState() => _ChatbotModalState();
}

class _ChatbotModalState extends State<ChatbotModal> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  void _addWelcomeMessage() {
    _messages.add(ChatMessage(
      text: 'Hello! I\'m your Nurse Assistant. How can I help you today?',
      isBot: true,
      timestamp: DateTime.now(),
    ));
  }

  Future<String> _getStorageKey() async {
    final empId = await SessionManager.getEmpId();
    return 'chatbot_history_${empId ?? "guest"}';
  }

  Future<void> _loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey();
    final stored = prefs.getString(key);
    if (stored != null) {
      final decoded = jsonDecode(stored) as List<dynamic>;
      setState(() {
        _messages.clear();
        _messages.addAll(decoded.map((e) => ChatMessage(
              text: e['text'],
              isBot: e['isBot'],
              timestamp: DateTime.parse(e['timestamp']),
            )));
      });
      // Auto-scroll to the bottom after loading
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    } else {
      // Only add welcome message if no saved history exists
      setState(() {
        _addWelcomeMessage();
      });
    }
  }

  Future<void> _saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey();
    final encoded = jsonEncode(_messages
        .map((m) => {
              'text': m.text,
              'isBot': m.isBot,
              'timestamp': m.timestamp.toIso8601String(),
            })
        .toList());
    await prefs.setString(key, encoded);
  }

  /// Clears chat history for the current employee.
  /// Call this from your logout flow (e.g., SessionManager.clearSession()) if needed.
  // ignore: unused_element
  Future<void> _clearChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey();
    await prefs.remove(key);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty || _isLoading) return;

    // Add user message
    setState(() {
      _messages.add(ChatMessage(
        text: message,
        isBot: false,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });
    _messageController.clear();
    _scrollToBottom();
    await _saveChatHistory();

    // Check for intents that require UI interaction
    final intent = ChatbotService.detectIntent(message);

    if (intent.type == IntentType.clientBookingEndedEarly) {
      setState(() {
        _isLoading = false;
      });
      _showClientBookingEndedEarlyDialog();
      return;
    }

    if (intent.type == IntentType.clientNotHome) {
      setState(() {
        _isLoading = false;
      });
      _showClientIssueConfirmationDialog('Client not home');
      return;
    }

    if (intent.type == IntentType.clientCancelled) {
      setState(() {
        _isLoading = false;
      });
      _showClientIssueConfirmationDialog('Client cancelled');
      return;
    }

    if (intent.type == IntentType.callInSick) {
      setState(() {
        _isLoading = false;
      });
      _showLeaveRequestDialog();
      return;
    }

    // Get employee ID
    final empId = await SessionManager.getEmpId();

    // Process message
    final response = await ChatbotService.processMessage(message, empId);

    // Add bot response
    setState(() {
      _messages.add(ChatMessage(
        text: response,
        isBot: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = false;
    });
    _scrollToBottom();
    await _saveChatHistory();
  }

  Future<void> _sendMessageWithSignature(
      String message, String signatureUrl) async {
    if (message.trim().isEmpty || _isLoading) return;

    // Add user message
    setState(() {
      _messages.add(ChatMessage(
        text: message,
        isBot: false,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });
    _messageController.clear();
    _scrollToBottom();
    await _saveChatHistory();

    // Get employee ID
    final empId = await SessionManager.getEmpId();

    // Process message with signature URL
    final response = await ChatbotService.processMessageWithSignature(
      message,
      empId,
      signatureUrl,
    );

    // Add bot response
    setState(() {
      _messages.add(ChatMessage(
        text: response,
        isBot: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = false;
    });
    _scrollToBottom();
    await _saveChatHistory();
  }

  void _onFAQSelected(String question) async {
    debugPrint('FAQ Selected: $question');
    // Find the FAQ to check if it has an action
    final faq = FAQData.faqs.firstWhere(
      (f) => f['question'] == question,
      orElse: () => {'question': question},
    );

    final action = faq['action'];
    debugPrint('FAQ Action: $action');

    if (action == 'leave') {
      _showLeaveRequestDialog();
    } else if (action == 'shift_change') {
      _showShiftChangeDialog();
    } else if (action == 'client_issue') {
      debugPrint('Client Issue Action triggered');
      // Check which client issue it is
      if (question == 'Client booking ended early') {
        debugPrint('Calling _showClientBookingEndedEarlyDialog');
        _showClientBookingEndedEarlyDialog();
      } else if (question == 'Client not home' ||
          question == 'Client cancelled') {
        _showClientIssueConfirmationDialog(question);
      } else {
        _sendMessage(question);
      }
    } else if (action == 'delay') {
      _showDelayDialog();
    } else {
      _sendMessage(question);
    }
  }

  void _showLeaveRequestDialog() {
    final reasonController = TextEditingController();
    final signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    Uint8List? signatureImage;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Call in Sick'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Please provide a reason for calling in sick:'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                      hintText: 'e.g., Personal emergency, Family matter...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  const Text('Please provide your signature:'),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(
                      minHeight: 150,
                      maxHeight: 200,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 150,
                          width: double.infinity,
                          child: Signature(
                            controller: signatureController,
                            backgroundColor: Colors.grey.shade100,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Clear'),
                              onPressed: () => signatureController.clear(),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.save_alt),
                              label: const Text('Save'),
                              onPressed: () async {
                                final signature =
                                    await signatureController.toPngBytes();
                                if (signature != null) {
                                  setDialogState(() {
                                    signatureImage = signature;
                                  });
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Signature saved!')),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '⚠️ Please tap "Save" to confirm your signature before submitting.',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  if (signatureImage != null) ...[
                    const SizedBox(height: 8),
                    const Text('Signature preview:'),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 80,
                      child: Image.memory(signatureImage!),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                signatureController.dispose();
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final reason = reasonController.text.trim();
                      if (reason.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Please provide a reason')),
                        );
                        return;
                      }
                      if (signatureImage == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Please provide your signature')),
                        );
                        return;
                      }

                      // Set loading state
                      setDialogState(() {
                        isSubmitting = true;
                      });

                      // Upload signature to Supabase Storage
                      try {
                        final supabase = Supabase.instance.client;
                        final timestamp = DateTime.now().millisecondsSinceEpoch;
                        final fileName = 'sick_leave_signature_$timestamp.png';

                        // Try to upload the signature
                        try {
                          await supabase.storage
                              .from('sick_leave_signatures')
                              .uploadBinary(fileName, signatureImage!);
                        } catch (storageError) {
                          final errorStr = storageError.toString();

                          // Handle different storage errors
                          if (errorStr.contains('Bucket not found') ||
                              errorStr.contains('404')) {
                            setDialogState(() {
                              isSubmitting = false;
                            });
                            if (context.mounted) {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Storage Bucket Missing'),
                                  content: const Text(
                                    'The storage bucket "sick_leave_signatures" does not exist.\n\n'
                                    'Please create it in Supabase:\n'
                                    '1. Go to Supabase Dashboard → Storage\n'
                                    '2. Click "New bucket"\n'
                                    '3. Name: sick_leave_signatures\n'
                                    '4. Make it Public\n'
                                    '5. Click "Create bucket"\n\n'
                                    'Then try again.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return;
                          } else if (errorStr.contains('row-level security') ||
                              errorStr.contains('RLS') ||
                              errorStr.contains('403') ||
                              errorStr.contains('Unauthorized')) {
                            setDialogState(() {
                              isSubmitting = false;
                            });
                            if (context.mounted) {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Storage Permission Error'),
                                  content: const Text(
                                    'The storage bucket has Row-Level Security (RLS) enabled.\n\n'
                                    'To fix this:\n\n'
                                    'Option 1 (Recommended):\n'
                                    '1. Go to Supabase Dashboard → Storage\n'
                                    '2. Find "sick_leave_signatures" bucket\n'
                                    '3. Click the bucket → Settings\n'
                                    '4. Toggle "Public bucket" to ON\n'
                                    '5. Save\n\n'
                                    'Option 2 (If you need RLS):\n'
                                    'Go to Storage → Policies and create a policy that allows INSERT for authenticated users.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return;
                          }
                          rethrow;
                        }

                        // Get public URL
                        final publicUrl = supabase.storage
                            .from('sick_leave_signatures')
                            .getPublicUrl(fileName);

                        debugPrint('✅ Signature uploaded: $publicUrl');

                        // Close dialog and dispose controller
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                        signatureController.dispose();

                        // Send message with reason and signature URL
                        await _sendMessageWithSignature(
                          'I need to call in sick today. Reason: $reason',
                          publicUrl,
                        );
                      } catch (e) {
                        debugPrint('Error in call in sick: $e');
                        setDialogState(() {
                          isSubmitting = false;
                        });
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: ${e.toString()}'),
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  void _showShiftChangeDialog() {
    final reasonController = TextEditingController();
    final startTimeController = TextEditingController();
    final endTimeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel/Change Shift'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'Please provide the shift details you want to change:'),
              const SizedBox(height: 16),
              TextField(
                controller: startTimeController,
                decoration: const InputDecoration(
                  labelText: 'Current Start Time',
                  hintText: 'e.g., 9am or 9:00',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: endTimeController,
                decoration: const InputDecoration(
                  labelText: 'Current End Time',
                  hintText: 'e.g., 5pm or 17:00',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  hintText: 'Why do you need to change this shift?',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              final start = startTimeController.text.trim();
              final end = endTimeController.text.trim();
              Navigator.of(context).pop();
              _sendMessage(
                  'I cannot do the shift from $start to $end. Reason: $reason');
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _showDelayDialog() {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delay in Arrival'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for the delay:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'e.g., Traffic, Personal emergency...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              Navigator.of(context).pop();
              _sendMessage('I will be late for my shift. Reason: $reason');
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _fetchCurrentShift() async {
    try {
      final empId = await SessionManager.getEmpId();
      debugPrint('Fetching current shift for Emp ID: $empId');

      if (empId == null) {
        debugPrint('Emp ID is null');
        return null;
      }

      final supabase = Supabase.instance.client;

      // 1. Try RPC first
      try {
        final response =
            await supabase.rpc('get_active_shift', params: {'p_emp_id': empId});

        debugPrint('get_active_shift response: $response');

        if (response != null) {
          Map<String, dynamic>? shiftData;
          if (response is List) {
            if (response.isNotEmpty) {
              shiftData = Map<String, dynamic>.from(response.first as Map);
            }
          } else if (response is Map) {
            shiftData = Map<String, dynamic>.from(response as Map);
          }

          if (shiftData != null) {
            return await _ensureClientDetails(shiftData);
          }
        }
      } catch (e) {
        debugPrint('RPC get_active_shift failed: $e');
      }

      // 2. Fallback: Manual Date/Time check for "Scheduled" shifts that might be blocked by strict RPC logic
      debugPrint('Fallback: Checking scheduled shifts for today...');
      final now = DateTime.now();
      final todayStr =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      try {
        final fallbackResponse = await supabase
            .from('shift')
            .select('*, client:client_id(*)')
            .eq('emp_id', empId)
            .eq('date', todayStr)
            .eq('shift_status', 'scheduled');

        debugPrint('Fallback response: $fallbackResponse');

        if (fallbackResponse != null &&
            fallbackResponse is List &&
            fallbackResponse.isNotEmpty) {
          // Find the "best" match (closest start time that hasn't ended)
          for (var s in fallbackResponse) {
            final shift = s as Map<String, dynamic>;
            if (_isShiftActiveOrUpcoming(
                shift['shift_start_time'], shift['shift_end_time'])) {
              debugPrint(
                  'Found active/upcoming fallback shift: ${shift['shift_id']}');
              return await _ensureClientDetails(shift);
            }
          }
        }
      } catch (e) {
        debugPrint('Fallback query failed: $e');
      }

      return null;
    } catch (e) {
      debugPrint('Error fetching current shift: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> _ensureClientDetails(
      Map<String, dynamic> shiftData) async {
    if (shiftData['client_id'] != null &&
        (shiftData['client_name'] == null || shiftData['client'] == null)) {
      try {
        final supabase = Supabase.instance.client;
        final clientRes = await supabase
            .from('client')
            .select('name, service_type')
            .eq('client_id', shiftData['client_id'])
            .single();

        shiftData['client'] = clientRes;
        shiftData['client_name'] = clientRes['name'];
        shiftData['client_service_type'] = clientRes['service_type'];
      } catch (e) {
        debugPrint('Error fetching client details: $e');
      }
    }
    return shiftData;
  }

  bool _isShiftActiveOrUpcoming(String? startStr, String? endStr) {
    if (startStr == null || endStr == null) return false;
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final startParts = startStr.split(':');
      final endParts = endStr.split(':');

      final start = today.add(Duration(
          hours: int.parse(startParts[0]), minutes: int.parse(startParts[1])));
      final end = today.add(Duration(
          hours: int.parse(endParts[0]), minutes: int.parse(endParts[1])));

      // Allow if end time is in the future
      return end.isAfter(now);
    } catch (e) {
      return false;
    }
  }

  Future<void> _submitShiftChangeRequest({
    required String requestType,
    required Shift shift,
    required String reason,
    required Uint8List signatureImage,
    required String newShiftStatus,
    required Function(bool) setLoading,
  }) async {
    setLoading(true);
    try {
      final supabase = Supabase.instance.client;
      final empId = await SessionManager.getEmpId();

      // 1. Upload Signature
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'shift_change_signature_${shift.shiftId}_$timestamp.png';
      String? signatureUrl;

      try {
        await supabase.storage
            .from(
                'sick_leave_signatures') // Reusing bucket as per existing code
            .uploadBinary(fileName, signatureImage);
        signatureUrl = supabase.storage
            .from('sick_leave_signatures')
            .getPublicUrl(fileName);
      } catch (e) {
        debugPrint('Error uploading signature: $e');
        // Continue without signature URL if upload fails, but we have image for email
      }

      // 2. Insert into shift_change_requests
      await supabase.from('shift_change_requests').insert({
        'emp_id': empId,
        'original_shift_id': shift.shiftId,
        'request_type': requestType,
        'reason': reason,
        'status': 'pending',
        'signature_url': signatureUrl,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      // 3. Update Shift Status (Clock Out & End Early/Cancel)
      final nowUtc = DateTime.now().toUtc();
      await supabase.from('shift').update({
        'clock_out': nowUtc.toIso8601String(),
        'shift_status': newShiftStatus,
        'shift_progress_note': '$requestType: $reason'
      }).eq('shift_id', shift.shiftId);

      // 4. Clock out from time_logs if exists
      // We need to find the active time log for this user
      final activeLog = await supabase
          .from('time_logs')
          .select('id, clock_in_time')
          .eq('emp_id', empId!)
          .filter('clock_out_time', 'is', null)
          .maybeSingle();

      if (activeLog != null) {
        final clockInTime = DateTime.parse(activeLog['clock_in_time']);
        final totalHours = (nowUtc.difference(clockInTime).inMinutes / 60.0)
            .toStringAsFixed(2);

        await supabase.from('time_logs').update({
          'clock_out_time': nowUtc.toIso8601String(),
          'total_hours': double.parse(totalHours),
          'updated_at': nowUtc.toIso8601String(),
        }).eq('id', activeLog['id']);
      }

      // 5. Send Email
      // Fetch employee details for email
      final employeeRes = await supabase
          .from('employee')
          .select('first_name, last_name')
          .eq('emp_id', empId)
          .single();
      final employeeName =
          '${employeeRes['first_name']} ${employeeRes['last_name'] ?? ''}'
              .trim();

      await EmailService.sendShiftChangeRequestEmail(
        requestType: requestType.replaceAll('_', ' '),
        clientName: shift.clientName ?? 'Unknown Client',
        shiftDate: shift.date ?? 'Unknown Date',
        shiftTime: shift.formattedTimeRange,
        reason: reason,
        employeeName: employeeName,
        signatureUrl: signatureUrl,
        signatureImage: signatureImage,
      );

      if (mounted) {
        Navigator.of(context).pop(); // Close dialog

        // Add bot success message directly
        setState(() {
          _messages.add(ChatMessage(
            text: 'Shift has been updated and supervisor has been notified',
            isBot: true,
            timestamp: DateTime.now(),
          ));
          _isLoading = false;
        });
        _scrollToBottom();
        await _saveChatHistory();
      }
    } catch (e) {
      debugPrint('Error submitting request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setLoading(false);
      }
    }
  }

  void _showClientBookingEndedEarlyDialog() async {
    // Show loading indicator first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final shiftData = await _fetchCurrentShift();

    if (mounted) {
      Navigator.of(context).pop(); // Dismiss loading
    }

    if (shiftData == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active shift found to end early.')),
        );
      }
      return;
    }

    final shift = Shift.fromJson(shiftData);
    if (mounted) {
      _showEndShiftConfirmationDialog(shift);
    }
  }

  String _formatStatus(String? status) {
    if (status == null) return "N/A";
    if (status == 'in_progress') return "In Progress";
    if (status == 'scheduled') return "Scheduled";
    if (status == 'completed') return "Completed";
    return status
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  Color _getStatusColor(String? status) {
    if (status == 'in_progress') return Colors.green;
    if (status == 'scheduled') return Colors.blue;
    if (status == 'completed') return Colors.grey;
    return Colors.blueGrey;
  }

  void _showEndShiftConfirmationDialog(Shift shift) {
    final signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(child: Text('End Shift Early')),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  signatureController.dispose();
                  Navigator.of(context).pop();
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Client: ${shift.clientName}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Program: ${shift.clientServiceType ?? "N/A"}'),
                        const SizedBox(height: 4),
                        Text('Time: ${shift.formattedTimeRange}'),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text('Status: ',
                                style: TextStyle(fontWeight: FontWeight.w500)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getStatusColor(shift.shiftStatus),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _formatStatus(shift.shiftStatus),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Client booking ended early. Please sign below to confirm ending your shift now.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  const Text('Signature:'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    height: 150,
                    child: Signature(
                      controller: signatureController,
                      backgroundColor: Colors.grey.shade100,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => signatureController.clear(),
                      child: const Text('Clear Signature'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                signatureController.dispose();
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (signatureController.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Please sign to confirm.')),
                        );
                        return;
                      }

                      final signature = await signatureController.toPngBytes();
                      if (signature == null) return;

                      _submitShiftChangeRequest(
                        requestType: 'client_booking_ended_early',
                        shift: shift,
                        reason: 'Client booking ended early',
                        signatureImage: signature,
                        newShiftStatus: 'completed',
                        setLoading: (loading) {
                          setDialogState(() => isSubmitting = loading);
                        },
                      );
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirm End Shift'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showClientIssueConfirmationDialog(String issueType) async {
    setState(() => _isLoading = true);
    final shiftMap = await _fetchCurrentShift();
    setState(() => _isLoading = false);

    if (shiftMap == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No active shift found for $issueType.')),
        );
      }
      return;
    }

    final shiftObj = Shift.fromJson(shiftMap);
    if (!mounted) return;

    final signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    bool isSubmitting = false;

    // Determine dialog title and message based on issue type
    String dialogTitle = issueType;
    String dialogMessage =
        '$issueType. Please sign below to confirm ending your shift now.';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(dialogTitle)),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  signatureController.dispose();
                  Navigator.of(context).pop();
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Client: ${shiftObj.clientName ?? "N/A"}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Program: ${shiftObj.clientServiceType ?? "N/A"}'),
                        const SizedBox(height: 4),
                        Text('Time: ${shiftObj.formattedTimeRange}'),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text('Status: ',
                                style: TextStyle(fontWeight: FontWeight.w500)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getStatusColor(shiftObj.shiftStatus),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _formatStatus(shiftObj.shiftStatus),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    dialogMessage,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  const Text('Signature:'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    height: 150,
                    child: Signature(
                      controller: signatureController,
                      backgroundColor: Colors.grey.shade100,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => signatureController.clear(),
                      child: const Text('Clear Signature'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                signatureController.dispose();
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (signatureController.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Please sign to confirm.')),
                        );
                        return;
                      }

                      final signature = await signatureController.toPngBytes();
                      if (signature == null) return;

                      String requestTypeCode = 'other';
                      if (issueType == 'Client not home')
                        requestTypeCode = 'client_not_home';
                      if (issueType == 'Client cancelled')
                        requestTypeCode = 'client_cancelled';

                      _submitShiftChangeRequest(
                        requestType: requestTypeCode,
                        shift: shiftObj,
                        reason: issueType,
                        signatureImage: signature,
                        newShiftStatus: 'cancelled',
                        setLoading: (loading) {
                          setDialogState(() => isSubmitting = loading);
                        },
                      );
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Confirm ${issueType == 'Client not home' ? 'Not Home' : issueType == 'Client cancelled' ? 'Cancellation' : 'Action'}'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Modern Gradient Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF0F2027), const Color(0xFF203A43)]
                        : [
                            theme.colorScheme.primary,
                            theme.colorScheme.secondary
                          ],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.smart_toy_rounded,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nurse Assistant',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Always here to help',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // FAQ Chips (Scrollable horizontal list)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(
                        color: theme.dividerColor.withValues(alpha: 0.1)),
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: FAQData.getFAQQuestions().map((question) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          elevation: 0,
                          label: Text(
                            question,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          onPressed: () => _onFAQSelected(question),
                          backgroundColor:
                              theme.colorScheme.primary.withValues(alpha: 0.08),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Chat messages
              Flexible(
                child: Container(
                  color: theme.scaffoldBackgroundColor,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 20),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return const _TypingIndicator();
                      }

                      final message = _messages[index];
                      return _ChatBubble(message: message);
                    },
                  ),
                ),
              ),

              // Input field area
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: TextField(
                          controller: _messageController,
                          decoration: const InputDecoration(
                            hintText: 'Type your message...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                          ),
                          onSubmitted: _sendMessage,
                          enabled: !_isLoading,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.secondary
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Icon(Icons.send_rounded,
                                color: Colors.white, size: 22),
                        onPressed: _isLoading
                            ? null
                            : () => _sendMessage(_messageController.text),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isBot;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isBot,
    required this.timestamp,
  });
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBot = message.isBot;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment:
            isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isBot) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              child: Icon(Icons.smart_toy_rounded,
                  size: 18, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isBot
                    ? theme.colorScheme.surface
                    : theme.colorScheme.primary,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: isBot ? Radius.zero : const Radius.circular(20),
                  bottomRight: isBot ? const Radius.circular(20) : Radius.zero,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: isBot
                    ? Border.all(color: Colors.grey.withValues(alpha: 0.2))
                    : null,
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: isBot ? theme.colorScheme.onSurface : Colors.white,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (!isBot) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.secondary,
              child: const Icon(Icons.person_rounded,
                  size: 18, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            child: Icon(Icons.smart_toy_rounded,
                size: 18, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SizedBox(
              width: 32,
              height: 12,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(3, (index) {
                    return Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
