import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nurse_tracking_app/services/chatbot_service.dart';
import 'package:nurse_tracking_app/services/session.dart';
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

  Future<void> _sendMessageWithSignature(String message, String signatureUrl) async {
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
    // Find the FAQ to check if it has an action
    final faq = FAQData.faqs.firstWhere(
      (f) => f['question'] == question,
      orElse: () => {'question': question},
    );

    final action = faq['action'];
    if (action == 'leave') {
      _showLeaveRequestDialog();
    } else if (action == 'shift_change') {
      _showShiftChangeDialog();
    } else if (action == 'client_issue') {
      // Check which client issue it is
      if (question == 'Client booking ended early') {
        _showClientBookingEndedEarlyDialog();
      } else {
        // Client not home or Client cancelled - send directly
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
                                final signature = await signatureController.toPngBytes();
                                if (signature != null) {
                                  setDialogState(() {
                                    signatureImage = signature;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Signature saved!')),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ],
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
              onPressed: isSubmitting ? null : () async {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please provide a reason')),
                  );
                  return;
                }
                if (signatureImage == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please provide your signature')),
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
                                onPressed: () => Navigator.of(context).pop(),
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
                                onPressed: () => Navigator.of(context).pop(),
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
                  
                  print('✅ Signature uploaded: $publicUrl');

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
                  print('Error in call in sick: $e');
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

  void _showClientBookingEndedEarlyDialog() {
    final startTimeController = TextEditingController();
    final endTimeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Client Booking Ended Early'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please provide the booking times:'),
              const SizedBox(height: 16),
              TextField(
                controller: startTimeController,
                decoration: const InputDecoration(
                  labelText: 'Start Time',
                  hintText: 'e.g., 9am or 9:00',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: endTimeController,
                decoration: const InputDecoration(
                  labelText: 'End Time',
                  hintText: 'e.g., 5pm or 17:00',
                  border: OutlineInputBorder(),
                ),
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
              final start = startTimeController.text.trim();
              final end = endTimeController.text.trim();
              if (start.isEmpty || end.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide both start and end times')),
                );
                return;
              }
              Navigator.of(context).pop();
              _sendMessage('Client booking ended early. Start time: $start, End time: $end');
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_rounded, color: Colors.white),
                  const SizedBox(width: 12),
                  const Text(
                    'Nurse Assistant',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // FAQ Chips
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              color: Theme.of(context).colorScheme.surface,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: FAQData.getFAQQuestions().map((question) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(
                          question,
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () => _onFAQSelected(question),
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        side: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.3),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Chat messages
            Flexible(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
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

            // Input field
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
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
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        filled: true,
                        fillColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: _sendMessage,
                      enabled: !_isLoading,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: IconButton(
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            message.isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.isBot) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child:
                  const Icon(Icons.chat_bubble, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isBot
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(16).copyWith(
                  topRight:
                      message.isBot ? const Radius.circular(16) : Radius.zero,
                  topLeft:
                      !message.isBot ? const Radius.circular(16) : Radius.zero,
                ),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: message.isBot
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Colors.white,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          if (!message.isBot) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.secondary,
              child: const Icon(Icons.person, size: 16, color: Colors.white),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: const Icon(Icons.chat_bubble, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16).copyWith(
                topRight: const Radius.circular(16),
              ),
            ),
            child: const SizedBox(
              width: 40,
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
