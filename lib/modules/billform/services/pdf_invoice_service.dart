import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:invoizo/modules/login/model/user_model.dart';
import 'package:share_plus/share_plus.dart';

class PdfInvoiceService {
  static pw.Font? _cachedFont;

  static Future<pw.Font> loadFont() async {
    if (_cachedFont != null) return _cachedFont!;
    try {
      final fontData = await rootBundle.load(
        'assets/fonts/NotoSans-Regular.ttf',
      );
      _cachedFont = pw.Font.ttf(fontData);
      return _cachedFont!;
    } catch (_) {
      return pw.Font.helvetica();
    }
  }

  static pw.Widget _buildMetaRow(String label, String value, pw.Font font) {
    return pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$label: ',
            style: pw.TextStyle(
              font: font,
              fontWeight: pw.FontWeight.bold,
              fontSize: 10.5,
              color: PdfColors.black,
            ),
          ),
          pw.TextSpan(
            text: value,
            style: pw.TextStyle(
              font: font,
              fontSize: 10.5,
              color: PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  static Future<File> generatePhysioInvoicePdf({
    required Therapist therapist,
    required String invoiceId,
    required String patientName,
    required String patientPhone,
    required String diagnosis,
    required String treatmentPlan,
    required String notes,
    required List<Map<String, String>> treatmentItems,
    required double totalAmount,
    required String paymentMode,
    required String paymentStatus,
    required bool isPro,
    String? receiptDate,
  }) async {
    final font = await loadFont();
    final pdf = pw.Document();

    // 1. Resolve Logo: custom uploaded file > base64 from cloud profile > app default icon
    pw.MemoryImage? logoImage;
    if (therapist.logoPath != null && therapist.logoPath!.isNotEmpty) {
      final logoFile = File(therapist.logoPath!);
      if (await logoFile.exists()) {
        try {
          logoImage = pw.MemoryImage(await logoFile.readAsBytes());
        } catch (_) {}
      }
    }
    if (logoImage == null &&
        therapist.logoBase64 != null &&
        therapist.logoBase64!.isNotEmpty) {
      try {
        logoImage = pw.MemoryImage(base64Decode(therapist.logoBase64!));
      } catch (_) {}
    }
    if (logoImage == null) {
      try {
        final byteData = await rootBundle.load('assets/icons/icon.png');
        logoImage = pw.MemoryImage(byteData.buffer.asUint8List());
      } catch (_) {}
    }

    // 2. Resolve Signature
    pw.MemoryImage? signatureImage;
    if (therapist.signaturePath != null &&
        therapist.signaturePath!.isNotEmpty) {
      final sigFile = File(therapist.signaturePath!);
      if (await sigFile.exists()) {
        try {
          signatureImage = pw.MemoryImage(await sigFile.readAsBytes());
        } catch (_) {}
      }
    }
    if (signatureImage == null &&
        therapist.signatureBase64 != null &&
        therapist.signatureBase64!.isNotEmpty) {
      try {
        signatureImage =
            pw.MemoryImage(base64Decode(therapist.signatureBase64!));
      } catch (_) {}
    }

    final now = DateTime.now();
    final formattedDate = receiptDate ??
        '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';

    // Doctor name formatted
    final docName = therapist.name.trim().isNotEmpty
        ? (therapist.name.trim().startsWith('Dr')
            ? therapist.name.trim()
            : 'Dr. ${therapist.name.trim()}')
        : 'Dr. Practitioner (PT)';

    // Teal Theme Color matching template
    final tealColor = PdfColor.fromHex('#008080');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // Free trial subtle watermark
              if (!isPro)
                pw.Positioned.fill(
                  child: pw.Center(
                    child: pw.Transform.rotate(
                      angle: -0.5,
                      child: pw.Opacity(
                        opacity: 0.05,
                        child: pw.Text(
                          'PHYSIOTALLY FREE TRIAL',
                          style: pw.TextStyle(
                            fontSize: 42,
                            fontWeight: pw.FontWeight.bold,
                            font: font,
                            color: PdfColors.blueGrey800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Main Receipt Document Content
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header Row: Logo on Left, Doctor info on Right
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      // Editable Practice / Doctor Logo (Left)
                      if (logoImage != null)
                        pw.Container(
                          height: 58,
                          width: 58,
                          child: pw.ClipOval(
                            child: pw.Image(
                              logoImage,
                              fit: pw.BoxFit.contain,
                            ),
                          ),
                        )
                      else
                        pw.SizedBox(height: 58, width: 58),

                      // Doctor / Practitioner Details (Right)
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            docName,
                            style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              font: font,
                              color: PdfColors.black,
                            ),
                          ),
                          if (therapist.qualification.trim().isNotEmpty) ...[
                            pw.SizedBox(height: 2),
                            pw.Text(
                              therapist.qualification.trim(),
                              style: pw.TextStyle(
                                fontSize: 10,
                                font: font,
                                color: PdfColors.black,
                              ),
                            ),
                          ],
                          if (therapist.registrationNumber.trim().isNotEmpty) ...[
                            pw.SizedBox(height: 2),
                            pw.Text(
                              therapist.registrationNumber
                                      .trim()
                                      .toLowerCase()
                                      .startsWith('reg')
                                  ? therapist.registrationNumber.trim()
                                  : 'Reg No: ${therapist.registrationNumber.trim()}',
                              style: pw.TextStyle(
                                fontSize: 10,
                                font: font,
                                color: PdfColors.black,
                              ),
                            ),
                          ],
                          if (therapist.phone.trim().isNotEmpty) ...[
                            pw.SizedBox(height: 2),
                            pw.Text(
                              therapist.phone.trim().toLowerCase().startsWith('phone')
                                  ? therapist.phone.trim()
                                  : 'Phone: ${therapist.phone.trim()}',
                              style: pw.TextStyle(
                                fontSize: 10,
                                font: font,
                                color: PdfColors.black,
                              ),
                            ),
                          ],
                          if (therapist.email.trim().isNotEmpty) ...[
                            pw.SizedBox(height: 2),
                            pw.Text(
                              therapist.email.trim().toLowerCase().startsWith('email')
                                  ? therapist.email.trim()
                                  : 'Email: ${therapist.email.trim()}',
                              style: pw.TextStyle(
                                fontSize: 10,
                                font: font,
                                color: PdfColors.black,
                              ),
                            ),
                          ],
                          if (therapist.workHours.trim().isNotEmpty) ...[
                            pw.SizedBox(height: 2),
                            pw.Text(
                              therapist.workHours
                                      .trim()
                                      .toLowerCase()
                                      .startsWith('work')
                                  ? therapist.workHours.trim()
                                  : 'Work Hours: ${therapist.workHours.trim()}',
                              style: pw.TextStyle(
                                fontSize: 10,
                                font: font,
                                color: PdfColors.black,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 8),

                  // Teal horizontal divider line across the page
                  pw.Divider(
                    color: tealColor,
                    thickness: 1.5,
                  ),

                  pw.SizedBox(height: 12),

                  // Receipt Title (Centered)
                  pw.Center(
                    child: pw.Text(
                      'PHYSIOTHERAPY RECEIPT',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.2,
                        color: tealColor,
                        font: font,
                      ),
                    ),
                  ),

                  pw.SizedBox(height: 16),

                  // Patient / Client Information Section
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildMetaRow('Date', formattedDate, font),
                      pw.SizedBox(height: 3),
                      _buildMetaRow(
                        'Client Name',
                        patientName.trim().toUpperCase(),
                        font,
                      ),
                      pw.SizedBox(height: 3),
                      _buildMetaRow(
                        'Mobile',
                        patientPhone.trim().isNotEmpty
                            ? patientPhone.trim()
                            : 'N/A',
                        font,
                      ),
                      pw.SizedBox(height: 3),
                      _buildMetaRow(
                        'Diagnosis',
                        diagnosis.trim().toUpperCase(),
                        font,
                      ),
                      if (treatmentPlan.trim().isNotEmpty) ...[
                        pw.SizedBox(height: 3),
                        _buildMetaRow(
                          'Treatment Plan',
                          treatmentPlan.trim(),
                          font,
                        ),
                      ],
                    ],
                  ),

                  pw.SizedBox(height: 16),

                  // Treatments Table (Treatment | Period | Amount (₹))
                  pw.Table(
                    border: pw.TableBorder.all(
                      color: PdfColors.black,
                      width: 0.8,
                    ),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(5.0),
                      1: const pw.FlexColumnWidth(2.6),
                      2: const pw.FlexColumnWidth(2.4),
                    },
                    children: [
                      // Header Row
                      pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color: tealColor,
                        ),
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 8,
                            ),
                            alignment: pw.Alignment.center,
                            child: pw.Text(
                              'Treatment',
                              style: pw.TextStyle(
                                font: font,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10.5,
                                color: PdfColors.white,
                              ),
                            ),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 8,
                            ),
                            alignment: pw.Alignment.center,
                            child: pw.Text(
                              'Period',
                              style: pw.TextStyle(
                                font: font,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10.5,
                                color: PdfColors.white,
                              ),
                            ),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 8,
                            ),
                            alignment: pw.Alignment.center,
                            child: pw.Text(
                              'Amount (₹)',
                              style: pw.TextStyle(
                                font: font,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10.5,
                                color: PdfColors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Data Rows
                      ...treatmentItems.map((item) {
                        final treatmentText = item['treatment'] ?? '';
                        final periodText = item['date'] ?? '';
                        final amountVal = item['amount'] ?? '0';

                        return pw.TableRow(
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 8,
                              ),
                              alignment: pw.Alignment.topLeft,
                              child: pw.Text(
                                treatmentText,
                                style: pw.TextStyle(
                                  font: font,
                                  fontSize: 10,
                                  color: PdfColors.black,
                                ),
                              ),
                            ),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 8,
                              ),
                              alignment: pw.Alignment.center,
                              child: pw.Text(
                                periodText,
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(
                                  font: font,
                                  fontSize: 10,
                                  color: PdfColors.black,
                                ),
                              ),
                            ),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 8,
                              ),
                              alignment: pw.Alignment.centerLeft,
                              child: pw.Text(
                                amountVal,
                                style: pw.TextStyle(
                                  font: font,
                                  fontSize: 10,
                                  color: PdfColors.black,
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),

                  pw.SizedBox(height: 10),

                  // Total (Right Aligned)
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      'Total: ₹${totalAmount.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        font: font,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 13.5,
                        color: PdfColors.black,
                      ),
                    ),
                  ),

                  // Optional Notes
                  if (notes.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 14),
                    pw.Text(
                      'Notes: ${notes.trim()}',
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],

                  pw.SizedBox(height: 36),

                  // Signature Section (Left Aligned)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Signature of Physiotherapist:',
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 10.5,
                          color: PdfColors.black,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      if (signatureImage != null)
                        pw.Container(
                          height: 38,
                          width: 140,
                          margin: const pw.EdgeInsets.only(bottom: 4),
                          child: pw.Image(
                            signatureImage,
                            fit: pw.BoxFit.contain,
                          ),
                        )
                      else
                        pw.SizedBox(height: 28),
                      pw.Container(
                        width: 180,
                        height: 0.8,
                        color: PdfColors.black,
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        docName,
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 10.5,
                          color: PdfColors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    final outputDir = await getTemporaryDirectory();
    final sanitizedPatientName = patientName
        .trim()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(' ', '_');
    final file = File(
      '${outputDir.path}/PhysioReceipt_${sanitizedPatientName}_$invoiceId.pdf',
    );
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static Future<void> sharePdf(File file, {required String patientName}) async {
    final xFile = XFile(file.path);
    await SharePlus.instance.share(
      ShareParams(files: [xFile], text: 'Physiotherapy Receipt - $patientName'),
    );
  }
}
