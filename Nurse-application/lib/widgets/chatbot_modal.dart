import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nurse_tracking_app/services/chatbot_service.dart';
import 'package:nurse_tracking_app/services/session.dart';
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
    } else {
      _sendMessage(question);
    }
  }

  void _showLeaveRequestDialog() {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Leave'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for your leave request:'),
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
              _sendMessage('I want to take leave today. Reason: $reason');
            },
            child: const Text('Submit'),
          ),
        ],
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
                  children: FAQData.getFAQQuestions().take(4).map((question) {
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
