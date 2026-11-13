import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoizo/core/theme/app_theme.dart';
import 'package:invoizo/modules/auth/controller/auth_controller.dart';
import 'package:invoizo/modules/billform/services/pdf_invoice_service.dart';
import 'package:invoizo/modules/history/controller/history_controller.dart';
import 'package:invoizo/modules/history/model/invoice_record.dart';
import 'package:invoizo/modules/login/model/user_model.dart';
import 'package:invoizo/modules/subscription/controller/subscription_controller.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchController = TextEditingController();
  String _filter = 'All'; // 'All', 'Paid', 'Pending'
  String? _busyInvoiceId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Ensures a valid PDF file exists on disk, generating it on-the-fly if needed
  Future<File?> _getOrGeneratePdf(InvoiceRecord item) async {
    setState(() => _busyInvoiceId = item.id);
    try {
      if (item.pdfFilePath != null && item.pdfFilePath!.isNotEmpty) {
        final existing = File(item.pdfFilePath!);
        if (await existing.exists()) {
          return existing;
        }
      }

      // Recreate PDF on-the-fly from saved invoice details
      final therapist = ref.read(authControllerProvider).therapist;
      final subState = ref.read(subscriptionControllerProvider);

      final fallbackTherapist = therapist ??
          Therapist(
            name: 'Physiotherapist',
            qualification: '',
            registrationNumber: '',
            phone: '',
            email: '',
            workHours: '',
          );

      final dateStr =
          '${item.createdAt.day.toString().padLeft(2, '0')}-${item.createdAt.month.toString().padLeft(2, '0')}-${item.createdAt.year}';

      final generated = await PdfInvoiceService.generatePhysioInvoicePdf(
        therapist: fallbackTherapist,
        invoiceId: item.id,
        patientName: item.patientName,
        patientPhone: item.patientPhone,
        diagnosis: item.diagnosis,
        treatmentPlan: item.treatmentPlan,
        notes: item.notes,
        treatmentItems: item.treatmentItems,
        totalAmount: item.totalAmount,
        paymentMode: item.paymentMode,
        paymentStatus: item.paymentStatus,
        isPro: subState.isPro,
        receiptDate: dateStr,
      );

      final updated = item.copyWith(pdfFilePath: generated.path);
      await ref.read(invoiceRepositoryProvider).saveInvoice(updated);
      ref.read(historyControllerProvider.notifier).refresh();

      return generated;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error preparing receipt PDF: $e')),
        );
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => _busyInvoiceId = null);
      }
    }
  }

  Future<void> _handlePreview(InvoiceRecord item) async {
    final file = await _getOrGeneratePdf(item);
    if (file != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReceiptPreviewScreen(item: item, pdfFile: file),
        ),
      );
    }
  }

  Future<void> _handlePrint(InvoiceRecord item) async {
    final file = await _getOrGeneratePdf(item);
    if (file != null) {
      final bytes = await file.readAsBytes();
      await Printing.layoutPdf(
        onLayout: (_) => bytes,
        name: 'PhysioReceipt_${item.patientName}',
      );
    }
  }

  Future<void> _handleShare(InvoiceRecord item) async {
    final file = await _getOrGeneratePdf(item);
    if (file != null) {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Physiotherapy Receipt - ${item.patientName}',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoices = ref.watch(historyControllerProvider);
    final historyNotifier = ref.read(historyControllerProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final query = _searchController.text.trim().toLowerCase();
    final filtered = invoices.where((inv) {
      final matchesQuery = query.isEmpty ||
          inv.patientName.toLowerCase().contains(query) ||
          inv.diagnosis.toLowerCase().contains(query) ||
          inv.patientPhone.contains(query);

      if (!matchesQuery) return false;
      if (_filter == 'Paid') return inv.paymentStatus == 'Paid';
      if (_filter == 'Pending') return inv.paymentStatus == 'Pending';
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Receipts History'),
      ),
      body: Column(
        children: [
          // Revenue & Summary Dashboard
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryMetric(
                    'TOTAL BILLED',
                    '₹${historyNotifier.totalRevenue.toStringAsFixed(0)}',
                    AppTheme.primaryTeal,
                    isDark,
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
                Expanded(
                  child: _buildSummaryMetric(
                    'COLLECTED',
                    '₹${historyNotifier.totalCollected.toStringAsFixed(0)}',
                    AppTheme.successGreen,
                    isDark,
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
                Expanded(
                  child: _buildSummaryMetric(
                    'PENDING',
                    '₹${historyNotifier.totalPending.toStringAsFixed(0)}',
                    AppTheme.accentAmber,
                    isDark,
                  ),
                ),
              ],
            ),
          ),

          // Search & Filter
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search patient, diagnosis, mobile...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', invoices.length),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'Paid',
                        invoices.where((i) => i.paymentStatus == 'Paid').length,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'Pending',
                        invoices.where((i) => i.paymentStatus == 'Pending').length,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Invoices List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            invoices.isEmpty
                                ? 'No receipts generated yet'
                                : 'No matching receipts found',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            invoices.isEmpty
                                ? 'Generate patient receipts from the Generate tab. They will be archived here automatically.'
                                : 'Try searching with another name or clearing the filter.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return _buildInvoiceCard(item, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric(String title, String value, Color color, bool isDark) {
    return Column(
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white60 : Colors.grey.shade600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, int count) {
    final isSelected = _filter == label;
    return GestureDetector(
      onTap: () => setState(() => _filter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryTeal
              : (Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.darkCardBg
                  : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryTeal : Colors.transparent,
          ),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  String _getShortPaymentMode(String mode) {
    if (mode.startsWith('UPI')) return 'UPI';
    if (mode.startsWith('Bank')) return 'Bank';
    if (mode.startsWith('Card')) return 'Card';
    if (mode.startsWith('Insurance')) return 'Insurance';
    if (mode.startsWith('Cash')) return 'Cash';
    final trimmed = mode.trim();
    if (trimmed.length > 10) {
      return '${trimmed.substring(0, 8)}..';
    }
    return trimmed;
  }

  Widget _buildCardActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color color = AppTheme.primaryTeal,
  }) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(5),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      splashRadius: 18,
      icon: Icon(icon, size: 19, color: color),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }

  Widget _buildInvoiceCard(InvoiceRecord item, bool isDark) {
    final dateStr =
        '${item.createdAt.day.toString().padLeft(2, '0')}/${item.createdAt.month.toString().padLeft(2, '0')}/${item.createdAt.year}';
    final isPaid = item.paymentStatus == 'Paid';
    final isBusy = _busyInvoiceId == item.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _handlePreview(item),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Patient Info Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.primaryTeal.withValues(alpha: 0.12),
                    child: const Icon(Icons.person, color: AppTheme.primaryTeal),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.patientName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (item.patientPhone.isNotEmpty)
                          Text(
                            item.patientPhone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '₹${item.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryTeal,
                          ),
                        ),
                      ),
                      Text(
                        dateStr,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Diagnosis badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.medical_services_outlined, size: 14, color: AppTheme.primaryTeal),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.diagnosis.isNotEmpty ? item.diagnosis : 'General Physio Rehab',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${item.treatmentItems.length} item(s)',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Divider(height: 18, thickness: 0.6),

              // Action Toolbar: Payment status + Preview, Print, Share, Delete
              Row(
                children: [
                  // Payment Status chip (tap to toggle)
                  Flexible(
                    child: InkWell(
                      onTap: () {
                        ref.read(historyControllerProvider.notifier).togglePaymentStatus(item.id);
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPaid
                              ? AppTheme.successGreen.withValues(alpha: 0.15)
                              : AppTheme.accentAmber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isPaid ? AppTheme.successGreen : AppTheme.accentAmber,
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPaid ? Icons.check_circle : Icons.schedule,
                              size: 13,
                              color: isPaid ? AppTheme.successGreen : AppTheme.accentAmber,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '${item.paymentStatus} • ${_getShortPaymentMode(item.paymentMode)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isPaid ? AppTheme.successGreen : AppTheme.accentAmber,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 4),

                  if (isBusy)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else ...[
                    // 1. PREVIEW ICON
                    _buildCardActionButton(
                      icon: Icons.visibility_outlined,
                      tooltip: 'Preview Receipt',
                      color: AppTheme.primaryTeal,
                      onPressed: () => _handlePreview(item),
                    ),

                    // 2. PRINT ICON
                    _buildCardActionButton(
                      icon: Icons.print_outlined,
                      tooltip: 'Print Receipt',
                      color: AppTheme.primaryTeal,
                      onPressed: () => _handlePrint(item),
                    ),

                    // 3. SHARE ICON
                    _buildCardActionButton(
                      icon: Icons.share_outlined,
                      tooltip: 'Share Receipt',
                      color: AppTheme.primaryTeal,
                      onPressed: () => _handleShare(item),
                    ),
                  ],

                  // 4. DELETE ICON
                  _buildCardActionButton(
                    icon: Icons.delete_outline,
                    tooltip: 'Delete Receipt',
                    color: Colors.grey,
                    onPressed: () => _confirmDelete(item.id),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Receipt?'),
        content: const Text('Are you sure you want to remove this receipt from history?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(historyControllerProvider.notifier).deleteInvoice(id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

/// Dedicated Full-Screen Receipt Preview Screen
class ReceiptPreviewScreen extends StatelessWidget {
  final InvoiceRecord item;
  final File pdfFile;

  const ReceiptPreviewScreen({
    super.key,
    required this.item,
    required this.pdfFile,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${item.patientName} - Receipt'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
            onPressed: () async {
              await SharePlus.instance.share(
                ShareParams(
                  files: [XFile(pdfFile.path)],
                  text: 'Physiotherapy Receipt - ${item.patientName}',
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print',
            onPressed: () async {
              final bytes = await pdfFile.readAsBytes();
              await Printing.layoutPdf(
                onLayout: (_) => bytes,
                name: 'PhysioReceipt_${item.patientName}',
              );
            },
          ),
        ],
      ),
      body: PdfPreview(
        build: (_) => pdfFile.readAsBytes(),
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        actions: const [], // We have Print & Share in the AppBar
      ),
    );
  }
}
