class Employee {
  final int empId;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String? designation;
  final String? address;
  final String? status;
  final String? skills;
  final String? qualifications;
  final String? imageUrl;

  Employee({
    required this.empId,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.designation,
    this.address,
    this.status,
    this.skills,
    this.qualifications,
    this.imageUrl,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      empId: json['emp_id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      email: json['email'],
      phone: json['phone'],
      designation: json['designation'],
      address: json['address'],
      status: json['status'],
      skills: json['skills'],
      qualifications: json['qualifications'],
      imageUrl: json['image_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'emp_id': empId,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'designation': designation,
      'address': address,
      'status': status,
      'skills': skills,
      'qualifications': qualifications,
      'image_url': imageUrl,
    };
  }

  String get fullName => '$firstName $lastName';
}
