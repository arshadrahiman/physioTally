import 'package:flutter/material.dart';
import 'package:invoizo/core/constants/contact_constants.dart';
import 'package:invoizo/core/theme/app_theme.dart';
import 'package:invoizo/modules/subscription/view/subscription_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class PaywallSheet extends StatelessWidget {
  final String title;
  final String message;

  const PaywallSheet({
    super.key,
    this.title = 'Free Quota Reached',
    this.message =
        'You have used your 5 free physiotherapy receipts. Upgrade to Physio Pro for unlimited patient invoicing, removing watermarks, and adding your clinic logo.',
  });

  static Future<void> show(
    BuildContext context, {
    String title = 'Free Limit Reached (5/5 Used)',
    String message =
        'You have reached your 5 free receipts limit. Upgrade to Physio Pro to generate unlimited bills and receipts.',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => PaywallSheet(title: title, message: message),
    );
  }

  Future<void> _openWhatsApp() async {
    final uri = Uri.parse(ContactConstants.getWhatsAppUrl(planName: 'Annual Pro'));
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryTeal.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.workspace_premium,
              color: AppTheme.primaryTeal,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 20),

          // Primary Button: View Plans
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                );
              },
              child: const Text(
                'View Plans & Activation Details',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Quick WhatsApp button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _openWhatsApp();
              },
              icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
              label: const Text(
                'Chat on WhatsApp (+91 9645808999)',
                style: TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 8),

          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}
