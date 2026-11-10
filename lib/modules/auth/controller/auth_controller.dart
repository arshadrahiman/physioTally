import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoizo/modules/auth/repository/auth_repository.dart';
import 'package:invoizo/modules/login/model/user_model.dart';
import 'package:invoizo/modules/subscription/services/supabase_subscription_service.dart';

final authControllerProvider = NotifierProvider<AuthController, AuthState>(() {
  return AuthController();
});

class AuthState {
  final bool isLoggedIn;
  final Therapist? therapist;

  AuthState({required this.isLoggedIn, this.therapist});

  AuthState copyWith({
    bool? isLoggedIn,
    Therapist? therapist,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      therapist: therapist ?? this.therapist,
    );
  }
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final repo = ref.watch(authRepositoryProvider);
    return AuthState(
      isLoggedIn: repo.isLoggedIn,
      therapist: repo.getCurrentTherapist(),
    );
  }

  Future<void> login(Therapist therapist) async {
    final repo = ref.read(authRepositoryProvider);
    await repo.login(therapist);
    state = state.copyWith(isLoggedIn: true, therapist: therapist);
  }

  Future<AuthResult> signUp({
    required String email,
    required String password,
    required Therapist therapist,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.signUpWithSupabase(
      email: email,
      password: password,
      therapist: therapist,
    );
    if (result.isSuccess) {
      state = state.copyWith(
        isLoggedIn: true,
        therapist: result.therapist ?? therapist,
      );
    }
    return result;
  }

  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.signInWithSupabase(
      email: email,
      password: password,
    );
    if (result.isSuccess) {
      final t = result.therapist ?? repo.getCurrentTherapist();
      state = state.copyWith(
        isLoggedIn: true,
        therapist: t,
      );
    }
    return result;
  }

  Future<void> logout() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.logout();
    state = AuthState(isLoggedIn: false, therapist: null);
  }

  Future<void> updateTherapist(Therapist therapist) async {
    final repo = ref.read(authRepositoryProvider);
    await repo.updateTherapist(therapist);
    state = state.copyWith(therapist: therapist);
  }
}

