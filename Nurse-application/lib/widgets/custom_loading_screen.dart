import 'package:flutter/material.dart';

class CustomLoadingScreen extends StatefulWidget {
  final String? message;
  final bool isOverlay;

  const CustomLoadingScreen({
    super.key,
    this.message,
    this.isOverlay = false,
  });

  @override
  State<CustomLoadingScreen> createState() => _CustomLoadingScreenState();
}

class _CustomLoadingScreenState extends State<CustomLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor =
        isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
    final contentColor = isDark ? Colors.white : Colors.black87;

    final content = Container(
      color: widget.isOverlay
          ? backgroundColor.withOpacity(0.9)
          : backgroundColor, // Slightly transparent if overlay
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Minimal Pulsing Logo
            ScaleTransition(
              scale: _animation.drive(
                Tween<double>(begin: 0.8, end: 1.0),
              ),
              child: FadeTransition(
                opacity: _animation.drive(
                  Tween<double>(begin: 0.5, end: 1.0),
                ),
                child: Icon(
                  Icons.medical_services_outlined, // Outlined is more minimal
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Subtle Loading Indicator (Optional, but good for feedback)
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary.withOpacity(0.5),
                ),
              ),
            ),

            // Minimal Text
            if (widget.message != null) ...[
              const SizedBox(height: 24),
              Text(
                widget.message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: contentColor.withOpacity(0.7),
                  fontWeight: FontWeight.w300,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );

    if (widget.isOverlay) {
      return Material(
        type: MaterialType.transparency,
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: content,
    );
  }
}
