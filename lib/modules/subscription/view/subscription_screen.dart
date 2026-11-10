import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoizo/core/constants/contact_constants.dart';
import 'package:invoizo/core/theme/app_theme.dart';
import 'package:invoizo/modules/auth/controller/auth_controller.dart';
import 'package:invoizo/modules/subscription/controller/subscription_controller.dart';
import 'package:invoizo/modules/subscription/model/subscription_model.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  int _selectedPlanIndex = 1; // 0 = Monthly, 1 = Annual, 2 = Lifetime
  final _promoController = TextEditingController();

  final List<Map<String, dynamic>> _plans = [
    {
      'name': 'Monthly Pro',
      'price': '₹199',
      'period': '/ month',
      'subtitle': 'Flexible monthly freelance billing',
      'days': 30,
      'badge': null,
    },
    {
      'name': 'Annual Pro',
      'price': '₹1,499',
      'period': '/ year',
      'subtitle': 'Just ₹125/month • Save 37%',
      'days': 365,
      'badge': 'MOST POPULAR',
    },
    {
      'name': 'Lifetime Access',
      'price': '₹2,999',
      'period': 'one-time',
      'subtitle': 'Pay once, use forever on this device',
      'days': 36500,
      'badge': 'BEST VALUE',
    },
  ];

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _launchUrlHelper(Uri uri) async {
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open: $uri')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching application: $e')),
        );
      }
    }
  }

  void _contactWhatsApp() {
    final plan = _plans[_selectedPlanIndex]['name'] as String;
    final uri = Uri.parse(ContactConstants.getWhatsAppUrl(planName: plan));
    _launchUrlHelper(uri);
  }

  void _contactPhone() {
    final uri = Uri.parse(ContactConstants.getPhoneUri());
    _launchUrlHelper(uri);
  }

  void _contactEmail() {
    final plan = _plans[_selectedPlanIndex]['name'] as String;
    final uri = Uri.parse(ContactConstants.getEmailUri(planName: plan));
    _launchUrlHelper(uri);
  }

  Future<void> _applyPromoCode() async {
    final code = _promoController.text.trim();
    if (code.isEmpty) return;

    final therapist = ref.read(authControllerProvider).therapist;
    final result = await ref
        .read(subscriptionControllerProvider.notifier)
        .activatePromo(
          code,
          email: therapist?.email,
          phone: therapist?.phone,
        );

    if (mounted) {
      if (result.type == PromoResultType.emergencyBonus) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.accentAmber,
            duration: const Duration(seconds: 4),
            content: Text(result.message, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
          ),
        );
        Navigator.pop(context);
      } else if (result.type == PromoResultType.proActivated) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.successGreen,
            duration: const Duration(seconds: 3),
            content: Text(result.message),
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.dangerRed,
            content: Text(result.message),
          ),
        );
      }
    }
  }

  Future<void> _syncWithCloudServer() async {
    final therapist = ref.read(authControllerProvider).therapist;
    if (therapist == null) return;

    final updated = await ref
        .read(subscriptionControllerProvider.notifier)
        .syncWithSupabaseServer(
          email: therapist.email,
          phone: therapist.phone,
        );

    if (mounted) {
      if (updated.isPro) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.successGreen,
            content: Text('✅ Subscription verified: ${updated.activePlanName} is active!'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Subscription status verified. No active subscription found for ${therapist.email}.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subState = ref.watch(subscriptionControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedPlan = _plans[_selectedPlanIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Physio Pro Upgrade'),
        actions: [
          if (subState.isPro)
            TextButton(
              onPressed: () async {
                await ref.read(subscriptionControllerProvider.notifier).resetToFree();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reset to Free tier for testing.')),
                  );
                }
              },
              child: const Text('Reset Free (Test)', style: TextStyle(color: Colors.grey)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card if already pro
            if (subState.isPro) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.successGreen),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified, color: AppTheme.successGreen, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subState.activePlanName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            subState.proExpiresAt != null
                                ? 'Active until ${subState.proExpiresAt!.day}/${subState.proExpiresAt!.month}/${subState.proExpiresAt!.year}'
                                : 'Active Lifetime Access',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Hero Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryTeal, AppTheme.primaryTealDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryTeal.withValues(alpha: 0.25),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'BUILT FOR PHYSIOTHERAPISTS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Elevate Your Freelance & Clinic Practice',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Generate unlimited branded treatment receipts, track patient revenue, and remove watermarks permanently.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Feature Checklist
            const Text(
              'What\'s included in Pro:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildFeatureRow('Unlimited Patient Invoices & Receipts', 'Free is limited to 5 total'),
            _buildFeatureRow('No Watermark or Free Badges', 'Clean, high-trust medical PDF branding'),
            _buildFeatureRow('Add Custom Clinic Logo & Signature', 'Seal of authenticity on every receipt'),
            _buildFeatureRow('Offline Patient History & Search', 'Never lose past bill records or dates'),
            _buildFeatureRow('Payment QR / UPI Details on Bill', 'Collect instant payments effortlessly'),
            const SizedBox(height: 24),

            // Plan Selection
            const Text(
              'Choose your plan:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            ...List.generate(_plans.length, (index) {
              final plan = _plans[index];
              final isSelected = _selectedPlanIndex == index;
              return GestureDetector(
                onTap: () => setState(() => _selectedPlanIndex = index),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryTeal.withValues(alpha: isDark ? 0.2 : 0.08)
                        : (isDark ? AppTheme.darkCardBg : Colors.white),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryTeal : AppTheme.lightBorder,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.check_circle : Icons.radio_button_off,
                        color: isSelected ? AppTheme.primaryTeal : Colors.grey,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  plan['name'] as String,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                if (plan['badge'] != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.accentAmber,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      plan['badge'] as String,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              plan['subtitle'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : AppTheme.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            plan['price'] as String,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: AppTheme.primaryTeal,
                            ),
                          ),
                          Text(
                            plan['period'] as String,
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),

            // Primary Contact Action: WhatsApp Activation
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _contactWhatsApp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.chat_bubble_outline),
                label: Text(
                  'Contact on WhatsApp (${selectedPlan['name']})',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Contact Developer Direct Cards
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCardBg : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.support_agent, color: AppTheme.primaryTeal, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Direct Subscription Support',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Contact us directly via WhatsApp, Phone, or Email for manual activation, UPI payment, or custom clinic packages.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 14),

                  // WhatsApp
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFFE8F5E9),
                      child: Icon(Icons.chat, color: Color(0xFF2E7D32), size: 18),
                    ),
                    title: const Text('WhatsApp Support', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: const Text(ContactConstants.supportWhatsApp, style: TextStyle(fontSize: 12)),
                    trailing: OutlinedButton(
                      onPressed: _contactWhatsApp,
                      child: const Text('Chat'),
                    ),
                  ),
                  const Divider(height: 1),

                  // Phone
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.primaryTeal.withValues(alpha: 0.12),
                      child: const Icon(Icons.phone, color: AppTheme.primaryTeal, size: 18),
                    ),
                    title: const Text('Phone Call', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: const Text(ContactConstants.supportPhone, style: TextStyle(fontSize: 12)),
                    trailing: OutlinedButton(
                      onPressed: _contactPhone,
                      child: const Text('Call'),
                    ),
                  ),
                  const Divider(height: 1),

                  // Email
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFFEFF6FF),
                      child: Icon(Icons.email_outlined, color: Color(0xFF1D4ED8), size: 18),
                    ),
                    title: const Text('Email Support', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: const Text(ContactConstants.supportEmail, style: TextStyle(fontSize: 12)),
                    trailing: OutlinedButton(
                      onPressed: _contactEmail,
                      child: const Text('Email'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Activation / Promo Code
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCardBg : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Have an Activation or Promo Code?',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _promoController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            hintText: 'Enter activation code',
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _applyPromoCode,
                        child: const Text('Activate'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'You will receive an activation code once your subscription payment is received.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Restore / Verify Subscription
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: _syncWithCloudServer,
                  icon: const Icon(Icons.sync, size: 18),
                  label: const Text('Restore / Verify Subscription', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, color: AppTheme.primaryTeal, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
