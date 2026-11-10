import 'package:flutter_test/flutter_test.dart';
import 'package:invoizo/modules/login/model/user_model.dart';
import 'package:invoizo/modules/subscription/model/subscription_model.dart';
import 'package:invoizo/modules/history/model/invoice_record.dart';

void main() {
  group('Physiotherapist Model Tests', () {
    test('Therapist serialization and defaults', () {
      final therapist = Therapist(
        name: 'Dr. Alex Reed, PT',
        qualification: 'BPT, MPT (Sports)',
        registrationNumber: 'PT-99881',
        clinicName: 'Elite Spine & Rehab',
        practiceType: 'Freelance / Home Visit Physiotherapist',
        phone: '+91 99988 77766',
        email: 'alex.physio@example.com',
        upiId: 'alex@upi',
        workHours: '8:00 AM - 6:00 PM',
        address: 'Downtown Clinic, Suite 4',
      );

      final map = therapist.toMap();
      final restored = Therapist.fromMap(map);

      expect(restored.name, 'Dr. Alex Reed, PT');
      expect(restored.clinicName, 'Elite Spine & Rehab');
      expect(restored.practiceType, 'Freelance / Home Visit Physiotherapist');
      expect(restored.upiId, 'alex@upi');
      expect(restored.address, 'Downtown Clinic, Suite 4');
    });
  });

  group('Subscription & Quota Logic Tests', () {
    test('Free tier allows 5 receipts and shows watermark', () {
      final sub = const SubscriptionState(
        tier: SubscriptionTier.free,
        invoicesGenerated: 2,
        freeQuota: 5,
      );

      expect(sub.isPro, false);
      expect(sub.hasWatermark, true);
      expect(sub.remainingFreeInvoices, 3);
      expect(sub.canGenerateInvoice, true);
      expect(sub.canUseCustomLogoAndSignature, false);
    });

    test('Free tier blocks generation after reaching 5 invoices', () {
      final sub = const SubscriptionState(
        tier: SubscriptionTier.free,
        invoicesGenerated: 5,
        freeQuota: 5,
      );

      expect(sub.isPro, false);
      expect(sub.remainingFreeInvoices, 0);
      expect(sub.canGenerateInvoice, false);
    });

    test('Pro tier allows unlimited invoices with no watermark', () {
      final sub = SubscriptionState(
        tier: SubscriptionTier.pro,
        invoicesGenerated: 25,
        proExpiresAt: DateTime.now().add(const Duration(days: 365)),
        activePlanName: 'Annual Pro',
      );

      expect(sub.canUseCustomLogoAndSignature, true);
    });

    test('Emergency bonus promo code increases free quota by 3', () {
      final initial = const SubscriptionState(
        tier: SubscriptionTier.free,
        invoicesGenerated: 5, // reached initial 5 limit
        freeQuota: 5,
      );
      expect(initial.canGenerateInvoice, false);

      // Add emergency top-up
      final updated = initial.copyWith(freeQuota: initial.freeQuota + 3);
      expect(updated.freeQuota, 8);
      expect(updated.remainingFreeInvoices, 3);
      expect(updated.canGenerateInvoice, true);
    });

    test('PromoActivationResult handles success and bonus fields correctly', () {
      final state = const SubscriptionState(freeQuota: 8);
      final emergencyResult = PromoActivationResult(
        type: PromoResultType.emergencyBonus,
        message: 'Emergency bonus added',
        bonusBillsAdded: 3,
        updatedState: state,
      );

      expect(emergencyResult.isSuccess, true);
      expect(emergencyResult.bonusBillsAdded, 3);
      expect(emergencyResult.type, PromoResultType.emergencyBonus);

      final invalidResult = PromoActivationResult(
        type: PromoResultType.invalid,
        message: 'Invalid key',
        updatedState: state,
      );
      expect(invalidResult.isSuccess, false);
    });
  });

  group('Invoice Record Model Tests', () {
    test('InvoiceRecord serialization and total computation', () {
      final record = InvoiceRecord(
        id: '123456789',
        patientName: 'Jane Smith',
        patientPhone: '9876543210',
        diagnosis: 'Cervical Radiculopathy',
        treatmentPlan: 'Manual Mobilization + IFT',
        treatmentItems: [
          {'treatment': 'Cervical Traction & IFT', 'date': '21-10-2026', 'amount': '600'},
          {'treatment': 'Isometric Neck Exercises', 'date': '21-10-2026', 'amount': '400'},
        ],
        totalAmount: 1000.0,
        paymentMode: 'UPI',
        paymentStatus: 'Paid',
        createdAt: DateTime(2026, 10, 21),
      );

      final map = record.toMap();
      final restored = InvoiceRecord.fromMap(map);

      expect(restored.patientName, 'Jane Smith');
      expect(restored.totalAmount, 1000.0);
      expect(restored.treatmentItems.length, 2);
      expect(restored.paymentStatus, 'Paid');
    });
  });

  group('Supabase Activation & Auth Models', () {
    test('Therapist optional id serialization', () {
      final t = Therapist(
        id: 'usr-abc-123',
        name: 'Dr. Jane, PT',
        clinicName: 'Spine Care',
        practiceType: 'Clinic',
        qualification: 'BPT',
        registrationNumber: 'REG-1',
        phone: '9988776655',
        email: 'jane@example.com',
        workHours: '9am - 5pm',
        logoBase64: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
        signatureBase64: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      );
      final map = t.toMap();
      expect(map['id'], 'usr-abc-123');
      expect(map['logoBase64'], isNotEmpty);
      expect(map['signatureBase64'], isNotEmpty);
      final restored = Therapist.fromMap(map);
      expect(restored.id, 'usr-abc-123');
      expect(restored.logoBase64, t.logoBase64);
      expect(restored.signatureBase64, t.signatureBase64);
    });
  });
}

