import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:invoizo/core/constants/subscription_constants.dart';
import 'package:invoizo/modules/subscription/model/subscription_model.dart';
import 'package:invoizo/modules/subscription/services/supabase_subscription_service.dart';

class SubscriptionRepository {
  static const boxName = 'subscriptionBox';
  static const subscriptionKey = 'currentSubscription';

  late final Box _box;

  Future<void> init() async {
    _box = await Hive.openBox(boxName);
  }

  SubscriptionState getSubscription() {
    try {
      final data = _box.get(subscriptionKey);
      if (data != null) {
        return SubscriptionState.fromMap(Map<String, dynamic>.from(data as Map));
      }
      return const SubscriptionState();
    } catch (e) {
      debugPrint('Error getting subscription: $e');
      return const SubscriptionState();
    }
  }

  Future<SubscriptionState> saveSubscription(SubscriptionState state) async {
    try {
      await _box.put(subscriptionKey, state.toMap());
      return state;
    } catch (e) {
      debugPrint('Error saving subscription: $e');
      throw Exception('Failed to save subscription');
    }
  }

  Future<SubscriptionState> incrementInvoiceCount() async {
    final current = getSubscription();
    final updated = current.copyWith(
      invoicesGenerated: current.invoicesGenerated + 1,
    );
    await saveSubscription(updated);
    return updated;
  }

  /// Adds temporary emergency bonus bills (e.g. +3 bills) for urgent patient needs or testing
  Future<SubscriptionState> addEmergencyBonusBills([int count = 3]) async {
    final current = getSubscription();
    final updated = current.copyWith(
      freeQuota: current.freeQuota + count,
    );
    await saveSubscription(updated);
    return updated;
  }

  Future<SubscriptionState> upgradeToPro({
    String planName = 'Physio Pro Annual',
    int durationDays = 365,
    String? remoteSubId,
  }) async {
    final current = getSubscription();
    final updated = current.copyWith(
      tier: SubscriptionTier.pro,
      proExpiresAt: DateTime.now().add(Duration(days: durationDays)),
      activePlanName: planName,
      status: 'active',
      remoteSubscriptionId: remoteSubId ?? current.remoteSubscriptionId,
      lastSyncedAt: DateTime.now(),
    );
    await saveSubscription(updated);
    return updated;
  }

  /// Handles promo code activation with Secret Emergency Key (+3 bills), VIP keys, or remote Supabase verification
  Future<PromoActivationResult> activatePromoCode(
    String rawCode, {
    String? userEmail,
    String? userPhone,
  }) async {
    final current = getSubscription();
    final code = rawCode.trim().toUpperCase();

    // 1. Check Secret Emergency +3 Bills Key
    if (code == SubscriptionConstants.emergencyTopupKey) {
      final updated = await addEmergencyBonusBills(SubscriptionConstants.emergencyTopupCount);
      return PromoActivationResult(
        type: PromoResultType.emergencyBonus,
        bonusBillsAdded: SubscriptionConstants.emergencyTopupCount,
        message:
            '🚨 Emergency Key Accepted! +${SubscriptionConstants.emergencyTopupCount} bills added to your quota for immediate patient use.',
        updatedState: updated,
      );
    }

    // 2. Check Local VIP Master Keys
    if (SubscriptionConstants.vipProKeys.contains(code)) {
      final updated = await upgradeToPro(
        planName: 'Physio Pro (Master Key VIP)',
        durationDays: 3650,
      );
      return PromoActivationResult(
        type: PromoResultType.proActivated,
        message: '⭐ Master VIP Promo Code Accepted! Unlimited Physio Pro activated.',
        updatedState: updated,
      );
    }

    // 3. Check Supabase Remote Server Database (Dedicated activation_keys table)
    if (SupabaseSubscriptionService.isConnected) {
      final keyResult = await SupabaseSubscriptionService.validateAndRedeemActivationKey(
        code: code,
        email: userEmail ?? '',
        phone: userPhone ?? '',
      );

      if (keyResult.isValid) {
        if (keyResult.keyType == 'bonus') {
          final updated = await addEmergencyBonusBills(keyResult.bonusBills);
          return PromoActivationResult(
            type: PromoResultType.emergencyBonus,
            bonusBillsAdded: keyResult.bonusBills,
            message: keyResult.message,
            updatedState: updated,
          );
        } else {
          final updated = await upgradeToPro(
            planName: keyResult.planName,
            durationDays: keyResult.durationDays,
          );
          return PromoActivationResult(
            type: PromoResultType.proActivated,
            message: keyResult.message,
            updatedState: updated,
          );
        }
      }
    }

    // 4. Invalid Code
    return PromoActivationResult(
      type: PromoResultType.invalid,
      message: 'Invalid promo code. Please check your activation key or contact support.',
      updatedState: current,
    );
  }

  /// Supabase Remote Server Database Status Check & Sync
  Future<SubscriptionState> syncWithRemoteDatabase({
    required String email,
    required String phone,
    String? userId,
  }) async {
    final current = getSubscription();
    if (!SupabaseSubscriptionService.isConnected) {
      return current;
    }

    final remoteRes = await SupabaseSubscriptionService.syncSubscription(
      email: email,
      phone: phone,
      userId: userId,
      invoicesGenerated: current.invoicesGenerated,
      freeQuota: current.freeQuota,
      isPro: current.isPro,
      activePlanName: current.activePlanName,
      proExpiresAt: current.proExpiresAt,
    );

    if (remoteRes.isFound && remoteRes.isActive) {
      final updated = current.copyWith(
        tier: SubscriptionTier.pro,
        status: 'active',
        activePlanName: remoteRes.planName ?? 'Physio Pro Remote',
        proExpiresAt: remoteRes.expiresAt ?? DateTime.now().add(const Duration(days: 365)),
        remoteSubscriptionId: remoteRes.remoteSubscriptionId,
        isRemoteVerified: true,
        lastSyncedAt: DateTime.now(),
      );
      await saveSubscription(updated);
      return updated;
    } else if (remoteRes.isFound && !remoteRes.isActive) {
      // Remote server marked this as expired or canceled
      final updated = current.copyWith(
        tier: SubscriptionTier.free,
        status: 'inactive',
        isRemoteVerified: true,
        lastSyncedAt: DateTime.now(),
      );
      await saveSubscription(updated);
      return updated;
    }

    return current;
  }

  Future<SubscriptionState> resetToFreeForTesting() async {
    final updated = const SubscriptionState(
      tier: SubscriptionTier.free,
      invoicesGenerated: 0,
      activePlanName: 'Free Starter Plan',
      status: 'inactive',
    );
    await saveSubscription(updated);
    return updated;
  }
}
