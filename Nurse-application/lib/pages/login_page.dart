import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nurse_tracking_app/main.dart';
import 'package:nurse_tracking_app/pages/dashboard_page.dart';
import 'package:nurse_tracking_app/services/session.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;
  late final TextEditingController _emailController = TextEditingController();
  late final TextEditingController _passwordController =
      TextEditingController();

  Future<void> _signIn() async {
    try {
      setState(() => _isLoading = true);

      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text.trim();

      print('🔍 Attempting login for: $email');

      final response = await supabase
          .from('employee')
          .select(
              'emp_id, first_name, last_name, email, password, designation, image_url, status')
          .ilike('email', email) // case-insensitive email match
          .eq('password', password)
          .maybeSingle();

      print('🧾 Supabase response: $response');

      if (!mounted) return;

      if (response != null) {
        // Save session with the response data
        await SessionManager.saveSession(response);

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DashboardPage()),
          );
        }
      } else {
        context.showSnackBar('Invalid email or password', isError: true);
      }
    } catch (error, stack) {
      print('❌ Login error: $error');
      print(stack);
      if (mounted) {
        context.showSnackBar('Unexpected error occurred', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.local_hospital,
                  size: 80, color: Theme.of(context).primaryColor),
              const SizedBox(height: 24),
              Text(
                "Gerri's Assistance",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Hospital Home Care Management',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 48),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _signIn,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Sign In'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
