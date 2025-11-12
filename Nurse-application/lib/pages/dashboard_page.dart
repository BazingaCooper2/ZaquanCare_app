import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../models/employee.dart';
import '../providers/theme_provider.dart';
import 'package:nurse_tracking_app/services/session.dart';
import 'employee_info_page.dart';
import 'shift_page.dart';
import 'time_tracking_page.dart';
import 'login_page.dart';
import 'reports_page.dart'; // ✅ Added import
import 'injury_report_form.dart'; // ✅ Added import for Injury Report Form
import '../widgets/chatbot_button.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Employee? _employee;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmployeeData();
  }

  Future<void> _loadEmployeeData() async {
    try {
      final empId = await SessionManager.getEmpId();
      if (empId == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final response = await supabase
          .from('employee')
          .select()
          .eq('emp_id', empId)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _employee = Employee.fromJson(response);
          _isLoading = false;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Employee profile not found'),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        setState(() {
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await SessionManager.clearSession();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_employee == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Error loading employee data'),
              ElevatedButton(
                onPressed: _loadEmployeeData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final themeProvider = Provider.of<ThemeProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 600 ? 3 : 2;

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${_employee!.firstName}'),
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => themeProvider.toggleTheme(),
            tooltip: 'Toggle Theme',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.05),
                    Theme.of(context).colorScheme.surface,
                  ],
                ),
              ),
              child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: AnimationLimiter(
                child: GridView.count(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: AnimationConfiguration.toStaggeredList(
                    duration: const Duration(milliseconds: 375),
                    childAnimationBuilder: (widget) => SlideAnimation(
                      horizontalOffset: 50.0,
                      child: FadeInAnimation(
                        child: widget,
                      ),
                    ),
                    children: [
                      _DashboardCard(
                        title: 'Employee Info',
                        icon: Icons.person,
                        color: Colors.blue,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  EmployeeInfoPage(employee: _employee!),
                            ),
                          );
                        },
                      ),
                      _DashboardCard(
                        title: 'Shifts',
                        icon: Icons.calendar_today,
                        color: Colors.green,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ShiftPage(employee: _employee!),
                            ),
                          );
                        },
                      ),
                      _DashboardCard(
                        title: 'Time Tracking',
                        icon: Icons.access_time,
                        color: Colors.orange,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  TimeTrackingPage(employee: _employee!),
                            ),
                          );
                        },
                      ),
                      _DashboardCard(
                        title: 'Reports',
                        icon: Icons.analytics,
                        color: Colors.purple,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ReportsPage(
                                  employee: _employee!), // ✅ Navigate to reports
                            ),
                          );
                        },
                      ),
                      _DashboardCard(
                        title: 'Injury Report',
                        icon: Icons.report,
                        color: Colors.red,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const InjuryReportForm(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ),
          ),
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton(
                backgroundColor: Colors.red,
                onPressed: () async {
                  final Uri launchUri = Uri(
                    scheme: 'tel',
                    path: '911',
                  );
                  try {
                    await launchUrl(launchUri);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not launch phone dialer')),
                    );
                  }
                },
                child: const Text(
                  'SOS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const ChatbotButton(),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: color,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
