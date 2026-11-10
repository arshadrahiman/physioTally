import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:invoizo/modules/history/model/invoice_record.dart';

class InvoiceRepository {
  static const boxName = 'invoicesBox';
  late final Box _box;

  Future<void> init() async {
    _box = await Hive.openBox(boxName);
  }

  List<InvoiceRecord> getAllInvoices() {
    try {
      final records = <InvoiceRecord>[];
      for (final key in _box.keys) {
        final val = _box.get(key);
        if (val != null) {
          records.add(InvoiceRecord.fromMap(Map<String, dynamic>.from(val as Map)));
        }
      }
      records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return records;
    } catch (e) {
      debugPrint('Error getting invoices: $e');
      return [];
    }
  }

  Future<void> saveInvoice(InvoiceRecord invoice) async {
    try {
      await _box.put(invoice.id, invoice.toMap());
    } catch (e) {
      debugPrint('Error saving invoice: $e');
      throw Exception('Failed to save invoice record');
    }
  }

  Future<void> updatePaymentStatus(String id, String newStatus) async {
    try {
      final val = _box.get(id);
      if (val != null) {
        final record = InvoiceRecord.fromMap(Map<String, dynamic>.from(val as Map));
        final updated = record.copyWith(paymentStatus: newStatus);
        await _box.put(id, updated.toMap());
      }
    } catch (e) {
      debugPrint('Error updating invoice: $e');
    }
  }

  Future<void> deleteInvoice(String id) async {
    try {
      await _box.delete(id);
    } catch (e) {
      debugPrint('Error deleting invoice: $e');
    }
  }
}
