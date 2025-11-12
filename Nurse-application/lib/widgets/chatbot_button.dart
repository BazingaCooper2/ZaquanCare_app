import 'package:flutter/material.dart';
import 'chatbot_modal.dart';

class ChatbotButton extends StatelessWidget {
  const ChatbotButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 20,
      bottom: 100, // Position above SOS button
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(32),
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const ChatbotModal(),
              );
            },
            child: const Icon(
              Icons.chat_bubble_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }
}

