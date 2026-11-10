import 'package:flutter_test/flutter_test.dart';
import 'package:invoizo/core/constants/subscription_constants.dart';

void main() {
  group('Supabase Configuration Tests', () {
    test('Supabase project URL and publishable key are configured', () {
      expect(SubscriptionConstants.supabaseUrl,
          'https://tnddkaktekgtfrzdshsy.supabase.co');
      expect(SubscriptionConstants.supabaseAnonKey,
          'sb_publishable_-OcICJesIrQKt4GLDeeaYg_eUslhT1-');
      expect(SubscriptionConstants.isSupabaseConfigured, true);
    });

    test('Table names are properly defined for remote subscription handling', () {
      expect(SubscriptionConstants.subscriptionsTable, 'subscriptions');
      expect(SubscriptionConstants.paymentsTable, 'subscription_requests');
    });
  });
}
