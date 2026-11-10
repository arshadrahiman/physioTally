import 'package:flutter/foundation.dart';
import 'package:invoizo/core/constants/subscription_constants.dart';
import 'package:invoizo/core/utils/image_utils.dart';
import 'package:invoizo/modules/login/model/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RemoteSubscriptionResult {
  final bool isFound;
  final bool isActive;
  final String? planName;
  final DateTime? expiresAt;
  final String? remoteSubscriptionId;
  final String message;

  const RemoteSubscriptionResult({
    required this.isFound,
    required this.isActive,
    this.planName,
    this.expiresAt,
    this.remoteSubscriptionId,
    required this.message,
  });
}

class ActivationKeyResult {
  final bool isValid;
  final String keyType; // 'pro' or 'bonus'
  final int bonusBills;
  final String planName;
  final int durationDays;
  final String message;

  const ActivationKeyResult({
    required this.isValid,
    this.keyType = 'pro',
    this.bonusBills = 3,
    this.planName = 'Physio Pro',
    this.durationDays = 365,
    required this.message,
  });
}

class AuthResult {
  final bool isSuccess;
  final String message;
  final Therapist? therapist;

  const AuthResult({
    required this.isSuccess,
    required this.message,
    this.therapist,
  });
}

class SupabaseSubscriptionService {
  static bool _initialized = false;

  static Future<void> initializeIfConfigured() async {
    if (_initialized) return;

    if (!SubscriptionConstants.isSupabaseConfigured) {
      debugPrint('ℹ️ Cloud credentials not configured. Operating in local mode.');
      return;
    }

    try {
      await Supabase.initialize(
        url: SubscriptionConstants.supabaseUrl,
        publishableKey: SubscriptionConstants.supabaseAnonKey,
      );
      _initialized = true;
      debugPrint('✅ Cloud sync initialized successfully.');
    } catch (e) {
      debugPrint('⚠️ Cloud sync initialization note: $e');
    }
  }

  static SupabaseClient? get _client {
    if (!_initialized || !SubscriptionConstants.isSupabaseConfigured) {
      return null;
    }
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static bool get isConnected => _client != null;

  static bool _isTableNotFound(dynamic e) {
    if (e is PostgrestException) {
      return e.code == 'PGRST205' ||
          e.message.contains('schema cache') ||
          e.message.contains('Could not find the table');
    }
    final s = e.toString();
    return s.contains('PGRST205') || s.contains('schema cache');
  }

  // ==========================================
  // AUTHENTICATION & PRACTITIONER PROFILE SYNC
  // ==========================================

  /// Sign Up with Email and Password, and sync practice profile to Supabase
  static Future<AuthResult> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required Therapist therapist,
  }) async {
    final client = _client;
    if (client == null) {
      return AuthResult(
        isSuccess: true,
        message: 'Saved locally (offline mode).',
        therapist: therapist,
      );
    }

    try {
      final logoB64 = therapist.logoBase64 ??
          await ImageUtils.fileToBase64(therapist.logoPath);
      final sigB64 = therapist.signatureBase64 ??
          await ImageUtils.fileToBase64(therapist.signaturePath);

      final res = await client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'name': therapist.name,
          'clinic_name': therapist.clinicName,
          'qualification': therapist.qualification,
          'registration_number': therapist.registrationNumber,
          'practice_type': therapist.practiceType,
          'phone': therapist.phone,
          'upi_id': therapist.upiId ?? '',
          'work_hours': therapist.workHours,
          'address': therapist.address ?? '',
          'logo_base64': logoB64 ?? '',
          'signature_base64': sigB64 ?? '',
        },
      );

      final userId = res.user?.id;
      final updatedTherapist = therapist.copyWith(
        id: userId,
        logoBase64: logoB64,
        signatureBase64: sigB64,
      );

      // 1. Sync to profiles table
      try {
        await client.from(SubscriptionConstants.profilesTable).upsert({
          'id': ?userId,
          'email': email.trim(),
          'name': therapist.name,
          'qualification': therapist.qualification,
          'registration_number': therapist.registrationNumber,
          'clinic_name': therapist.clinicName,
          'practice_type': therapist.practiceType,
          'phone': therapist.phone,
          'upi_id': therapist.upiId ?? '',
          'work_hours': therapist.workHours,
          'address': therapist.address ?? '',
          'logo_base64': logoB64 ?? '',
          'signature_base64': sigB64 ?? '',
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        if (!_isTableNotFound(e)) {
          debugPrint('Profile upsert note: $e');
        }
      }

      // 2. Initialize default subscription row
      try {
        await client.from(SubscriptionConstants.subscriptionsTable).upsert({
          'user_id': ?userId,
          'email': email.trim(),
          'phone': therapist.phone,
          'tier': 'free',
          'plan_name': 'Free Starter Plan',
          'free_quota': 5,
          'invoices_generated': 0,
          'is_active': true,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        if (!_isTableNotFound(e)) {
          debugPrint('Subscription initialization note: $e');
        }
      }

      return AuthResult(
        isSuccess: true,
        message: 'Account created and practice profile synced.',
        therapist: updatedTherapist,
      );
    } on AuthException catch (e) {
      debugPrint('Auth error: ${e.message}');
      final msg = (e.message.contains('SocketException') ||
              e.message.contains('Failed host lookup') ||
              e.message.contains('ClientException'))
          ? 'Unable to connect to the server. Please check your internet connection or verify your Supabase project status.'
          : e.message;
      return AuthResult(
        isSuccess: false,
        message: msg,
      );
    } catch (e) {
      debugPrint('Signup error: $e');
      return AuthResult(
        isSuccess: false,
        message: 'Unable to connect to service. Please check connection.',
      );
    }
  }

  /// Sign In with Email and Password, and restore practitioner profile
  static Future<AuthResult> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      return const AuthResult(
        isSuccess: false,
        message: 'Operating in offline mode. Please connect to internet to sign in.',
      );
    }

    try {
      final res = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final user = res.user;
      Therapist? therapist;

      if (user != null) {
        // Fetch practitioner profile
        try {
          final profileRes = await client
              .from(SubscriptionConstants.profilesTable)
              .select()
              .or('id.eq.${user.id},email.eq.${user.email}')
              .maybeSingle();

          if (profileRes != null) {
            therapist = await _buildTherapistWithDecodedImages(
              id: user.id,
              name: profileRes['name']?.toString() ?? '',
              qualification: profileRes['qualification']?.toString() ?? '',
              registrationNumber: profileRes['registration_number']?.toString() ?? '',
              clinicName: profileRes['clinic_name']?.toString() ?? '',
              practiceType: profileRes['practice_type']?.toString() ??
                  'Freelance / Home Visit Physiotherapist',
              phone: profileRes['phone']?.toString() ?? '',
              email: profileRes['email']?.toString() ?? user.email ?? email,
              upiId: profileRes['upi_id']?.toString() ?? '',
              workHours: profileRes['work_hours']?.toString() ?? '9:00 AM - 7:00 PM',
              address: profileRes['address']?.toString() ?? '',
              logoB64: profileRes['logo_base64']?.toString(),
              signatureB64: profileRes['signature_base64']?.toString(),
            );
          } else if (user.userMetadata != null && user.userMetadata!.isNotEmpty) {
            final meta = user.userMetadata!;
            therapist = await _buildTherapistWithDecodedImages(
              id: user.id,
              name: meta['name']?.toString() ?? '',
              qualification: meta['qualification']?.toString() ?? '',
              registrationNumber: meta['registration_number']?.toString() ?? '',
              clinicName: meta['clinic_name']?.toString() ?? '',
              practiceType: meta['practice_type']?.toString() ??
                  'Freelance / Home Visit Physiotherapist',
              phone: meta['phone']?.toString() ?? '',
              email: user.email ?? email,
              upiId: meta['upi_id']?.toString() ?? '',
              workHours: meta['work_hours']?.toString() ?? '9:00 AM - 7:00 PM',
              address: meta['address']?.toString() ?? '',
              logoB64: meta['logo_base64']?.toString(),
              signatureB64: meta['signature_base64']?.toString(),
            );
          }
        } catch (e) {
          if (!_isTableNotFound(e)) {
            debugPrint('Profile restore note: $e');
          }
          if (user.userMetadata != null && user.userMetadata!.isNotEmpty) {
            final meta = user.userMetadata!;
            therapist = await _buildTherapistWithDecodedImages(
              id: user.id,
              name: meta['name']?.toString() ?? '',
              qualification: meta['qualification']?.toString() ?? '',
              registrationNumber: meta['registration_number']?.toString() ?? '',
              clinicName: meta['clinic_name']?.toString() ?? '',
              practiceType: meta['practice_type']?.toString() ??
                  'Freelance / Home Visit Physiotherapist',
              phone: meta['phone']?.toString() ?? '',
              email: user.email ?? email,
              upiId: meta['upi_id']?.toString() ?? '',
              workHours: meta['work_hours']?.toString() ?? '9:00 AM - 7:00 PM',
              address: meta['address']?.toString() ?? '',
              logoB64: meta['logo_base64']?.toString(),
              signatureB64: meta['signature_base64']?.toString(),
            );
          }
        }
      }

      return AuthResult(
        isSuccess: true,
        message: 'Signed in successfully.',
        therapist: therapist,
      );
    } on AuthException catch (e) {
      debugPrint('Sign in auth exception: ${e.message}');
      final msg = (e.message.contains('SocketException') ||
              e.message.contains('Failed host lookup') ||
              e.message.contains('ClientException'))
          ? 'Unable to connect to the server. Please check your internet connection or verify your Supabase project status.'
          : e.message;
      return AuthResult(
        isSuccess: false,
        message: msg,
      );
    } catch (e) {
      debugPrint('Sign in error: $e');
      return const AuthResult(
        isSuccess: false,
        message: 'Unable to sign in. Please verify your email and password.',
      );
    }
  }

  /// Helper to decode Base64 strings to local device files and construct a Therapist
  static Future<Therapist> _buildTherapistWithDecodedImages({
    required String? id,
    required String name,
    required String qualification,
    required String registrationNumber,
    required String clinicName,
    required String practiceType,
    required String phone,
    required String email,
    required String upiId,
    required String workHours,
    required String address,
    String? logoB64,
    String? signatureB64,
  }) async {
    String? localLogoPath;
    if (logoB64 != null && logoB64.trim().isNotEmpty) {
      localLogoPath = await ImageUtils.base64ToLocalFile(logoB64, 'clinic_logo.png');
    }

    String? localSigPath;
    if (signatureB64 != null && signatureB64.trim().isNotEmpty) {
      localSigPath = await ImageUtils.base64ToLocalFile(signatureB64, 'practitioner_signature.png');
    }

    return Therapist(
      id: id,
      name: name,
      qualification: qualification,
      registrationNumber: registrationNumber,
      clinicName: clinicName,
      practiceType: practiceType,
      phone: phone,
      email: email,
      upiId: upiId,
      workHours: workHours,
      address: address,
      logoPath: localLogoPath,
      signaturePath: localSigPath,
      logoBase64: logoB64,
      signatureBase64: signatureB64,
    );
  }

  /// Sign Out
  static Future<void> signOut() async {
    try {
      await _client?.auth.signOut();
    } catch (e) {
      debugPrint('Sign out note: $e');
    }
  }

  /// Updates or saves practitioner profile to Supabase
  static Future<bool> saveProfile(Therapist therapist) async {
    final client = _client;
    if (client == null) return false;

    try {
      final logoB64 = therapist.logoBase64 ??
          await ImageUtils.fileToBase64(therapist.logoPath);
      final sigB64 = therapist.signatureBase64 ??
          await ImageUtils.fileToBase64(therapist.signaturePath);

      await client.from(SubscriptionConstants.profilesTable).upsert({
        if (therapist.id != null) 'id': therapist.id,
        'email': therapist.email,
        'name': therapist.name,
        'qualification': therapist.qualification,
        'registration_number': therapist.registrationNumber,
        'clinic_name': therapist.clinicName,
        'practice_type': therapist.practiceType,
        'phone': therapist.phone,
        'upi_id': therapist.upiId ?? '',
        'work_hours': therapist.workHours,
        'address': therapist.address ?? '',
        'logo_base64': logoB64 ?? '',
        'signature_base64': sigB64 ?? '',
        'updated_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      if (!_isTableNotFound(e)) {
        debugPrint('Error saving profile: $e');
      }
      return false;
    }
  }

  // ==========================================
  // SUBSCRIPTION STATE & REMOTE STATUS SYNC
  // ==========================================

  /// Checks remote subscription status on Supabase server by therapist email or phone
  static Future<RemoteSubscriptionResult> checkRemoteStatus({
    required String email,
    required String phone,
    String? userId,
  }) async {
    final client = _client;
    if (client == null) {
      return const RemoteSubscriptionResult(
        isFound: false,
        isActive: false,
        message: 'Operating in offline mode.',
      );
    }

    try {
      final query = client.from(SubscriptionConstants.subscriptionsTable).select();
      final filter = userId != null && userId.isNotEmpty
          ? 'user_id.eq.$userId,email.eq.$email'
          : 'email.eq.$email,phone.eq.$phone';

      final response = await query.or(filter).order('updated_at', ascending: false).limit(1);

      if (response.isNotEmpty) {
        final row = response.first;
        final isActive = (row['is_active'] as bool?) ?? false;
        final tier = row['tier']?.toString();
        final isPro = tier == 'pro' || isActive;
        final planName = row['plan_name']?.toString() ?? (isPro ? 'Physio Pro Plan' : 'Free Tier');
        final expiresAtStr = row['expires_at']?.toString();
        final expiresAt = expiresAtStr != null ? DateTime.tryParse(expiresAtStr) : null;
        final id = row['id']?.toString();

        return RemoteSubscriptionResult(
          isFound: true,
          isActive: isPro,
          planName: planName,
          expiresAt: expiresAt,
          remoteSubscriptionId: id,
          message: isPro
              ? 'Active Pro subscription verified.'
              : 'Free trial active.',
        );
      }

      return const RemoteSubscriptionResult(
        isFound: false,
        isActive: false,
        message: 'No subscription record found for this account.',
      );
    } catch (e) {
      if (!_isTableNotFound(e)) {
        debugPrint('Error querying subscriptions: $e');
      }
      return const RemoteSubscriptionResult(
        isFound: false,
        isActive: false,
        message: 'Unable to verify subscription online. Operating in local mode.',
      );
    }
  }

  /// Syncs user's subscription record with Supabase
  static Future<RemoteSubscriptionResult> syncSubscription({
    required String email,
    required String phone,
    String? userId,
    required int invoicesGenerated,
    required int freeQuota,
    required bool isPro,
    required String activePlanName,
    DateTime? proExpiresAt,
  }) async {
    final client = _client;
    if (client == null) {
      return const RemoteSubscriptionResult(
        isFound: false,
        isActive: false,
        message: 'Operating in offline mode.',
      );
    }

    try {
      // 1. Check existing subscription in cloud
      final remote = await checkRemoteStatus(email: email, phone: phone, userId: userId);

      if (remote.isFound) {
        return remote;
      }

      // 2. If not found in cloud, upsert local status to cloud
      await client.from(SubscriptionConstants.subscriptionsTable).upsert({
        'user_id': ?userId,
        'email': email,
        'phone': phone,
        'tier': isPro ? 'pro' : 'free',
        'plan_name': activePlanName,
        'invoices_generated': invoicesGenerated,
        'free_quota': freeQuota,
        'is_active': isPro,
        'expires_at': proExpiresAt?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      return RemoteSubscriptionResult(
        isFound: true,
        isActive: isPro,
        planName: activePlanName,
        expiresAt: proExpiresAt,
        message: 'Subscription synced successfully.',
      );
    } catch (e) {
      if (!_isTableNotFound(e)) {
        debugPrint('Subscription sync error: $e');
      }
      return const RemoteSubscriptionResult(
        isFound: false,
        isActive: false,
        message: 'Sync completed with local verified state.',
      );
    }
  }

  // ==========================================
  // DEDICATED ACTIVATION KEYS TABLE VALIDATION
  // ==========================================

  /// Verifies and redeems an activation key from the dedicated `activation_keys` table
  static Future<ActivationKeyResult> validateAndRedeemActivationKey({
    required String code,
    required String email,
    required String phone,
  }) async {
    final client = _client;
    if (client == null) {
      return const ActivationKeyResult(
        isValid: false,
        message: 'Unable to connect to verification service.',
      );
    }

    final sanitizedCode = code.trim().toUpperCase();

    try {
      // 1. Query separate `activation_keys` table
      final response = await client
          .from(SubscriptionConstants.activationKeysTable)
          .select()
          .eq('code', sanitizedCode)
          .limit(1);

      if (response.isNotEmpty) {
        final row = response.first;
        final isActive = (row['is_active'] as bool?) ?? true;
        if (!isActive) {
          return const ActivationKeyResult(
            isValid: false,
            message: 'This activation key has been deactivated.',
          );
        }

        // Check expiration
        final expiresAtStr = row['expires_at']?.toString();
        if (expiresAtStr != null && expiresAtStr.isNotEmpty) {
          final expiresAt = DateTime.tryParse(expiresAtStr);
          if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
            return const ActivationKeyResult(
              isValid: false,
              message: 'This activation key has expired.',
            );
          }
        }

        // Check usage limits
        final maxUses = (row['max_uses'] as num?)?.toInt() ?? 1;
        final usedCount = (row['used_count'] as num?)?.toInt() ?? 0;
        if (maxUses != -1 && usedCount >= maxUses) {
          return const ActivationKeyResult(
            isValid: false,
            message: 'This activation key has already reached its maximum usage limit.',
          );
        }

        final keyType = row['key_type']?.toString().toLowerCase() ?? 'pro';
        final bonusBills = (row['bonus_bills'] as num?)?.toInt() ?? 3;
        final planName = row['plan_name']?.toString() ?? 'Physio Pro Annual';
        final durationDays = (row['duration_days'] as num?)?.toInt() ?? 365;
        final rowId = row['id']?.toString();

        // Increment usage count in database
        if (rowId != null) {
          try {
            await client.from(SubscriptionConstants.activationKeysTable).update({
              'used_count': usedCount + 1,
              'last_used_at': DateTime.now().toIso8601String(),
              'last_used_by': email.isNotEmpty ? email : phone,
            }).eq('id', rowId);
          } catch (e) {
            debugPrint('Activation key usage increment note: $e');
          }
        }

        return ActivationKeyResult(
          isValid: true,
          keyType: keyType,
          bonusBills: bonusBills,
          planName: planName,
          durationDays: durationDays,
          message: keyType == 'bonus'
              ? 'Bonus Key Accepted! +$bonusBills emergency bills added to your quota.'
              : 'Activation Key Accepted! $planName successfully activated.',
        );
      }
    } catch (e) {
      if (!_isTableNotFound(e)) {
        debugPrint('Activation_keys table query note: $e');
      }
    }

    // 2. Fallback check on `subscriptions` table promo_code column
    final subResult = await redeemRemoteActivationKey(
      promoCode: sanitizedCode,
      email: email,
      phone: phone,
    );
    if (subResult.isFound && subResult.isActive) {
      return ActivationKeyResult(
        isValid: true,
        keyType: 'pro',
        planName: subResult.planName ?? 'Physio Pro',
        durationDays: 365,
        message: subResult.message,
      );
    }

    return const ActivationKeyResult(
      isValid: false,
      message: 'Invalid activation key. Please check the code and try again.',
    );
  }

  /// Backward-compatible redemption against subscriptions table
  static Future<RemoteSubscriptionResult> redeemRemoteActivationKey({
    required String promoCode,
    required String email,
    required String phone,
  }) async {
    final client = _client;
    if (client == null) {
      return const RemoteSubscriptionResult(
        isFound: false,
        isActive: false,
        message: 'Unable to connect to verification service.',
      );
    }

    try {
      final sanitizedCode = promoCode.trim().toUpperCase();
      final response = await client
          .from(SubscriptionConstants.subscriptionsTable)
          .select()
          .eq('promo_code', sanitizedCode)
          .eq('is_redeemed', false)
          .limit(1);

      if (response.isNotEmpty) {
        final row = response.first;
        final rowId = row['id'].toString();
        final planName = row['plan_name']?.toString() ?? 'Physio Pro Annual';
        final durationDays = (row['duration_days'] as num?)?.toInt() ?? 365;
        final expiresAt = DateTime.now().add(Duration(days: durationDays));

        await client.from(SubscriptionConstants.subscriptionsTable).update({
          'is_redeemed': true,
          'is_active': true,
          'redeemed_by_email': email,
          'redeemed_by_phone': phone,
          'redeemed_at': DateTime.now().toIso8601String(),
          'expires_at': expiresAt.toIso8601String(),
        }).eq('id', rowId);

        return RemoteSubscriptionResult(
          isFound: true,
          isActive: true,
          planName: planName,
          expiresAt: expiresAt,
          remoteSubscriptionId: rowId,
          message: 'Promo code successfully verified and activated!',
        );
      }

      return const RemoteSubscriptionResult(
        isFound: false,
        isActive: false,
        message: 'Invalid or already redeemed activation code.',
      );
    } catch (e) {
      debugPrint('Error redeeming code: $e');
      return const RemoteSubscriptionResult(
        isFound: false,
        isActive: false,
        message: 'Unable to verify code at this time. Please try again later.',
      );
    }
  }

  /// Submits an online payment verification request to Supabase for admin approval
  static Future<bool> submitPaymentRequest({
    required String email,
    required String phone,
    required String planName,
    required String amount,
    String? transactionRef,
  }) async {
    final client = _client;
    if (client == null) return false;

    try {
      await client.from(SubscriptionConstants.paymentsTable).insert({
        'email': email,
        'phone': phone,
        'plan_name': planName,
        'amount': amount,
        'transaction_ref': transactionRef ?? '',
        'status': 'pending_approval',
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Error logging payment request on Supabase: $e');
      return false;
    }
  }
}
