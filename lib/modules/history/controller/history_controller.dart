import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoizo/modules/history/model/invoice_record.dart';
import 'package:invoizo/modules/history/repository/invoice_repository.dart';

final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  return InvoiceRepository();
});

final historyControllerProvider =
    NotifierProvider<HistoryController, List<InvoiceRecord>>(() {
  return HistoryController();
});

class HistoryController extends Notifier<List<InvoiceRecord>> {
  @override
  List<InvoiceRecord> build() {
    final repo = ref.watch(invoiceRepositoryProvider);
    return repo.getAllInvoices();
  }

  void refresh() {
    final repo = ref.read(invoiceRepositoryProvider);
    state = repo.getAllInvoices();
  }

  Future<void> addInvoice(InvoiceRecord record) async {
    final repo = ref.read(invoiceRepositoryProvider);
    await repo.saveInvoice(record);
    refresh();
  }

  Future<void> togglePaymentStatus(String id) async {
    final repo = ref.read(invoiceRepositoryProvider);
    final invoice = state.firstWhere((i) => i.id == id);
    final newStatus = invoice.paymentStatus == 'Paid' ? 'Pending' : 'Paid';
    await repo.updatePaymentStatus(id, newStatus);
    refresh();
  }

  Future<void> deleteInvoice(String id) async {
    final repo = ref.read(invoiceRepositoryProvider);
    await repo.deleteInvoice(id);
    refresh();
  }

  double get totalRevenue =>
      state.fold(0.0, (sum, i) => sum + i.totalAmount);

  double get totalCollected => state
      .where((i) => i.paymentStatus == 'Paid')
      .fold(0.0, (sum, i) => sum + i.totalAmount);

  double get totalPending => state
      .where((i) => i.paymentStatus == 'Pending')
      .fold(0.0, (sum, i) => sum + i.totalAmount);
}
