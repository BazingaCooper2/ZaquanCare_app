import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import 'package:signature/signature.dart';
import '../main.dart';
import '../services/email_service.dart';
import '../services/session.dart';

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

  // Signature controller and state
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  Uint8List? _signatureImage;
  String? _uploadedSignatureUrl;

  @override
  void dispose() {
    _injuredPersonController.dispose();
    _reportingEmployeeController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _signatureController.dispose();
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

  Future<String?> _uploadSignatureToSupabase(Uint8List signatureBytes) async {
    try {
      final supabase = Supabase.instance.client;
      final fileName = 'signature_${DateTime.now().millisecondsSinceEpoch}.png';

      await supabase.storage
          .from('injury_signatures')
          .uploadBinary(fileName, signatureBytes);

      final publicUrl =
          supabase.storage.from('injury_signatures').getPublicUrl(fileName);
      print('✅ Signature uploaded: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('❌ Error uploading signature: $e');
      return null;
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

    if (_signatureImage == null) {
      context.showSnackBar('Please sign before submitting!', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final empId = await SessionManager.getEmpId();
      if (empId == null) {
        context.showSnackBar('You must be logged in to submit a report.',
            isError: true);
        setState(() => _isSubmitting = false);
        return;
      }

      // ✅ Upload signature to Supabase Storage
      final uploadedUrl = await _uploadSignatureToSupabase(_signatureImage!);
      if (uploadedUrl == null) {
        context.showSnackBar('Failed to upload signature!', isError: true);
        setState(() => _isSubmitting = false);
        return;
      }
      _uploadedSignatureUrl = uploadedUrl;

      final data = {
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
        'injured_person': _injuredPersonController.text.trim(),
        'reporting_employee': _reportingEmployeeController.text.trim(),
        'location': _locationController.text.trim(),
        'description': _descriptionController.text.trim(),
        'severity': _selectedSeverity,
        'status': _selectedStatus,
        'emp_id': empId, // ✅ Employee ID from session (matches bigint in table)
        'signature_url': _uploadedSignatureUrl, // ✅ Signature URL from storage
      };

      // ✅ Insert into Supabase
      // Note: Supabase insert() throws exceptions on error, doesn't return error object
      await supabase.from('injury_reports').insert(data);

      // ✅ Email notification
      final emailSent = await EmailService.sendInjuryReport(
        date: DateFormat('yyyy-MM-dd').format(_selectedDate!),
        injuredPerson: _injuredPersonController.text.trim(),
        reportingEmployee: _reportingEmployeeController.text.trim(),
        location: _locationController.text.trim(),
        description: _descriptionController.text.trim(),
        severity: _selectedSeverity!,
        status: _selectedStatus!,
        signatureImage: _signatureImage, // ✅ Attach signature image in email
      );

      if (emailSent) {
        context.showSnackBar(
            '✅ Injury report submitted & email sent to supervisor');
      } else {
        context.showSnackBar('⚠️ Report saved but failed to send email');
      }

      _resetForm();
    } catch (e) {
      context.showSnackBar('❌ Failed to submit report: $e', isError: true);
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
    _signatureController.clear();
    setState(() {
      _selectedDate = null;
      _selectedSeverity = null;
      _selectedStatus = null;
      _signatureImage = null;
      _uploadedSignatureUrl = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Injury Report Form',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEAF3FF), Color(0xFFFFFFFF)],
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
                      _buildDatePicker(context),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _injuredPersonController,
                        label: 'Injured Person',
                        validatorMsg: 'Please enter the injured person',
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _reportingEmployeeController,
                        label: 'Reporting Employee',
                        validatorMsg: 'Please enter the reporting employee',
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _locationController,
                        label: 'Location',
                        validatorMsg: 'Please enter the location',
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _descriptionController,
                        label: 'Description',
                        validatorMsg: 'Please enter a description',
                        maxLines: 4,
                      ),
                      const SizedBox(height: 16),
                      _buildDropdown(
                        label: 'Severity',
                        value: _selectedSeverity,
                        options: _severityOptions,
                        onChanged: (value) =>
                            setState(() => _selectedSeverity = value),
                      ),
                      const SizedBox(height: 16),
                      _buildDropdown(
                        label: 'Status',
                        value: _selectedStatus,
                        options: _statusOptions,
                        onChanged: (value) =>
                            setState(() => _selectedStatus = value),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Employee Signature',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Signature(
                              controller: _signatureController,
                              height: 150,
                              backgroundColor: Colors.grey.shade100,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                TextButton.icon(
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Clear'),
                                  onPressed: () => _signatureController.clear(),
                                ),
                                TextButton.icon(
                                  icon: const Icon(Icons.save_alt),
                                  label: const Text('Save'),
                                  onPressed: () async {
                                    final signature = await _signatureController.toPngBytes();
                                    if (signature != null) {
                                      setState(() => _signatureImage = signature);
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
                      if (_signatureImage != null) ...[
                        const SizedBox(height: 10),
                        const Text('Preview:'),
                        Image.memory(_signatureImage!, height: 100),
                      ],
                      const SizedBox(height: 24),
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
                              : const Text('Submit Report',
                                  style: TextStyle(fontSize: 16)),
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

  Widget _buildDatePicker(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _selectDate(context),
          child: InputDecorator(
            decoration: InputDecoration(
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: const Icon(Icons.calendar_today),
            ),
            child: Text(
              _selectedDate == null
                  ? 'Select Date'
                  : DateFormat('yyyy-MM-dd').format(_selectedDate!),
            ),
          ),
        ),
      ],
    );
  }

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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return validatorMsg;
        return null;
      },
    );
  }

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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: options
          .map((option) => DropdownMenuItem(value: option, child: Text(option)))
          .toList(),
      onChanged: onChanged,
      validator: (value) =>
          value == null ? 'Please select $label'.toLowerCase() : null,
    );
  }
}
