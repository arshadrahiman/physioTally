import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoizo/modules/history/controller/history_controller.dart';
import 'package:invoizo/modules/history/model/invoice_record.dart';
import 'package:invoizo/modules/history/repository/invoice_repository.dart';
import 'package:invoizo/modules/history/view/history_screen.dart';

class FakeInvoiceRepository extends InvoiceRepository {
  final List<InvoiceRecord> mockInvoices;

  FakeInvoiceRepository(this.mockInvoices);

  @override
  List<InvoiceRecord> getAllInvoices() => mockInvoices;

  @override
  Future<void> updatePaymentStatus(String id, String newStatus) async {}

  @override
  Future<void> deleteInvoice(String id) async {}
}

void main() {
  testWidgets(
    'HistoryScreen renders without any RenderFlex overflow on narrow 320px viewport',
    (tester) async {
      FlutterErrorDetails? caughtDetails;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        caughtDetails = details;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);
      // Set a very narrow viewport (320px width - typical small phone or split view)
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final List<InvoiceRecord> mockData = [
        InvoiceRecord(
          id: 'test-inv-001',
          patientName: 'Prof. Christopher Montgomery-Wellington III',
          patientPhone: '+91 98765 43210',
          diagnosis:
              'Bilateral Cervical Radiculopathy & Post-Operative Shoulder Rehab',
          treatmentPlan: '10 sessions',
          totalAmount: 18500.0,
          createdAt: DateTime(2026, 10, 21),
          paymentStatus: 'Pending',
          paymentMode: 'UPI (GooglePay / PhonePe / Paytm)',
          treatmentItems: const [
            {
              'name': 'Dry Needling & Myofascial Release',
              'quantity': '3',
              'rate': '1200',
              'total': '3600',
            },
            {
              'name': 'Electrotherapy (TENS / IFT)',
              'quantity': '5',
              'rate': '800',
              'total': '4000',
            },
          ],
        ),
        InvoiceRecord(
          id: 'test-inv-002',
          patientName: 'Sarah Connor',
          patientPhone: '+91 91234 56789',
          diagnosis: 'Lumbar Spondylosis',
          treatmentPlan: '5 sessions',
          totalAmount: 2500.0,
          createdAt: DateTime(2026, 10, 20),
          paymentStatus: 'Paid',
          paymentMode: 'Bank Transfer / NEFT',
          treatmentItems: const [
            {
              'name': 'Lumbar Traction Therapy',
              'quantity': '2',
              'rate': '1250',
              'total': '2500',
            },
          ],
        ),
      ];

      final fakeRepo = FakeInvoiceRepository(mockData);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [invoiceRepositoryProvider.overrideWithValue(fakeRepo)],
          child: const MaterialApp(home: Scaffold(body: HistoryScreen())),
        ),
      );

      await tester.pumpAndSettle();

      // Verify patient names render
      expect(
        find.text('Prof. Christopher Montgomery-Wellington III'),
        findsOneWidget,
      );
      expect(find.text('Sarah Connor'), findsOneWidget);

      // Verify shortened payment mode badge text
      expect(find.text('Pending • UPI'), findsOneWidget);
      expect(find.text('Paid • Bank'), findsOneWidget);

      // Verify all 4 action icons are present for each card
      expect(find.byIcon(Icons.visibility_outlined), findsNWidgets(2));
      expect(find.byIcon(Icons.print_outlined), findsNWidgets(2));
      expect(find.byIcon(Icons.share_outlined), findsNWidgets(2));
      expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));

      expect(
        caughtDetails,
        isNull,
        reason: 'No RenderFlex overflow should occur',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
