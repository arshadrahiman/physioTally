class InvoiceRecord {
  final String id;
  final String patientName;
  final String patientPhone;
  final String diagnosis;
  final String treatmentPlan;
  final String notes;
  final List<Map<String, String>> treatmentItems;
  final double totalAmount;
  final String paymentMode;
  final String paymentStatus; // 'Paid', 'Pending'
  final DateTime createdAt;
  final String? pdfFilePath;

  InvoiceRecord({
    required this.id,
    required this.patientName,
    required this.patientPhone,
    required this.diagnosis,
    required this.treatmentPlan,
    this.notes = '',
    required this.treatmentItems,
    required this.totalAmount,
    this.paymentMode = 'Cash',
    this.paymentStatus = 'Paid',
    required this.createdAt,
    this.pdfFilePath,
  });

  InvoiceRecord copyWith({
    String? id,
    String? patientName,
    String? patientPhone,
    String? diagnosis,
    String? treatmentPlan,
    String? notes,
    List<Map<String, String>>? treatmentItems,
    double? totalAmount,
    String? paymentMode,
    String? paymentStatus,
    DateTime? createdAt,
    String? pdfFilePath,
  }) {
    return InvoiceRecord(
      id: id ?? this.id,
      patientName: patientName ?? this.patientName,
      patientPhone: patientPhone ?? this.patientPhone,
      diagnosis: diagnosis ?? this.diagnosis,
      treatmentPlan: treatmentPlan ?? this.treatmentPlan,
      notes: notes ?? this.notes,
      treatmentItems: treatmentItems ?? this.treatmentItems,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentMode: paymentMode ?? this.paymentMode,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      createdAt: createdAt ?? this.createdAt,
      pdfFilePath: pdfFilePath ?? this.pdfFilePath,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientName': patientName,
      'patientPhone': patientPhone,
      'diagnosis': diagnosis,
      'treatmentPlan': treatmentPlan,
      'notes': notes,
      'treatmentItems': treatmentItems,
      'totalAmount': totalAmount,
      'paymentMode': paymentMode,
      'paymentStatus': paymentStatus,
      'createdAt': createdAt.toIso8601String(),
      'pdfFilePath': pdfFilePath,
    };
  }

  factory InvoiceRecord.fromMap(Map<String, dynamic> map) {
    List<Map<String, String>> items = [];
    if (map['treatmentItems'] != null) {
      items = (map['treatmentItems'] as List).map((e) {
        return Map<String, String>.from(e as Map);
      }).toList();
    }

    return InvoiceRecord(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      patientName: map['patientName'] ?? '',
      patientPhone: map['patientPhone'] ?? '',
      diagnosis: map['diagnosis'] ?? '',
      treatmentPlan: map['treatmentPlan'] ?? '',
      notes: map['notes'] ?? '',
      treatmentItems: items,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paymentMode: map['paymentMode'] ?? 'Cash',
      paymentStatus: map['paymentStatus'] ?? 'Paid',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      pdfFilePath: map['pdfFilePath'],
    );
  }
}
