import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../services/email_service.dart';

class InjuryReportForm extends StatefulWidget {
  const InjuryReportForm({super.key});

  @override
  State<InjuryReportForm> createState() => _InjuryReportFormState();
}

class _InjuryReportFormState extends State<InjuryReportForm> {
  final _formKey = GlobalKey<FormState>();
  final _injuredPersonController = TextEditingController();
  final _reportingEmployeeController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime? _selectedDate;
  String? _selectedSeverity;
  String? _selectedStatus;

  final List<String> _severityOptions = ['Low', 'Moderate', 'High', 'Critical'];
  final List<String> _statusOptions = ['Pending', 'Investigating', 'Resolved'];

  bool _isSubmitting = false;

  @override
  void dispose() {
    _injuredPersonController.dispose();
    _reportingEmployeeController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null) {
      context.showSnackBar('Please select a date', isError: true);
      return;
    }
    if (_selectedSeverity == null) {
      context.showSnackBar('Please select a severity', isError: true);
      return;
    }
    if (_selectedStatus == null) {
      context.showSnackBar('Please select a status', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final data = {
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
        'injured_person': _injuredPersonController.text.trim(),
        'reporting_employee': _reportingEmployeeController.text.trim(),
        'location': _locationController.text.trim(),
        'description': _descriptionController.text.trim(),
        'severity': _selectedSeverity,
        'status': _selectedStatus,
      };

      // Insert into database
      await supabase.from('injury_reports').insert(data);

      // Send email to manager
      final emailSent = await EmailService.sendInjuryReport(
        date: DateFormat('yyyy-MM-dd').format(_selectedDate!),
        injuredPerson: _injuredPersonController.text.trim(),
        reportingEmployee: _reportingEmployeeController.text.trim(),
        location: _locationController.text.trim(),
        description: _descriptionController.text.trim(),
        severity: _selectedSeverity!,
        status: _selectedStatus!,
      );

      if (emailSent) {
        context
            .showSnackBar('Injury report submitted and email sent to manager');
      } else {
        context.showSnackBar(
            'Report submitted but failed to send email notification');
      }

      _resetForm();
    } catch (e) {
      context.showSnackBar('Failed to submit report: $e', isError: true);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _resetForm() {
    _formKey.currentState!.reset();
    _injuredPersonController.clear();
    _reportingEmployeeController.clear();
    _locationController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedDate = null;
      _selectedSeverity = null;
      _selectedStatus = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // ✅ Transparent header effect
      appBar: AppBar(
        title: const Text(
          'Injury Report Form',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent, // ✅ Transparent background
        elevation: 0, // ✅ No shadow
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFEAF3FF), // light nurse blue top
              Color(0xFFFFFFFF), // white bottom
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date
                      Text(
                        'Date',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _selectDate(context),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            suffixIcon: const Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            _selectedDate == null
                                ? 'Select Date'
                                : DateFormat('yyyy-MM-dd')
                                    .format(_selectedDate!),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Injured Person
                      _buildTextField(
                        controller: _injuredPersonController,
                        label: 'Injured Person',
                        validatorMsg: 'Please enter the injured person',
                      ),
                      const SizedBox(height: 16),

                      // Reporting Employee
                      _buildTextField(
                        controller: _reportingEmployeeController,
                        label: 'Reporting Employee',
                        validatorMsg: 'Please enter the reporting employee',
                      ),
                      const SizedBox(height: 16),

                      // Location
                      _buildTextField(
                        controller: _locationController,
                        label: 'Location',
                        validatorMsg: 'Please enter the location',
                      ),
                      const SizedBox(height: 16),

                      // Description
                      _buildTextField(
                        controller: _descriptionController,
                        label: 'Description',
                        validatorMsg: 'Please enter a description',
                        maxLines: 4,
                      ),
                      const SizedBox(height: 16),

                      // Severity
                      _buildDropdown(
                        label: 'Severity',
                        value: _selectedSeverity,
                        options: _severityOptions,
                        onChanged: (value) =>
                            setState(() => _selectedSeverity = value),
                      ),
                      const SizedBox(height: 16),

                      // Status
                      _buildDropdown(
                        label: 'Status',
                        value: _selectedStatus,
                        options: _statusOptions,
                        onChanged: (value) =>
                            setState(() => _selectedStatus = value),
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isSubmitting
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text(
                                  'Submit Report',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Custom textfield builder for consistency
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String validatorMsg,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return validatorMsg;
        return null;
      },
    );
  }

  // Custom dropdown builder
  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> options,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      items: options
          .map((option) => DropdownMenuItem(
                value: option,
                child: Text(option),
              ))
          .toList(),
      onChanged: onChanged,
      validator: (value) =>
          value == null ? 'Please select $label'.toLowerCase() : null,
    );
  }
}
