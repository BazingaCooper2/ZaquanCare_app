import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import 'package:signature/signature.dart';
import '../main.dart';
import '../services/session.dart';
import '../services/email_service.dart';

class EmployeeInjuryForm extends StatefulWidget {
  const EmployeeInjuryForm({super.key});

  @override
  State<EmployeeInjuryForm> createState() => _EmployeeInjuryFormState();
}

class _EmployeeInjuryFormState extends State<EmployeeInjuryForm> {
  final _formKey = GlobalKey<FormState>();

  // PART 1: REPORT COMPLETED BY
  final _supervisorReportedToController = TextEditingController();
  final _reasonForDelayController = TextEditingController();
  DateTime? _dateReported;

  // PART 2: PERSONAL DATA
  final _employeeNameController =
      TextEditingController(); // Manual override or auto-filled
  final _employeePhoneController = TextEditingController();
  final _employeeEmailController = TextEditingController();
  final _employeeAddressController = TextEditingController();
  bool _returnToWorkPackageTaken = false;

  // PART 3: INJURY DETAILS
  DateTime? _injuryDate;
  TimeOfDay? _injuryTime;
  TimeOfDay? _timeLeftWork;
  final _programController = TextEditingController();
  final _locationController = TextEditingController();
  final _clientInvolvedController = TextEditingController(); // Name and phone

  // PART 4: BODY PARTS (Checkbox state)
  final Map<String, bool> _bodyParts = {
    'Head': false,
    'Teeth': false,
    'Upper Back': false,
    'Lower Back': false,
    'Shoulder': false,
    'Wrist': false,
    'Hip': false,
    'Ankle': false,
    'Face': false,
    'Neck': false,
    'Fingers': false,
    'Eye': false,
    'Chest': false,
    'Abdomen': false,
    'Elbow': false,
    'Ears': false,
    'Pelvis': false,
    'Forearm': false,
    'Lower Legs': false,
    'Other': false
  };
  final _otherBodyPartController = TextEditingController();

  // PART 5: INJURY DETAILS DESCRIPTION
  final _descriptionController =
      TextEditingController(); // "Describe what happened..."

  // PART 6: WITNESS REMARKS
  final _witnessNameController = TextEditingController();
  final _witnessPhoneController = TextEditingController();

  // PART 7: HCP DETAILS (If medical attention required)
  bool _medicalAttentionRequired = false;
  final _hcpNameController = TextEditingController();
  final _hcpAddressController = TextEditingController();
  final _hcpPhoneController = TextEditingController();
  bool _broughtFafForm = false;

  // Signature
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  Uint8List? _signatureImage;
  String? _uploadedSignatureUrl;

  bool _isSubmitting = false;

  @override
  void dispose() {
    _supervisorReportedToController.dispose();
    _reasonForDelayController.dispose();
    _employeeNameController.dispose();
    _employeePhoneController.dispose();
    _employeeEmailController.dispose();
    _employeeAddressController.dispose();
    _programController.dispose();
    _locationController.dispose();
    _clientInvolvedController.dispose();
    _otherBodyPartController.dispose();
    _descriptionController.dispose();
    _witnessNameController.dispose();
    _witnessPhoneController.dispose();
    _hcpNameController.dispose();
    _hcpAddressController.dispose();
    _hcpPhoneController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isReported) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (!mounted) return;
    if (picked != null) {
      setState(() {
        if (isReported) {
          _dateReported = picked;
        } else {
          _injuryDate = picked;
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isLeftWork) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (!mounted) return;
    if (picked != null) {
      setState(() {
        if (isLeftWork) {
          _timeLeftWork = picked;
        } else {
          _injuryTime = picked;
        }
      });
    }
  }

  Future<String?> _uploadSignatureToSupabase(Uint8List signatureBytes) async {
    try {
      final supabase = Supabase.instance.client;
      final fileName =
          'injury_sig_${DateTime.now().millisecondsSinceEpoch}.png';
      await supabase.storage
          .from('injury_signatures')
          .uploadBinary(fileName, signatureBytes);
      return supabase.storage.from('injury_signatures').getPublicUrl(fileName);
    } catch (e) {
      debugPrint('Error uploading signature: $e');
      return null;
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_injuryDate == null) {
      context.showSnackBar('Please select injury date', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final empId = await SessionManager.getEmpId();
      if (empId == null) {
        if (mounted) {
          context.showSnackBar('You must be logged in.', isError: true);
        }
        setState(() => _isSubmitting = false);
        return;
      }

      if (_signatureImage != null) {
        _uploadedSignatureUrl =
            await _uploadSignatureToSupabase(_signatureImage!);
      }

      // Concatenate full description
      final fullDescription = '''
DESCRIPTION: ${_descriptionController.text.trim()}

--- REPORT DETAILS (PART 1) ---
Reported To: ${_supervisorReportedToController.text.trim()}
Date Reported: ${_dateReported != null ? DateFormat('yyyy-MM-dd').format(_dateReported!) : 'N/A'}
Reason for Delay: ${_reasonForDelayController.text.trim()}

--- PERSONAL DATA (PART 2) ---
Name: ${_employeeNameController.text.trim()}
Phone: ${_employeePhoneController.text.trim()}
Email: ${_employeeEmailController.text.trim()}
Address: ${_employeeAddressController.text.trim()}
RTW Package Taken: $_returnToWorkPackageTaken

--- INJURY DETAILS (PART 3) ---
Time Left Work: ${_timeLeftWork != null ? (mounted ? _timeLeftWork!.format(context) : 'N/A') : 'N/A'}
Location: ${_locationController.text.trim()}
Client Involved: ${_clientInvolvedController.text.trim()}
Other Body Parts: ${_otherBodyPartController.text.trim()}

--- WITNESS (PART 6) ---
Name: ${_witnessNameController.text.trim()}
Phone: ${_witnessPhoneController.text.trim()}

--- HCP DETAILS (PART 7) ---
HCP Name/Title: ${_hcpNameController.text.trim()}
Address: ${_hcpAddressController.text.trim()}
Phone: ${_hcpPhoneController.text.trim()}
Brought FAF Form: $_broughtFafForm

--- SIGNATURE ---
URL: ${_uploadedSignatureUrl ?? 'Not Signed'}
''';

      final bodyPartsList =
          _bodyParts.entries.where((e) => e.value).map((e) => e.key).toList();
      final bodyPartsMap = {for (var e in bodyPartsList) e: true};

      final data = {
        'emp_id': empId,
        'injury_date': DateFormat('yyyy-MM-dd').format(_injuryDate!),
        'injury_time': _injuryTime != null
            ? '${_injuryTime!.hour.toString().padLeft(2, '0')}:${_injuryTime!.minute.toString().padLeft(2, '0')}:00'
            : null,
        'program': _programController.text.trim(),
        'injury_description': fullDescription,
        'injured_body_parts': bodyPartsMap,
        'medical_attention_required': _medicalAttentionRequired,
        'signature_url': _uploadedSignatureUrl,
      };

      await supabase.from('injury_reports').insert(data);

      final emailSent = await EmailService.sendInjuryReportEmail(
        injuryDate: DateFormat('yyyy-MM-dd').format(_injuryDate!),
        injuryTime: _injuryTime != null
            ? (mounted ? _injuryTime!.format(context) : 'N/A')
            : 'N/A',
        program: _programController.text.trim(),
        description: _descriptionController.text.trim(),
        bodyParts: bodyPartsList,
        medicalAttentionRequired: _medicalAttentionRequired,
        signatureImage: _signatureImage,
        // Detailed fields
        supervisorReportedTo: _supervisorReportedToController.text.trim(),
        dateReported: _dateReported != null
            ? DateFormat('yyyy-MM-dd').format(_dateReported!)
            : 'N/A',
        employeeName: _employeeNameController.text.trim(),
        employeePhone: _employeePhoneController.text.trim(),
        timeLeftWork: _timeLeftWork != null
            ? (mounted ? _timeLeftWork!.format(context) : 'N/A')
            : 'N/A',
        location: _locationController.text.trim(),
        clientInvolved: _clientInvolvedController.text.trim(),
        witnessName: _witnessNameController.text.trim(),
        hcpDetails: _medicalAttentionRequired
            ? "Name: ${_hcpNameController.text}\nAddress: ${_hcpAddressController.text}\nPhone: ${_hcpPhoneController.text}"
            : "N/A",
      );

      if (mounted) {
        if (emailSent) {
          context.showSnackBar('✅ Report submitted & email sent');
        } else {
          context.showSnackBar('⚠️ Saved but email failed');
        }
      }
      _resetForm();
    } catch (e) {
      if (mounted) context.showSnackBar('❌ Error: $e', isError: true);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _resetForm() {
    _formKey.currentState!.reset();
    _supervisorReportedToController.clear();
    _reasonForDelayController.clear();
    _employeeNameController.clear();
    _employeePhoneController.clear();
    _employeeEmailController.clear();
    _employeeAddressController.clear();
    _programController.clear();
    _locationController.clear();
    _clientInvolvedController.clear();
    _otherBodyPartController.clear();
    _descriptionController.clear();
    _witnessNameController.clear();
    _witnessPhoneController.clear();
    _hcpNameController.clear();
    _hcpAddressController.clear();
    _hcpPhoneController.clear();
    _signatureController.clear();
    setState(() {
      _injuryDate = null;
      _injuryTime = null;
      _dateReported = null;
      _timeLeftWork = null;
      _returnToWorkPackageTaken = false;
      _medicalAttentionRequired = false;
      _broughtFafForm = false;
      _signatureImage = null;
      _uploadedSignatureUrl = null;
      _bodyParts.updateAll((key, value) => false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.amber.shade50,
            child: const Column(
              children: [
                Text(
                    'IMMEDIATELY contact and speak to your supervisor/designate.',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.brown)),
                Text('Use Emergency Notification System if necessary.',
                    style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionHeader('PART 1: REPORT COMPLETED BY'),
          _buildTextField(
              controller: _supervisorReportedToController,
              label: 'Illness/Injury Reported To (Name)',
              icon: Icons.person),
          const SizedBox(height: 12),
          _buildDateTimePicker(context, 'Date Reported', true, true),
          const SizedBox(height: 12),
          _buildTextField(
              controller: _reasonForDelayController,
              label: 'Reason for delay (if not immediate)',
              required: false),
          const SizedBox(height: 24),
          _buildSectionHeader('PART 2: PERSONAL DATA'),
          _buildTextField(
              controller: _employeeNameController,
              label: 'Name',
              required: false),
          const SizedBox(height: 12),
          _buildTextField(
              controller: _employeePhoneController,
              label: 'Telephone Number',
              icon: Icons.phone),
          const SizedBox(height: 12),
          _buildTextField(
              controller: _employeeAddressController,
              label: 'Address',
              icon: Icons.home),
          const SizedBox(height: 12),
          CheckboxListTile(
            title: const Text('Medical attention required?'),
            value: _medicalAttentionRequired,
            onChanged: (v) =>
                setState(() => _medicalAttentionRequired = v ?? false),
          ),
          if (_medicalAttentionRequired)
            CheckboxListTile(
              title:
                  const Text('Was a Return To Work package taken to the HCP?'),
              value: _returnToWorkPackageTaken,
              onChanged: (v) =>
                  setState(() => _returnToWorkPackageTaken = v ?? false),
            ),
          const SizedBox(height: 24),
          _buildSectionHeader('PART 3: INJURY DETAILS'),
          Row(
            children: [
              Expanded(
                  child: _buildDateTimePicker(
                      context, 'Date of Injury', true, false)),
              const SizedBox(width: 16),
              Expanded(
                  child: _buildDateTimePicker(context, 'Time', false, false)),
            ],
          ),
          const SizedBox(height: 12),
          _buildTimePicker(context, 'Time Left Work', true),
          const SizedBox(height: 12),
          _buildTextField(
              controller: _programController,
              label: 'Program',
              required: false),
          const SizedBox(height: 12),
          _buildTextField(
              controller: _locationController,
              label: 'Location (address where injury occurred)'),
          const SizedBox(height: 12),
          _buildTextField(
              controller: _clientInvolvedController,
              label: 'Client Involved (Name & Phone)',
              required: false),
          const SizedBox(height: 24),
          _buildSectionHeader('PART 4: AREA OF INJURY (BODY PART)'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8)),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              children: _bodyParts.keys.map((key) {
                return SizedBox(
                  width: 140, // Fixed width for columns look
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _bodyParts[key],
                        onChanged: (v) =>
                            setState(() => _bodyParts[key] = v ?? false),
                        visualDensity: VisualDensity.compact,
                      ),
                      Text(key, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          if (_bodyParts['Other'] == true)
            _buildTextField(
                controller: _otherBodyPartController,
                label: 'Specify Other Body Part'),
          const SizedBox(height: 24),
          _buildSectionHeader('PART 5: INJURY DETAILS'),
          _buildTextField(
              controller: _descriptionController,
              label:
                  'Describe what happened (lifting, slipped, etc.) & conditions',
              maxLines: 5),
          const SizedBox(height: 24),
          _buildSectionHeader('PART 6: WITNESS REMARKS'),
          _buildTextField(
              controller: _witnessNameController,
              label: 'Witness Name',
              required: false),
          const SizedBox(height: 12),
          _buildTextField(
              controller: _witnessPhoneController,
              label: 'Witness Phone',
              required: false),
          const SizedBox(height: 24),
          if (_medicalAttentionRequired) ...[
            _buildSectionHeader('PART 7: DETAILS OF ATTENDING HCP'),
            _buildTextField(
                controller: _hcpNameController, label: 'Name and Title of HCP'),
            const SizedBox(height: 12),
            _buildTextField(
                controller: _hcpAddressController, label: 'Address of HCP'),
            const SizedBox(height: 12),
            _buildTextField(
                controller: _hcpPhoneController, label: 'Phone Number of HCP'),
            const SizedBox(height: 12),
            CheckboxListTile(
              title: const Text('Did you bring an FAF form with you?'),
              value: _broughtFafForm,
              onChanged: (v) => setState(() => _broughtFafForm = v ?? false),
            ),
            const Text(
                'Please attach RETURN TO WORK INFORMATION to this document',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 24),
          ],
          const Text('I confirm data is true/complete/correct.',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Signature(
                    controller: _signatureController,
                    height: 120,
                    backgroundColor: Colors.grey.shade100),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                        onPressed: () => _signatureController.clear(),
                        child: const Text('Clear')),
                    TextButton(
                        onPressed: () async {
                          final data = await _signatureController.toPngBytes();
                          if (data != null) {
                            setState(() => _signatureImage = data);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Signature Saved')));
                            }
                          }
                        },
                        child: const Text('Save')),
                  ],
                ),
              ],
            ),
          ),
          if (_signatureImage != null)
            const Text('Signature Captured ✅',
                style: TextStyle(color: Colors.green)),
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
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Submit Report'),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      color: Colors.grey.shade700,
      child: Text(title,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildTextField(
      {required TextEditingController controller,
      required String label,
      bool required = true,
      int maxLines = 1,
      IconData? icon}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      validator:
          required ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
    );
  }

  Widget _buildDateTimePicker(
      BuildContext context, String label, bool isDate, bool isReported) {
    final val = isDate
        ? (isReported ? _dateReported : _injuryDate)
        : (isReported ? null : _injuryTime);
    // Simplified logic as we don't have time reported var in state, only Date Reported per form Image (Time of Injury is Part 1 in image? kind of, but Time of Injury is definitely Part 3. Part 1 has Date Reported. Image says Time of Injury in Part 1 too? Yes.)
    // Image Part 1: "Time of Injury". Data Reported (D/M/Y).
    // Image Part 3: "Time", "Time Left Work".
    // I will use _injuryTime for Part 3. I'll ignore Part 1 Time of Injury to avoid dupes or link it.

    // Formatting display
    String text = 'Select';
    if (val != null) {
      if (val is DateTime) text = DateFormat('yyyy-MM-dd').format(val);
      if (val is TimeOfDay) text = val.format(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => isDate
              ? _selectDate(context, isReported)
              : _selectTime(context, false), // Only injury time here
          child: InputDecorator(
            decoration: InputDecoration(
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                suffixIcon:
                    Icon(isDate ? Icons.calendar_today : Icons.access_time),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            child: Text(text),
          ),
        ),
      ],
    );
  }

  Widget _buildTimePicker(BuildContext context, String label, bool isLeftWork) {
    final val = isLeftWork ? _timeLeftWork : _injuryTime;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => _selectTime(context, isLeftWork),
          child: InputDecorator(
            decoration: InputDecoration(
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                suffixIcon: const Icon(Icons.access_time),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            child: Text(val?.format(context) ?? 'Select'),
          ),
        ),
      ],
    );
  }
}
