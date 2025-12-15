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
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  Future<void> _signIn() async {
    try {
      setState(() => _isLoading = true);

      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        context.showSnackBar('Please enter both email and password',
            isError: true);
        setState(() => _isLoading = false);
        return;
      }

      print('🔍 Attempting Supabase login for: $email');

      // ✅ Step 1: Authenticate user using Supabase Auth
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        context.showSnackBar('Invalid credentials', isError: true);
        setState(() => _isLoading = false);
        return;
      }

      print('✅ Logged in as ${user.email}, UID: ${user.id}');

      // ✅ Step 2: Fetch corresponding employee record
      // (Make sure your employee table either has auth_id or matching email)
      final employee = await supabase
          .from('employee')
          .select(
              'emp_id, first_name, last_name, email, designation, image_url, status')
          .eq('email', user.email ?? email)
          .maybeSingle();

      if (employee == null) {
        context.showSnackBar(
            'Employee profile not found in database. Contact admin.',
            isError: true);
        await supabase.auth.signOut();
        setState(() => _isLoading = false);
        return;
      }

      // ✅ Step 3: Save employee session locally
      await SessionManager.saveSession(employee);

      // ✅ Step 4: Navigate to dashboard
      if (mounted) {
        context.showSnackBar('✅ Login successful');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardPage()),
        );
      }
    } catch (error, stack) {
      print('❌ Login error: $error');
      print(stack);
      context.showSnackBar('Login failed: $error', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.local_hospital,
                  size: 80, color: Theme.of(context).primaryColor),
              const SizedBox(height: 24),
              Text(
                "Gerri-Assistance",
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
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () => setState(
                        () => _isPasswordVisible = !_isPasswordVisible),
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                  ),
                ),
                obscureText: !_isPasswordVisible,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _signIn,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Sign In'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
