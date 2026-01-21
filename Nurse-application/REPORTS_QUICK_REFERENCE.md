# Quick Reference: Unified Reporting System

## Report Type Selection → Database Table Mapping

| Report Type (UI)              | Supabase Table              |
|-------------------------------|----------------------------|
| Hazard / Near Miss            | hazard_near_miss_reports   |
| Incident Report               | incident_reports           |
| Employee Injury / Illness     | injury_reports             |

## Required Fields by Report Type

### 1. Hazard / Near Miss Report

**Required**:
- Incident Date
- Incident Time
- Incident Location
- Hazard Rating (SERIOUS | MINOR_NEAR_MISS)
- Hazard Types (at least one)
- Hazard Statement
- Immediate Action

**Optional**:
- Documented on Hazard Board (checkbox, defaults to false)

**Auto-populated**:
- emp_id (from session)

### 2. Incident Report

**Required**:
- Incident Date
- Incident Time
- Incident Location
- Incident Description
- Sequence of Events
- Immediate Actions
- Client Condition

**Optional**:
- Medical Attention Required (checkbox, defaults to false)

**Auto-populated**:
- emp_id (from session)

### 3. Employee Injury / Illness Report

**Required**:
- Injury Date
- Injury Description
- Signature

**Optional**:
- Injury Time
- Program
- Injured Body Parts
- Medical Attention Required (checkbox, defaults to false)

**Auto-populated**:
- emp_id (from session)

## Code Structure

```
lib/
├── pages/
│   ├── unified_reports_form.dart       # Main entry point
│   └── dashboard_page.dart             # Updated navigation
├── widgets/
│   ├── hazard_near_miss_form.dart      # Hazard form widget
│   ├── incident_report_form_widget.dart # Incident form widget
│   └── employee_injury_form.dart       # Injury form widget
└── services/
    └── email_service.dart              # Extended with 3 new methods
```

## Email Methods

```dart
// Hazard Report
EmailService.sendHazardReportEmail(...)

// Incident Report
EmailService.sendIncidentReportEmail(...)

// Injury Report
EmailService.sendInjuryReportEmail(...)
```

## Common Patterns

### Getting Employee ID
```dart
final empId = await SessionManager.getEmpId();
if (empId == null) {
  // Handle not logged in
  return;
}
```

### Supabase Insert
```dart
await supabase.from('table_name').insert(data);
```

### Email Notification
```dart
final emailSent = await EmailService.sendXxxReportEmail(...);
if (emailSent) {
  context.showSnackBar('✅ Report submitted & email sent');
} else {
  context.showSnackBar('⚠️ Report saved but failed to send email');
}
```

### Form Reset
```dart
void _resetForm() {
  _formKey.currentState!.reset();
  // Clear all controllers
  // Reset all state variables
}
```

## Body Parts Available (Injury Report)

- Head
- Neck
- Shoulder (Left/Right)
- Arm (Left/Right)
- Hand (Left/Right)
- Chest
- Back
- Abdomen
- Leg (Left/Right)
- Knee (Left/Right)
- Foot (Left/Right)

## Hazard Types Available

- Slip/Trip/Fall
- Chemical Exposure
- Sharp Objects
- Equipment Malfunction
- Fire Hazard
- Electrical
- Biohazard
- Other

## Important Notes

1. **Never insert status field** - DB defaults handle this
2. **Never use auth.uid()** - Always use emp_id from SessionManager
3. **Email failure is non-critical** - Report is saved even if email fails
4. **Signature is required** for injury reports
5. **All forms validate before submission**
6. **All forms show loading state during submission**
7. **All forms reset after successful submission**

## Testing Quick Commands

```bash
# Analyze code
flutter analyze

# Run on emulator/device
flutter run

# Clean build
flutter clean
flutter pub get
flutter run
```

## Troubleshooting

**Issue**: "emp_id is null"
- Solution: User needs to log in again

**Issue**: "Signature upload failed"
- Solution: Check Supabase storage bucket 'injury_signatures' exists and is accessible

**Issue**: "Email not received"
- Solution: Check email credentials in email_service.dart, verify recipient email

**Issue**: "Database insert failed"
- Solution: Verify table exists and fields match exactly

**Issue**: "Form doesn't show after selecting type"
- Solution: Check that widget is imported correctly in unified_reports_form.dart
