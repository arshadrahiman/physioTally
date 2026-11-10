import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoizo/modules/subscription/model/subscription_model.dart';
import 'package:invoizo/modules/subscription/repository/subscription_repository.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository();
});

final subscriptionControllerProvider =
    NotifierProvider<SubscriptionController, SubscriptionState>(() {
  return SubscriptionController();
});

class SubscriptionController extends Notifier<SubscriptionState> {
  @override
  SubscriptionState build() {
    final repo = ref.watch(subscriptionRepositoryProvider);
    return repo.getSubscription();
  }

  Future<void> reload() async {
    final repo = ref.read(subscriptionRepositoryProvider);
    state = repo.getSubscription();
  }

  Future<bool> incrementUsage() async {
    final repo = ref.read(subscriptionRepositoryProvider);
    final updated = await repo.incrementInvoiceCount();
    state = updated;
    return true;
  }

  Future<void> upgradeToPro({
    String planName = 'Physio Pro Annual',
    int durationDays = 365,
  }) async {
    final repo = ref.read(subscriptionRepositoryProvider);
    final updated = await repo.upgradeToPro(
      planName: planName,
      durationDays: durationDays,
    );
    state = updated;
  }

  /// Activates a promo code: supports Secret Emergency +3 Key, Master VIP, and Supabase Server
  Future<PromoActivationResult> activatePromo(
    String code, {
    String? email,
    String? phone,
  }) async {
    final repo = ref.read(subscriptionRepositoryProvider);
    final result = await repo.activatePromoCode(
      code,
      userEmail: email,
      userPhone: phone,
    );
    if (result.isSuccess) {
      state = result.updatedState;
    }
    return result;
  }

  /// Adds temporary emergency bonus bills (+3)
  Future<void> addEmergencyBonus([int count = 3]) async {
    final repo = ref.read(subscriptionRepositoryProvider);
    final updated = await repo.addEmergencyBonusBills(count);
    state = updated;
  }

  /// Syncs with remote Supabase server database
  Future<SubscriptionState> syncWithSupabaseServer({
    required String email,
    required String phone,
    String? userId,
  }) async {
    final repo = ref.read(subscriptionRepositoryProvider);
    final updated = await repo.syncWithRemoteDatabase(
      email: email,
      phone: phone,
      userId: userId,
    );
    state = updated;
    return updated;
  }

  Future<void> resetToFree() async {
    final repo = ref.read(subscriptionRepositoryProvider);
    final updated = await repo.resetToFreeForTesting();
    state = updated;
  }
}
