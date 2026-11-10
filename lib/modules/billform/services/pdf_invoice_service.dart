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
  }) async {
    final font = await loadFont();
    final pdf = pw.Document();

    pw.MemoryImage? logoImage;
    if (therapist.logoPath != null && therapist.logoPath!.isNotEmpty) {
      final logoFile = File(therapist.logoPath!);
      if (await logoFile.exists()) {
        try {
          logoImage = pw.MemoryImage(await logoFile.readAsBytes());
        } catch (_) {}
      }
    }

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

    final formattedDate =
        '${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // Professional Free Trial Watermark (Only shown for free trial users)
              if (!isPro)
                pw.Positioned.fill(
                  child: pw.Center(
                    child: pw.Transform.rotate(
                      angle: -0.55,
                      child: pw.Opacity(
                        opacity: 0.065,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 14,
                          ),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(
                              color: PdfColors.blueGrey800,
                              width: 2.5,
                            ),
                            borderRadius: pw.BorderRadius.circular(8),
                          ),
                          child: pw.Column(
                            mainAxisSize: pw.MainAxisSize.min,
                            children: [
                              pw.Text(
                                'PHYSIOTALLY',
                                style: pw.TextStyle(
                                  fontSize: 40,
                                  fontWeight: pw.FontWeight.bold,
                                  font: font,
                                  letterSpacing: 4.0,
                                  color: PdfColors.blueGrey900,
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                'FREE TRIAL VERSION',
                                style: pw.TextStyle(
                                  fontSize: 15,
                                  fontWeight: pw.FontWeight.bold,
                                  font: font,
                                  letterSpacing: 2.5,
                                  color: PdfColors.blueGrey900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Main Receipt Content
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Top Header: Clinic / Practitioner info
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      // Logo or Medical Crest
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          if (logoImage != null)
                            pw.Container(
                              height: 64,
                              width: 130,
                              margin: const pw.EdgeInsets.only(bottom: 8),
                              child: pw.Image(
                                logoImage,
                                fit: pw.BoxFit.contain,
                              ),
                            )
                          else
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.teal,
                                borderRadius: pw.BorderRadius.circular(6),
                              ),
                              child: pw.Text(
                                'PHYSIOTHERAPY CLINIC & HOME CARE',
                                style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  font: font,
                                ),
                              ),
                            ),
                          pw.SizedBox(height: 6),
                          pw.Text(
                            therapist.clinicName.isNotEmpty
                                ? therapist.clinicName
                                : 'Physiotherapy & Rehabilitation Care',
                            style: pw.TextStyle(
                              fontSize: 15,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.teal900,
                              font: font,
                            ),
                          ),
                          pw.Text(
                            therapist.practiceType,
                            style: pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700,
                              font: font,
                            ),
                          ),
                        ],
                      ),

                      // Practitioner details
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            therapist.name,
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              font: font,
                              color: PdfColors.teal800,
                            ),
                          ),
                          pw.Text(
                            therapist.qualification,
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              font: font,
                              color: PdfColors.grey800,
                            ),
                          ),
                          if (therapist.registrationNumber.isNotEmpty)
                            pw.Text(
                              'Reg No: ${therapist.registrationNumber}',
                              style: pw.TextStyle(fontSize: 10, font: font),
                            ),
                          pw.Text(
                            'Phone: ${therapist.phone}',
                            style: pw.TextStyle(fontSize: 10, font: font),
                          ),
                          if (therapist.email.isNotEmpty)
                            pw.Text(
                              'Email: ${therapist.email}',
                              style: pw.TextStyle(fontSize: 10, font: font),
                            ),
                          if (therapist.address != null &&
                              therapist.address!.isNotEmpty)
                            pw.Container(
                              width: 180,
                              child: pw.Text(
                                therapist.address!,
                                textAlign: pw.TextAlign.right,
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  color: PdfColors.grey700,
                                  font: font,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 12),
                  pw.Divider(color: PdfColors.teal, thickness: 1.5),
                  pw.SizedBox(height: 8),

                  // Title Bar & Meta
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'PHYSIOTHERAPY TREATMENT RECEIPT',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.teal800,
                          font: font,
                        ),
                      ),
                      pw.Text(
                        'Date: $formattedDate   |   Receipt #: ${invoiceId.substring(invoiceId.length > 8 ? invoiceId.length - 8 : 0)}',
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey700,
                          font: font,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 12),

                  // Patient Card
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.RichText(
                                text: pw.TextSpan(
                                  children: [
                                    pw.TextSpan(
                                      text: 'Patient Name: ',
                                      style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold,
                                        font: font,
                                        fontSize: 11,
                                      ),
                                    ),
                                    pw.TextSpan(
                                      text: patientName,
                                      style: pw.TextStyle(
                                        font: font,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              pw.RichText(
                                text: pw.TextSpan(
                                  children: [
                                    pw.TextSpan(
                                      text: 'Contact / Mobile: ',
                                      style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold,
                                        font: font,
                                        fontSize: 10,
                                      ),
                                    ),
                                    pw.TextSpan(
                                      text: patientPhone.isNotEmpty
                                          ? patientPhone
                                          : 'N/A',
                                      style: pw.TextStyle(
                                        font: font,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.RichText(
                                text: pw.TextSpan(
                                  children: [
                                    pw.TextSpan(
                                      text: 'Clinical Diagnosis: ',
                                      style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold,
                                        font: font,
                                        fontSize: 10,
                                      ),
                                    ),
                                    pw.TextSpan(
                                      text: diagnosis,
                                      style: pw.TextStyle(
                                        font: font,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (treatmentPlan.isNotEmpty) ...[
                                pw.SizedBox(height: 4),
                                pw.RichText(
                                  text: pw.TextSpan(
                                    children: [
                                      pw.TextSpan(
                                        text: 'Treatment Plan: ',
                                        style: pw.TextStyle(
                                          fontWeight: pw.FontWeight.bold,
                                          font: font,
                                          fontSize: 10,
                                        ),
                                      ),
                                      pw.TextSpan(
                                        text: treatmentPlan,
                                        style: pw.TextStyle(
                                          font: font,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 16),

                  // Treatment Itemized Table
                  pw.TableHelper.fromTextArray(
                    headers: [
                      '#',
                      'Therapy / Modality / Procedure',
                      'Period / Sessions',
                      'Amount (₹)',
                    ],
                    data: List.generate(treatmentItems.length, (i) {
                      final item = treatmentItems[i];
                      return [
                        '${i + 1}',
                        item['treatment'] ?? '',
                        item['date'] ?? '',
                        '₹${item['amount'] ?? '0'}',
                      ];
                    }),
                    headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                      font: font,
                      fontSize: 10,
                    ),
                    headerDecoration: const pw.BoxDecoration(
                      color: PdfColors.teal,
                    ),
                    cellStyle: pw.TextStyle(font: font, fontSize: 9.5),
                    cellAlignment: pw.Alignment.centerLeft,
                    cellAlignments: {
                      0: pw.Alignment.center,
                      3: pw.Alignment.centerRight,
                    },
                    columnWidths: {
                      0: const pw.FixedColumnWidth(28),
                      1: const pw.FlexColumnWidth(5),
                      2: const pw.FlexColumnWidth(3),
                      3: const pw.FlexColumnWidth(2.2),
                    },
                  ),

                  pw.SizedBox(height: 14),

                  // Total & Payment Summary Row
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Payment Mode & UPI
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            children: [
                              pw.Text(
                                'Payment Status: ',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 10,
                                  font: font,
                                ),
                              ),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: pw.BoxDecoration(
                                  color: paymentStatus == 'Paid'
                                      ? PdfColors.green100
                                      : PdfColors.amber100,
                                  borderRadius: pw.BorderRadius.circular(4),
                                  border: pw.Border.all(
                                    color: paymentStatus == 'Paid'
                                        ? PdfColors.green700
                                        : PdfColors.amber800,
                                  ),
                                ),
                                child: pw.Text(
                                  paymentStatus.toUpperCase(),
                                  style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold,
                                    font: font,
                                    color: paymentStatus == 'Paid'
                                        ? PdfColors.green800
                                        : PdfColors.amber900,
                                  ),
                                ),
                              ),
                              pw.SizedBox(width: 8),
                              pw.Text(
                                'via $paymentMode',
                                style: pw.TextStyle(fontSize: 10, font: font),
                              ),
                            ],
                          ),
                          if (therapist.upiId != null &&
                              therapist.upiId!.isNotEmpty) ...[
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'UPI ID: ${therapist.upiId}',
                              style: pw.TextStyle(
                                fontSize: 9,
                                color: PdfColors.teal900,
                                fontWeight: pw.FontWeight.bold,
                                font: font,
                              ),
                            ),
                          ],
                        ],
                      ),

                      // Grand Total
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.teal50,
                          borderRadius: pw.BorderRadius.circular(6),
                          border: pw.Border.all(color: PdfColors.teal),
                        ),
                        child: pw.Row(
                          children: [
                            pw.Text(
                              'TOTAL AMOUNT: ',
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.teal900,
                                font: font,
                              ),
                            ),
                            pw.Text(
                              '₹${totalAmount.toStringAsFixed(2)}',
                              style: pw.TextStyle(
                                fontSize: 15,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.teal900,
                                font: font,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Clinical Notes
                  if (notes.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 16),
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey50,
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(color: PdfColors.grey300),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Therapist Clinical Notes / Advice:',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9.5,
                              font: font,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            notes.trim(),
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey800,
                              font: font,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  pw.Spacer(),

                  // Bottom Signature & Disclaimer
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Thank you for trusting us with your recovery and wellness.',
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              fontStyle: pw.FontStyle.italic,
                              color: PdfColors.grey600,
                              font: font,
                            ),
                          ),
                          pw.Text(
                            'This receipt is valid for tax / medical reimbursement purposes.',
                            style: pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.grey500,
                              font: font,
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          if (signatureImage != null)
                            pw.Container(
                              height: 38,
                              width: 100,
                              child: pw.Image(
                                signatureImage,
                                fit: pw.BoxFit.contain,
                              ),
                            )
                          else
                            pw.Container(
                              width: 140,
                              decoration: const pw.BoxDecoration(
                                border: pw.Border(
                                  bottom: pw.BorderSide(
                                    color: PdfColors.grey400,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: pw.SizedBox(height: 28),
                            ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            therapist.name,
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              font: font,
                            ),
                          ),
                          pw.Text(
                            'Authorized Physiotherapist',
                            style: pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.grey600,
                              font: font,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Free tier footer note (Only shown for free trial users)
                  if (!isPro) ...[
                    pw.SizedBox(height: 10),
                    pw.Center(
                      child: pw.Text(
                        'Generated using PhysioTally Free Trial • Upgrade to Physio Pro to remove trial watermark',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontStyle: pw.FontStyle.italic,
                          color: PdfColors.grey600,
                          font: font,
                        ),
                      ),
                    ),
                  ],
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
