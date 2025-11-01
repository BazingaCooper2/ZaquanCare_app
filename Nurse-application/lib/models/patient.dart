class Patient {
  final String id;
  final String patientId;
  final String firstName;
  final String lastName;
  final String address;
  final String? phone;
  final String? emergencyContact;
  final String? emergencyPhone;
  final String? medicalNotes;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final DateTime updatedAt;
  

  Patient({
    required this.id,
    required this.patientId,
    required this.firstName,
    required this.lastName,
    required this.address,
    this.phone,
    this.emergencyContact,
    this.emergencyPhone,
    this.medicalNotes,
    this.latitude,
    this.longitude,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'],
      patientId: json['patient_id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      address: json['address'],
      phone: json['phone'],
      emergencyContact: json['emergency_contact'],
      emergencyPhone: json['emergency_phone'],
      medicalNotes: json['medical_notes'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  String get fullName => '$firstName $lastName';
}
