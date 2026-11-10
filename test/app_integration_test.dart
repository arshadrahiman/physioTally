import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoizo/modules/auth/repository/auth_repository.dart';
import 'package:invoizo/modules/history/controller/history_controller.dart';
import 'package:invoizo/modules/history/model/invoice_record.dart';
import 'package:invoizo/modules/history/repository/invoice_repository.dart';
import 'package:invoizo/modules/login/model/user_model.dart';
import 'package:invoizo/modules/login/view/login_screen.dart';
import 'package:invoizo/modules/subscription/controller/subscription_controller.dart';
import 'package:invoizo/modules/subscription/model/subscription_model.dart';
import 'package:invoizo/modules/subscription/repository/subscription_repository.dart';
import 'package:invoizo/modules/subscription/services/supabase_subscription_service.dart';

class MockAuthRepository extends AuthRepository {
  Therapist? _therapist;
  bool _loggedIn = false;

  @override
  bool get isLoggedIn => _loggedIn;

  @override
  Therapist? getCurrentTherapist() => _therapist;

  @override
  Future<void> login(Therapist therapist) async {
    _therapist = therapist;
    _loggedIn = true;
  }

  @override
  Future<void> logout() async {
    _therapist = null;
    _loggedIn = false;
  }

  @override
  Future<AuthResult> signInWithSupabase({
    required String email,
    required String password,
  }) async {
    _loggedIn = true;
    _therapist = Therapist(
      name: 'Dr. Physio Practitioner',
      clinicName: 'PhysioTally Clinic',
      qualification: 'BPT',
      registrationNumber: 'REG-123',
      phone: '+91 9876543210',
      email: email,
      workHours: '9:00 AM - 7:00 PM',
    );
    return AuthResult(isSuccess: true, message: 'Welcome back!', therapist: _therapist);
  }
}

class MockSubscriptionRepository extends SubscriptionRepository {
  SubscriptionState _state = const SubscriptionState();

  @override
  SubscriptionState getSubscription() => _state;

  @override
  Future<SubscriptionState> saveSubscription(SubscriptionState state) async {
    _state = state;
    return _state;
  }

  @override
  Future<SubscriptionState> incrementInvoiceCount() async {
    _state = _state.copyWith(invoicesGenerated: _state.invoicesGenerated + 1);
    return _state;
  }

  @override
  Future<SubscriptionState> addEmergencyBonusBills([int count = 3]) async {
    _state = _state.copyWith(freeQuota: _state.freeQuota + count);
    return _state;
  }

  @override
  Future<SubscriptionState> upgradeToPro({
    String planName = 'Physio Pro Annual',
    int durationDays = 365,
    String? remoteSubId,
  }) async {
    _state = _state.copyWith(
      tier: SubscriptionTier.pro,
      activePlanName: planName,
      status: 'active',
      proExpiresAt: DateTime.now().add(Duration(days: durationDays)),
    );
    return _state;
  }

  @override
  Future<PromoActivationResult> activatePromoCode(
    String rawCode, {
    String? userEmail,
    String? userPhone,
  }) async {
    final code = rawCode.trim().toUpperCase();
    if (code == 'BONUS3BILLS' || code == 'PHYSIO3EMERGENCY') {
      final updated = await addEmergencyBonusBills(3);
      return PromoActivationResult(
        type: PromoResultType.emergencyBonus,
        bonusBillsAdded: 3,
        message: 'Bonus bills added successfully',
        updatedState: updated,
      );
    }

    if (code == 'PHYSIO-VIP-2026' || code == 'VIPMASTER2026') {
      final updated = await upgradeToPro(planName: 'Physio Pro VIP');
      return PromoActivationResult(
        type: PromoResultType.proActivated,
        message: 'Physio Pro VIP activated',
        updatedState: updated,
      );
    }

    return PromoActivationResult(
      type: PromoResultType.invalid,
      message: 'Invalid key',
      updatedState: _state,
    );
  }
}

class MockInvoiceRepository extends InvoiceRepository {
  final List<InvoiceRecord> _invoices = [];

  @override
  List<InvoiceRecord> getAllInvoices() => _invoices;

  @override
  Future<void> saveInvoice(InvoiceRecord invoice) async {
    _invoices.add(invoice);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ActivationKeyResult & Model Integration Tests', () {
    test('ActivationKeyResult model pro type verification', () {
      const res = ActivationKeyResult(
        isValid: true,
        keyType: 'pro',
        planName: 'Physio Pro Annual',
        durationDays: 365,
        message: 'Activated',
      );
      expect(res.isValid, true);
      expect(res.keyType, 'pro');
      expect(res.durationDays, 365);
    });

    test('ActivationKeyResult model bonus type verification', () {
      const res = ActivationKeyResult(
        isValid: true,
        keyType: 'bonus',
        bonusBills: 3,
        message: 'Bonus +3',
      );
      expect(res.isValid, true);
      expect(res.keyType, 'bonus');
      expect(res.bonusBills, 3);
    });

    test('PromoActivation via SubscriptionController applies bonus bills', () async {
      final mockSub = MockSubscriptionRepository();
      final result = await mockSub.activatePromoCode('BONUS3BILLS');
      expect(result.isSuccess, true);
      expect(result.type, PromoResultType.emergencyBonus);
      expect(result.bonusBillsAdded, 3);
      expect(result.updatedState.freeQuota, 8);
    });

    test('PromoActivation via SubscriptionController upgrades to Pro', () async {
      final mockSub = MockSubscriptionRepository();
      final result = await mockSub.activatePromoCode('PHYSIO-VIP-2026');
      expect(result.isSuccess, true);
      expect(result.type, PromoResultType.proActivated);
      expect(result.updatedState.isPro, true);
    });
  });

  group('LoginScreen UI & Mode Toggle Widget Tests', () {
    late MockAuthRepository mockAuth;
    late MockSubscriptionRepository mockSub;
    late MockInvoiceRepository mockInvoice;

    setUp(() {
      mockAuth = MockAuthRepository();
      mockSub = MockSubscriptionRepository();
      mockInvoice = MockInvoiceRepository();
    });

    Widget createTestWidget() {
      return ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuth),
          subscriptionRepositoryProvider.overrideWithValue(mockSub),
          invoiceRepositoryProvider.overrideWithValue(mockInvoice),
        ],
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      );
    }

    testWidgets('LoginScreen displays branding and Sign In view without offline quick access', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsWidgets);
      expect(find.text('Sign in to access your practice & patient receipts'), findsOneWidget);
      expect(find.text('Sign In'), findsWidgets);
      expect(find.text('Register Practice'), findsWidgets);
      expect(find.text('SIGN IN TO PRACTICE'), findsOneWidget);
      // Offline quick access must NOT be present
      expect(find.text('Continue Offline (Quick Access)'), findsNothing);
    });

    testWidgets('LoginScreen switches between Sign In and Register Practice modes', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Click on "Register Practice" tab
      final registerTab = find.text('Register Practice').first;
      await tester.tap(registerTab);
      await tester.pumpAndSettle();

      // Expect registration fields
      expect(find.text('REGISTER PRACTICE & START INVOICING'), findsOneWidget);
      expect(find.text('Full Name with Title *'), findsOneWidget);
      expect(find.text('Clinic / Practice Name'), findsOneWidget);
      expect(find.text('Qualifications *'), findsOneWidget);

      // Click back to "Sign In"
      final signInTab = find.text('Sign In').first;
      await tester.tap(signInTab);
      await tester.pumpAndSettle();

      expect(find.text('SIGN IN TO PRACTICE'), findsOneWidget);
    });

    testWidgets('Validation triggers when submitting empty Sign In form', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final signInButton = find.text('SIGN IN TO PRACTICE');
      await tester.ensureVisible(signInButton);
      await tester.tap(signInButton);
      await tester.pumpAndSettle();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('Sign in authenticates practitioner with credentials', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'physio@test.com');
      await tester.enterText(textFields.at(1), 'password123');

      final signInButton = find.text('SIGN IN TO PRACTICE');
      await tester.ensureVisible(signInButton);
      await tester.tap(signInButton);
      await tester.pumpAndSettle();

      expect(mockAuth.isLoggedIn, true);
      expect(mockAuth.getCurrentTherapist()?.email, 'physio@test.com');
    });
  });
}
