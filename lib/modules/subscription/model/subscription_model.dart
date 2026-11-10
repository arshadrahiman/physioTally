enum SubscriptionTier {
  free,
  pro,
}

enum PromoResultType {
  emergencyBonus,
  proActivated,
  invalid,
}

class PromoActivationResult {
  final PromoResultType type;
  final String message;
  final int? bonusBillsAdded;
  final SubscriptionState updatedState;

  const PromoActivationResult({
    required this.type,
    required this.message,
    this.bonusBillsAdded,
    required this.updatedState,
  });

  bool get isSuccess =>
      type == PromoResultType.emergencyBonus || type == PromoResultType.proActivated;
}

class SubscriptionState {
  static const int defaultFreeQuota = 5;

  final SubscriptionTier tier;
  final int invoicesGenerated;
  final int freeQuota;
  final DateTime? proExpiresAt;
  final String activePlanName;

  // Supabase / Remote Database Architecture Fields
  final String? remoteUserId;
  final String? remoteSubscriptionId;
  final bool isRemoteVerified;
  final DateTime? lastSyncedAt;
  final String status; // 'active', 'inactive', 'canceled'

  const SubscriptionState({
    this.tier = SubscriptionTier.free,
    this.invoicesGenerated = 0,
    this.freeQuota = defaultFreeQuota,
    this.proExpiresAt,
    this.activePlanName = 'Free Starter Plan',
    this.remoteUserId,
    this.remoteSubscriptionId,
    this.isRemoteVerified = false,
    this.lastSyncedAt,
    this.status = 'inactive',
  });

  bool get isPro {
    if (tier == SubscriptionTier.pro) {
      if (proExpiresAt == null) return true;
      return proExpiresAt!.isAfter(DateTime.now());
    }
    return false;
  }

  int get remainingFreeInvoices {
    if (isPro) return 999999;
    final remaining = freeQuota - invoicesGenerated;
    return remaining > 0 ? remaining : 0;
  }

  bool get canGenerateInvoice {
    if (isPro) return true;
    return invoicesGenerated < freeQuota;
  }

  bool get hasWatermark => !isPro;

  bool get canUseCustomLogoAndSignature => isPro;

  SubscriptionState copyWith({
    SubscriptionTier? tier,
    int? invoicesGenerated,
    int? freeQuota,
    DateTime? proExpiresAt,
    String? activePlanName,
    String? remoteUserId,
    String? remoteSubscriptionId,
    bool? isRemoteVerified,
    DateTime? lastSyncedAt,
    String? status,
  }) {
    return SubscriptionState(
      tier: tier ?? this.tier,
      invoicesGenerated: invoicesGenerated ?? this.invoicesGenerated,
      freeQuota: freeQuota ?? this.freeQuota,
      proExpiresAt: proExpiresAt ?? this.proExpiresAt,
      activePlanName: activePlanName ?? this.activePlanName,
      remoteUserId: remoteUserId ?? this.remoteUserId,
      remoteSubscriptionId: remoteSubscriptionId ?? this.remoteSubscriptionId,
      isRemoteVerified: isRemoteVerified ?? this.isRemoteVerified,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tier': tier.name,
      'invoicesGenerated': invoicesGenerated,
      'freeQuota': freeQuota,
      'proExpiresAt': proExpiresAt?.toIso8601String(),
      'activePlanName': activePlanName,
      'remoteUserId': remoteUserId,
      'remoteSubscriptionId': remoteSubscriptionId,
      'isRemoteVerified': isRemoteVerified,
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
      'status': status,
    };
  }

  factory SubscriptionState.fromMap(Map<String, dynamic> map) {
    SubscriptionTier parsedTier = SubscriptionTier.free;
    if (map['tier'] == 'pro') {
      parsedTier = SubscriptionTier.pro;
    }

    DateTime? expires;
    if (map['proExpiresAt'] != null && map['proExpiresAt'].toString().isNotEmpty) {
      expires = DateTime.tryParse(map['proExpiresAt'].toString());
    }

    DateTime? synced;
    if (map['lastSyncedAt'] != null && map['lastSyncedAt'].toString().isNotEmpty) {
      synced = DateTime.tryParse(map['lastSyncedAt'].toString());
    }

    return SubscriptionState(
      tier: parsedTier,
      invoicesGenerated: (map['invoicesGenerated'] as num?)?.toInt() ?? 0,
      freeQuota: (map['freeQuota'] as num?)?.toInt() ?? defaultFreeQuota,
      proExpiresAt: expires,
      activePlanName: map['activePlanName']?.toString() ??
          (parsedTier == SubscriptionTier.pro ? 'Physio Pro Plan' : 'Free Starter Plan'),
      remoteUserId: map['remoteUserId']?.toString(),
      remoteSubscriptionId: map['remoteSubscriptionId']?.toString(),
      isRemoteVerified: (map['isRemoteVerified'] as bool?) ?? false,
      lastSyncedAt: synced,
      status: map['status']?.toString() ??
          (parsedTier == SubscriptionTier.pro ? 'active' : 'inactive'),
    );
  }
}
