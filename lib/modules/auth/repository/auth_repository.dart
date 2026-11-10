import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoizo/modules/login/model/user_model.dart';
import 'package:invoizo/modules/subscription/services/supabase_subscription_service.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

class AuthRepository {
  static const authBoxName = 'authBox';
  static const isLoggedInKey = 'isLoggedIn';
  static const therapistKey = 'currentTherapist';

  late final Box _box;

  Future<void> init() async {
    _box = await Hive.openBox(authBoxName);
  }

  bool get isLoggedIn {
    try {
      return _box.get(isLoggedInKey, defaultValue: false) as bool;
    } catch (e) {
      debugPrint('Error checking login status: $e');
      return false;
    }
  }

  Future<void> login(Therapist therapist) async {
    try {
      await _box.putAll({therapistKey: therapist.toMap(), isLoggedInKey: true});
    } catch (e) {
      debugPrint('Error during login: $e');
      throw Exception('Failed to save login data');
    }
  }

  Future<void> logout() async {
    try {
      await _box.put(isLoggedInKey, false);
      if (SupabaseSubscriptionService.isConnected) {
        await SupabaseSubscriptionService.signOut();
      }
    } catch (e) {
      debugPrint('Error during logout: $e');
      throw Exception('Failed to logout');
    }
  }

  Therapist? getCurrentTherapist() {
    try {
      final data = _box.get(therapistKey);
      if (data != null) {
        return Therapist.fromMap(Map<String, dynamic>.from(data as Map));
      }
      return null;
    } catch (e) {
      debugPrint('Error getting therapist: $e');
      return null;
    }
  }

  Future<void> updateTherapist(Therapist therapist) async {
    try {
      await _box.put(therapistKey, therapist.toMap());
      if (SupabaseSubscriptionService.isConnected) {
        SupabaseSubscriptionService.saveProfile(therapist).catchError((e) {
          debugPrint('Error syncing profile update to Supabase: $e');
          return false;
        });
      }
    } catch (e) {
      debugPrint('Error updating therapist: $e');
      throw Exception('Failed to update therapist data');
    }
  }

  /// Sign Up with Supabase Auth & sync profile + subscription
  Future<AuthResult> signUpWithSupabase({
    required String email,
    required String password,
    required Therapist therapist,
  }) async {
    try {
      final result = await SupabaseSubscriptionService.signUpWithEmailAndPassword(
        email: email,
        password: password,
        therapist: therapist,
      );

      if (result.isSuccess) {
        final savedTherapist = result.therapist ?? therapist;
        await login(savedTherapist);
        return AuthResult(
          isSuccess: true,
          message: result.message,
          therapist: savedTherapist,
        );
      }

      return result;
    } catch (e) {
      debugPrint('Supabase signup error in repository: $e');
      return AuthResult(
        isSuccess: false,
        message: 'Registration error: $e',
      );
    }
  }

  /// Sign In with Supabase Auth & restore profile
  Future<AuthResult> signInWithSupabase({
    required String email,
    required String password,
  }) async {
    try {
      final result = await SupabaseSubscriptionService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.isSuccess) {
        final existingLocal = getCurrentTherapist();
        final finalTherapist = result.therapist ??
            existingLocal ??
            Therapist(
              name: 'Dr. Practitioner',
              clinicName: 'Physiotherapy Clinic',
              qualification: 'BPT',
              registrationNumber: '',
              phone: '',
              email: email,
              workHours: '9:00 AM - 7:00 PM',
            );

        await login(finalTherapist);
        return AuthResult(
          isSuccess: true,
          message: result.message,
          therapist: finalTherapist,
        );
      }

      return result;
    } catch (e) {
      debugPrint('Supabase signin error in repository: $e');
      return AuthResult(
        isSuccess: false,
        message: 'Sign in error: $e',
      );
    }
  }
}

