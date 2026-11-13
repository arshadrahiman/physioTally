import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoizo/core/constants/physio_presets.dart';
import 'package:invoizo/core/theme/app_theme.dart';
import 'package:invoizo/modules/auth/controller/auth_controller.dart';
import 'package:invoizo/modules/billform/controller/bill_controller.dart';
import 'package:invoizo/modules/billform/services/pdf_invoice_service.dart';
import 'package:invoizo/modules/history/controller/history_controller.dart';
import 'package:invoizo/modules/history/model/invoice_record.dart';
import 'package:invoizo/modules/subscription/controller/subscription_controller.dart';
import 'package:invoizo/modules/subscription/view/subscription_screen.dart';
import 'package:invoizo/modules/subscription/view/widgets/paywall_sheet.dart';

class PhysioBillForm extends ConsumerStatefulWidget {
  const PhysioBillForm({super.key});

  @override
  ConsumerState<PhysioBillForm> createState() => _PhysioBillFormState();
}

class _PhysioBillFormState extends ConsumerState<PhysioBillForm> {
  final _formKey = GlobalKey<FormState>();

  // Patient Info Controllers
  final _receiptDateController = TextEditingController();
  final _patientNameController = TextEditingController();
  final _patientMobileController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _treatmentPlanController = TextEditingController();
  final _notesController = TextEditingController();

  // Add Treatment Item Controllers
  final _treatmentNameController = TextEditingController();
  final _fromDateController = TextEditingController();
  final _toDateController = TextEditingController();
  final _amountController = TextEditingController();

  // Payment Particulars
  String _paymentStatus = 'Paid';
  String _paymentMode = 'UPI (GooglePay / PhonePe / Paytm)';

  @override
  void initState() {
    super.initState();
    final today = _formatDate(DateTime.now());
    _receiptDateController.text = today;
    _fromDateController.text = today;
    _toDateController.text = today;
  }

  @override
  void dispose() {
    _receiptDateController.dispose();
    _patientNameController.dispose();
    _patientMobileController.dispose();
    _diagnosisController.dispose();
    _treatmentPlanController.dispose();
    _notesController.dispose();
    _treatmentNameController.dispose();
    _fromDateController.dispose();
    _toDateController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        controller.text = _formatDate(picked);
      });
    }
  }

  void _addTreatmentItem() {
    final treatment = _treatmentNameController.text.trim();
    final fromDate = _fromDateController.text.trim();
    final toDate = _toDateController.text.trim();
    final amount = _amountController.text.trim();

    if (treatment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or enter treatment procedure')),
      );
      return;
    }

    if (amount.isEmpty || double.tryParse(amount) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    final dateStr = fromDate == toDate ? fromDate : '$fromDate to $toDate';

    ref.read(billControllerProvider.notifier).addTreatment({
      'treatment': treatment,
      'date': dateStr,
      'amount': amount,
    });

    _treatmentNameController.clear();
    _amountController.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _generatePdfAndShare() async {
    final therapist = ref.read(authControllerProvider).therapist;
    final billState = ref.read(billControllerProvider);
    final subState = ref.read(subscriptionControllerProvider);

    if (therapist == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Therapist credentials missing. Please update profile.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill mandatory patient details')),
      );
      return;
    }

    if (billState.treatmentItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one treatment / procedure')),
      );
      return;
    }

    // Check Subscription Quota
    if (!subState.canGenerateInvoice) {
      PaywallSheet.show(
        context,
        title: 'Free Limit Reached (5/5 Used)',
        message:
            'You have used your 5 free receipts. Upgrade to Physio Pro for unlimited patient billing, custom clinic logo, and zero watermarks.',
      );
      return;
    }

    ref.read(billControllerProvider.notifier).setLoading(true);

    try {
      final invoiceId = DateTime.now().millisecondsSinceEpoch.toString();
      final totalAmount = billState.totalAmount;

      final File pdfFile = await PdfInvoiceService.generatePhysioInvoicePdf(
        therapist: therapist,
        invoiceId: invoiceId,
        patientName: _patientNameController.text.trim(),
        patientPhone: _patientMobileController.text.trim(),
        diagnosis: _diagnosisController.text.trim(),
        treatmentPlan: _treatmentPlanController.text.trim(),
        notes: _notesController.text.trim(),
        treatmentItems: billState.treatmentItems,
        totalAmount: totalAmount,
        paymentMode: _paymentMode,
        paymentStatus: _paymentStatus,
        isPro: subState.isPro,
        receiptDate: _receiptDateController.text.trim(),
      );

      // Save to local invoice history
      final record = InvoiceRecord(
        id: invoiceId,
        patientName: _patientNameController.text.trim(),
        patientPhone: _patientMobileController.text.trim(),
        diagnosis: _diagnosisController.text.trim(),
        treatmentPlan: _treatmentPlanController.text.trim(),
        notes: _notesController.text.trim(),
        treatmentItems: List.from(billState.treatmentItems),
        totalAmount: totalAmount,
        paymentMode: _paymentMode,
        paymentStatus: _paymentStatus,
        createdAt: DateTime.now(),
        pdfFilePath: pdfFile.path,
      );

      await ref.read(historyControllerProvider.notifier).addInvoice(record);
      await ref.read(subscriptionControllerProvider.notifier).incrementUsage();

      // Share PDF
      await PdfInvoiceService.sharePdf(
        pdfFile,
        patientName: _patientNameController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.successGreen,
            content: Text('✅ Receipt generated, archived, and ready to share!'),
          ),
        );
        _clearForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating receipt: $e')),
        );
      }
    } finally {
      if (mounted) {
        ref.read(billControllerProvider.notifier).setLoading(false);
      }
    }
  }

  void _clearForm() {
    _patientNameController.clear();
    _patientMobileController.clear();
    _diagnosisController.clear();
    _treatmentPlanController.clear();
    _notesController.clear();
    _treatmentNameController.clear();
    _amountController.clear();
    ref.read(billControllerProvider.notifier).clearTreatments();
    _formKey.currentState?.reset();
  }

  @override
  Widget build(BuildContext context) {
    final billState = ref.watch(billControllerProvider);
    final subState = ref.watch(subscriptionControllerProvider);
    final therapist = ref.watch(authControllerProvider).therapist;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Generate Physio Receipt'),
            if (therapist != null)
              Text(
                therapist.clinicName.isNotEmpty
                    ? '${therapist.clinicName} • ${therapist.name}'
                    : therapist.name,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white60 : Colors.grey.shade700,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Subscription Status Quota Banner
                  _buildQuotaBanner(subState, isDark),
                  const SizedBox(height: 14),

                  // Patient & Diagnosis Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person_outline, color: AppTheme.primaryTeal),
                              const SizedBox(width: 8),
                              const Text(
                                'Client / Patient Information',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          InkWell(
                            onTap: () => _pickDate(_receiptDateController),
                            child: IgnorePointer(
                              child: TextFormField(
                                controller: _receiptDateController,
                                decoration: const InputDecoration(
                                  labelText: 'Receipt Date *',
                                  hintText: 'DD-MM-YYYY',
                                  suffixIcon: Icon(Icons.calendar_month, size: 20),
                                  prefixIcon: Icon(Icons.event_note_outlined),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _patientNameController,
                            decoration: const InputDecoration(
                              labelText: 'Client / Patient Full Name *',
                              hintText: 'e.g. MOHANAN PONNETH',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Patient name is required' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _patientMobileController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Contact / Mobile Number *',
                              hintText: 'e.g. +91 98765 43210',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Mobile number is required'
                                : null,
                          ),
                          const SizedBox(height: 16),

                          // Clinical Diagnosis
                          TextFormField(
                            controller: _diagnosisController,
                            decoration: const InputDecoration(
                              labelText: 'Clinical Diagnosis *',
                              hintText: 'e.g. Cervical Spondylosis / Low Back Pain',
                              prefixIcon: Icon(Icons.medical_services_outlined),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Clinical diagnosis is required'
                                : null,
                          ),
                          const SizedBox(height: 8),

                          // Quick Diagnosis Chips
                          const Text(
                            'Quick Physio Diagnoses:',
                            style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: PhysioPresets.commonDiagnoses.take(6).map((diag) {
                              return ActionChip(
                                label: Text(diag, style: const TextStyle(fontSize: 11)),
                                backgroundColor: isDark ? AppTheme.darkSurface : Colors.grey.shade100,
                                onPressed: () {
                                  setState(() {
                                    _diagnosisController.text = diag;
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 14),

                          // Treatment Plan
                          TextFormField(
                            controller: _treatmentPlanController,
                            decoration: const InputDecoration(
                              labelText: 'Prescribed Treatment Plan *',
                              hintText: 'e.g. Manual Therapy + IFT + Home Exercises',
                              prefixIcon: Icon(Icons.assignment_outlined),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Treatment plan is required'
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Treatment & Session Items Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.fitness_center_outlined, color: AppTheme.primaryTeal),
                              const SizedBox(width: 8),
                              const Text(
                                'Treatments & Modalities',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Treatment procedure
                          TextFormField(
                            controller: _treatmentNameController,
                            decoration: const InputDecoration(
                              labelText: 'Procedure / Modality Name',
                              hintText: 'e.g. Manual Therapy & Joint Mobilization',
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Quick Modality Chips
                          const Text(
                            'Common Modalities:',
                            style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: PhysioPresets.commonTreatments.take(6).map((treat) {
                              return ActionChip(
                                label: Text(treat, style: const TextStyle(fontSize: 11)),
                                backgroundColor: isDark ? AppTheme.darkSurface : Colors.grey.shade100,
                                onPressed: () {
                                  setState(() {
                                    _treatmentNameController.text = treat;
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 14),

                          // Date Selectors
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => _pickDate(_fromDateController),
                                  child: IgnorePointer(
                                    child: TextFormField(
                                      controller: _fromDateController,
                                      decoration: const InputDecoration(
                                        labelText: 'From Date',
                                        suffixIcon: Icon(Icons.calendar_month, size: 18),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: InkWell(
                                  onTap: () => _pickDate(_toDateController),
                                  child: IgnorePointer(
                                    child: TextFormField(
                                      controller: _toDateController,
                                      decoration: const InputDecoration(
                                        labelText: 'To Date',
                                        suffixIcon: Icon(Icons.calendar_month, size: 18),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Amount field
                          TextFormField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Amount (₹)',
                              hintText: 'e.g. 500',
                              prefixText: '₹ ',
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Add button
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _addTreatmentItem,
                              icon: const Icon(Icons.add),
                              label: const Text('Add Procedure to Receipt'),
                            ),
                          ),

                          // Added Items List
                          if (billState.treatmentItems.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            const Divider(),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Added Procedures (${billState.treatmentItems.length})',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Total: ₹${billState.totalAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryTeal,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ...List.generate(billState.treatmentItems.length, (index) {
                              final item = billState.treatmentItems[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.darkSurface : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['treatment'] ?? '',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                          Text(
                                            'Period: ${item['date']}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '₹${item['amount']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppTheme.primaryTeal,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                      onPressed: () {
                                        ref
                                            .read(billControllerProvider.notifier)
                                            .removeTreatment(index);
                                      },
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Payment & Clinical Notes
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.payments_outlined, color: AppTheme.primaryTeal),
                              const SizedBox(width: 8),
                              const Text(
                                'Payment & Clinical Notes',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Payment Status
                          Row(
                            children: [
                              const Text('Payment Status:', style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(width: 14),
                              ChoiceChip(
                                label: const Text('Paid'),
                                selected: _paymentStatus == 'Paid',
                                onSelected: (sel) {
                                  if (sel) setState(() => _paymentStatus = 'Paid');
                                },
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('Pending'),
                                selected: _paymentStatus == 'Pending',
                                onSelected: (sel) {
                                  if (sel) setState(() => _paymentStatus = 'Pending');
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Payment Mode
                          DropdownButtonFormField<String>(
                            initialValue: _paymentMode,
                            decoration: const InputDecoration(labelText: 'Payment Mode'),
                            items: PhysioPresets.paymentModes.map((mode) {
                              return DropdownMenuItem(value: mode, child: Text(mode));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _paymentMode = val);
                            },
                          ),
                          const SizedBox(height: 14),

                          // Clinical Advice / Notes
                          TextFormField(
                            controller: _notesController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Clinical Notes / Exercise Advice (Optional)',
                              hintText: 'e.g. Apply hot pack twice daily, avoid deep squats',
                              prefixIcon: Icon(Icons.note_alt_outlined),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Grand Total & Generate Action
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkCardBg : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Grand Total Amount:',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '₹${billState.totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryTeal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: billState.isLoading ? null : _generatePdfAndShare,
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            label: const Text(
                              'Generate & Share Physio Receipt',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),

          if (billState.isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Generating Medical Receipt...',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuotaBanner(dynamic subState, bool isDark) {
    if (subState.isPro) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.primaryTeal.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified, color: AppTheme.primaryTeal, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Physio Pro Active • Unlimited Bills & Receipts',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    final remaining = subState.remainingFreeInvoices;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.accentAmber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentAmber.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppTheme.accentAmber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Free Plan: $remaining of ${subState.freeQuota} free receipts remaining',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Upgrade',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
