import 'package:flutter/material.dart';
import '../widgets/hazard_near_miss_form.dart';
import '../widgets/incident_report_form_widget.dart';
import '../widgets/employee_injury_form.dart';

class UnifiedReportsForm extends StatefulWidget {
  const UnifiedReportsForm({super.key});

  @override
  State<UnifiedReportsForm> createState() => _UnifiedReportsFormState();
}

class _UnifiedReportsFormState extends State<UnifiedReportsForm> {
  String? _selectedReportType;

  final List<String> _reportTypes = [
    'Hazard / Near Miss',
    'Incident Report',
    'Employee Injury / Illness',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Submit Report',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0F2027),
                    const Color(0xFF203A43),
                    const Color(0xFF2C5364)
                  ]
                : [const Color(0xFFE0F7FA), const Color(0xFF80DEEA)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedReportType,
                      decoration: InputDecoration(
                        labelText: 'Select Report Type',
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                        prefixIcon: Icon(Icons.assignment_turned_in,
                            color: theme.colorScheme.primary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide:
                              BorderSide(color: Colors.grey.withOpacity(0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide:
                              BorderSide(color: theme.colorScheme.primary),
                        ),
                      ),
                      items: _reportTypes
                          .map((type) => DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedReportType = value;
                        });
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Display the selected form
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _selectedReportType == null
                      ? Container(
                          key: const ValueKey('empty'),
                          padding: const EdgeInsets.symmetric(
                              vertical: 60, horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.post_add_rounded,
                                size: 80,
                                color:
                                    theme.colorScheme.primary.withOpacity(0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Ready to File',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Select a report category above to begin filling out the form.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          key: ValueKey(_selectedReportType),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: _buildSelectedForm(),
                            ),
                          ),
                        ),
                ),
                // Extra padding at bottom
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedForm() {
    switch (_selectedReportType) {
      case 'Hazard / Near Miss':
        return const HazardNearMissForm();
      case 'Incident Report':
        return const IncidentReportFormWidget();
      case 'Employee Injury / Illness':
        return const EmployeeInjuryForm();
      default:
        return const SizedBox.shrink();
    }
  }
}
