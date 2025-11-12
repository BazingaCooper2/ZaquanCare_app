class Client {
  final int clientId;
  final String firstName;
  final String? lastName;
  final String? phone;
  final String? email;
  final String? serviceType;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? preferredLanguage;
  final String? notes;
  final String? risks;
  final String? clientCoordinatorName;
  final String? imageUrl;
  final String? accountingDetails;
  final String? shiftStartTime;
  final String? shiftEndTime;
  final String name;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? province;
  final String? zipCode;
  final String password;
  final String? patientLocation;

  Client({
    required this.clientId,
    required this.firstName,
    this.lastName,
    this.phone,
    this.email,
    this.serviceType,
    this.dateOfBirth,
    this.gender,
    this.preferredLanguage,
    this.notes,
    this.risks,
    this.clientCoordinatorName,
    this.imageUrl,
    this.accountingDetails,
    this.shiftStartTime,
    this.shiftEndTime,
    required this.name,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.province,
    this.zipCode,
    required this.password,
    this.patientLocation,
  });

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      clientId: json['client_id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      phone: json['phone'],
      email: json['email'],
      serviceType: json['service_type'],
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.parse(json['date_of_birth'])
          : null,
      gender: json['gender'],
      preferredLanguage: json['preferred_language'],
      notes: json['notes'],
      risks: json['risks'],
      clientCoordinatorName: json['client_coordinator_name'],
      imageUrl: json['image_url'],
      accountingDetails: json['accounting_details'],
      shiftStartTime: json['shift_start_time'],
      shiftEndTime: json['shift_end_time'],
      name: json['name'],
      addressLine1: json['address_line1'],
      addressLine2: json['address_line2'],
      city: json['city'],
      province: json['province'],
      zipCode: json['zip_code'],
      password: json['password'],
      patientLocation: json['patient_location'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'client_id': clientId,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'email': email,
      'service_type': serviceType,
      'date_of_birth': dateOfBirth?.toIso8601String(),
      'gender': gender,
      'preferred_language': preferredLanguage,
      'notes': notes,
      'risks': risks,
      'client_coordinator_name': clientCoordinatorName,
      'image_url': imageUrl,
      'accounting_details': accountingDetails,
      'shift_start_time': shiftStartTime,
      'shift_end_time': shiftEndTime,
      'name': name,
      'address_line1': addressLine1,
      'address_line2': addressLine2,
      'city': city,
      'province': province,
      'zip_code': zipCode,
      'password': password,
      'patient_location': patientLocation,
    };
  }

  String get fullName => '$firstName ${lastName ?? ''}'.trim();

  // Helper method to parse patient location to LatLng coordinates
  // Format: "latitude,longitude" (e.g., "43.538165,-80.311467")
  List<double>? get locationCoordinates {
    if (patientLocation == null || patientLocation!.isEmpty) return null;
    
    try {
      final parts = patientLocation!.split(',');
      if (parts.length == 2) {
        return [
          double.parse(parts[0].trim()),
          double.parse(parts[1].trim()),
        ];
      }
    } catch (e) {
      print('Error parsing patient_location: $e');
    }
    return null;
  }

  String get fullAddress {
    final parts = <String>[];
    if (addressLine1?.isNotEmpty == true) parts.add(addressLine1!);
    if (addressLine2?.isNotEmpty == true) parts.add(addressLine2!);
    if (city?.isNotEmpty == true) parts.add(city!);
    if (province?.isNotEmpty == true) parts.add(province!);
    if (zipCode?.isNotEmpty == true) parts.add(zipCode!);
    return parts.isNotEmpty ? parts.join(', ') : name;
  }
}

