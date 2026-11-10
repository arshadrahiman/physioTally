class SubscriptionConstants {
  // Secret Emergency Promo Key (Large Alphanumeric)
  // When entered, adds +3 emergency bills to the client's quota for demo testing or urgent needs.
  static const String emergencyTopupKey = 'PF-EMERGENCY-BONUS-9645-X8K9-77PQ';
  static const int emergencyTopupCount = 3;

  // Offline / VIP Master Pro Keys
  static const List<String> vipProKeys = [
    'PHYSIOPRO-VIP-KEY-8899-LIFETIME-ACCESS',
    'PHYSIOPRO',
    'FREELANCE',
    'REHAB2026',
  ];

  // Supabase Remote Server Configuration
  // To enable remote subscription management from your Supabase dashboard:
  // 1. Replace the URL and Anon Key below with your project credentials from Supabase Dashboard > Project Settings > API.
  // 2. Create a table named `subscriptions` with columns:
  //    id (uuid), email (text), phone (text), plan_name (text), is_active (bool),
  //    expires_at (timestamptz), promo_code (text), is_redeemed (bool).
  static const String supabaseUrl = 'https://tnddkaktekgtfrzdshsy.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_-OcICJesIrQKt4GLDeeaYg_eUslhT1-';
  static const String subscriptionsTable = 'subscriptions';
  static const String activationKeysTable = 'activation_keys';
  static const String profilesTable = 'profiles';
  static const String paymentsTable = 'subscription_requests';

  static bool get isSupabaseConfigured {
    return supabaseUrl.startsWith('https://') &&
        !supabaseUrl.contains('your-supabase-project') &&
        supabaseAnonKey.length > 20 &&
        !supabaseAnonKey.contains('placeholder');
  }
}
