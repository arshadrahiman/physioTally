class Therapist {
  final String? id;
  final String name;
  final String qualification;
  final String registrationNumber;
  final String clinicName;
  final String practiceType;
  final String phone;
  final String email;
  final String? upiId;
  final String workHours;
  final String? logoPath;
  final String? signaturePath;
  final String? logoBase64;
  final String? signatureBase64;
  final String? address;

  Therapist({
    this.id,
    required this.name,
    required this.qualification,
    required this.registrationNumber,
    this.clinicName = '',
    this.practiceType = 'Freelance / Home Visit Physiotherapist',
    required this.phone,
    required this.email,
    this.upiId = '',
    required this.workHours,
    this.logoPath,
    this.signaturePath,
    this.logoBase64,
    this.signatureBase64,
    this.address,
  });

  Therapist copyWith({
    String? id,
    String? name,
    String? qualification,
    String? registrationNumber,
    String? clinicName,
    String? practiceType,
    String? phone,
    String? email,
    String? upiId,
    String? workHours,
    String? logoPath,
    String? signaturePath,
    String? logoBase64,
    String? signatureBase64,
    String? address,
  }) {
    return Therapist(
      id: id ?? this.id,
      name: name ?? this.name,
      qualification: qualification ?? this.qualification,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      clinicName: clinicName ?? this.clinicName,
      practiceType: practiceType ?? this.practiceType,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      upiId: upiId ?? this.upiId,
      workHours: workHours ?? this.workHours,
      logoPath: logoPath ?? this.logoPath,
      signaturePath: signaturePath ?? this.signaturePath,
      logoBase64: logoBase64 ?? this.logoBase64,
      signatureBase64: signatureBase64 ?? this.signatureBase64,
      address: address ?? this.address,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'qualification': qualification,
      'registrationNumber': registrationNumber,
      'clinicName': clinicName,
      'practiceType': practiceType,
      'phone': phone,
      'email': email,
      'upiId': upiId,
      'workHours': workHours,
      'logoPath': logoPath,
      'signaturePath': signaturePath,
      'logoBase64': logoBase64,
      'signatureBase64': signatureBase64,
      'address': address,
    };
  }

  factory Therapist.fromMap(Map<String, dynamic> map) {
    return Therapist(
      id: map['id']?.toString(),
      name: map['name'] ?? '',
      qualification: map['qualification'] ?? '',
      registrationNumber: map['registrationNumber'] ?? '',
      clinicName: map['clinicName'] ?? '',
      practiceType: map['practiceType'] ?? 'Freelance / Home Visit Physiotherapist',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      upiId: map['upiId'] ?? '',
      workHours: map['workHours'] ?? '',
      logoPath: map['logoPath'] ?? '',
      signaturePath: map['signaturePath'] ?? '',
      logoBase64: map['logoBase64'] ?? map['logo_base64'],
      signatureBase64: map['signatureBase64'] ?? map['signature_base64'],
      address: map['address'] ?? '',
    );
  }
}

