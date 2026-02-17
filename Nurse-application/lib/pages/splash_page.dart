import 'package:flutter/material.dart';
import 'package:nurse_tracking_app/pages/login_page.dart';
import 'package:nurse_tracking_app/pages/dashboard_page.dart';
import 'package:nurse_tracking_app/services/session.dart';
import 'package:nurse_tracking_app/widgets/custom_loading_screen.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    final empId = await SessionManager.getEmpId();

    if (!mounted) return;

    if (empId != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const DashboardPage()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const CustomLoadingScreen(
        message: 'Loading your preferences...',
      ),
    );
  }
}
