import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:invoizo/core/constants/physio_presets.dart';
import 'package:invoizo/core/theme/app_theme.dart';
import 'package:invoizo/core/theme/theme_provider.dart';
import 'package:invoizo/core/utils/image_utils.dart';
import 'package:invoizo/modules/auth/controller/auth_controller.dart';
import 'package:invoizo/modules/login/model/user_model.dart';
import 'package:invoizo/modules/login/view/login_screen.dart';
import 'package:invoizo/modules/subscription/controller/subscription_controller.dart';
import 'package:invoizo/modules/subscription/view/subscription_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final therapist = ref.watch(authControllerProvider).therapist;
    final subState = ref.watch(subscriptionControllerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (therapist == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Practice Profile')),
        body: const Center(child: Text('No practice profile found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Practice & Settings'),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            onPressed: () => ref.read(themeProvider.notifier).toggle(),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Logout',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          children: [
            // Subscription Card
            _buildSubscriptionCard(subState, isDark, therapist),
            const SizedBox(height: 16),

            // Profile Header Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 46,
                          backgroundColor: AppTheme.primaryTeal.withValues(alpha: 0.15),
                          backgroundImage: therapist.logoPath != null &&
                                  therapist.logoPath!.isNotEmpty &&
                                  File(therapist.logoPath!).existsSync()
                              ? FileImage(File(therapist.logoPath!))
                              : null,
                          child: (therapist.logoPath == null ||
                                  therapist.logoPath!.isEmpty ||
                                  !File(therapist.logoPath!).existsSync())
                              ? const Icon(Icons.medical_services, size: 42, color: AppTheme.primaryTeal)
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      therapist.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (therapist.clinicName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        therapist.clinicName,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryTeal),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      therapist.qualification,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Reg #: ${therapist.registrationNumber}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditProfileScreen(therapist: therapist),
                            ),
                          );
                          setState(() {});
                        },
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit Practice Details'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Details List Card
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    _buildInfoTile(Icons.work_outline, 'Practice Type', therapist.practiceType),
                    const Divider(height: 1),
                    _buildInfoTile(Icons.phone_outlined, 'Contact Phone', therapist.phone),
                    const Divider(height: 1),
                    _buildInfoTile(Icons.email_outlined, 'Email Address', therapist.email.isNotEmpty ? therapist.email : 'Not specified'),
                    const Divider(height: 1),
                    _buildInfoTile(Icons.qr_code, 'UPI ID', therapist.upiId != null && therapist.upiId!.isNotEmpty ? therapist.upiId! : 'Not set'),
                    const Divider(height: 1),
                    _buildInfoTile(Icons.location_on_outlined, 'Address / Territory', therapist.address ?? 'Not specified'),
                    const Divider(height: 1),
                    _buildInfoTile(Icons.access_time_outlined, 'Consultation Hours', therapist.workHours),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.headset_mic_outlined, color: AppTheme.primaryTeal),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Subscription & App Support', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('WhatsApp / Call: +91 9645808999', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                        );
                      },
                      child: const Text('Support'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // App Branding & Info (Light / Dark mode aware)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                isDark ? 'assets/icons/logo_dark.png' : 'assets/icons/logo_light.png',
                height: 44,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'PhysioTally v1.0.2 • Invoicing for Physiotherapists',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard(dynamic subState, bool isDark, Therapist therapist) {
    final isPro = subState.isPro;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPro
              ? [const Color(0xFF0F766E), const Color(0xFF115E59)]
              : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPro ? Colors.white.withValues(alpha: 0.2) : AppTheme.accentAmber,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isPro ? '⭐ PHYSIO PRO' : 'FREE PLAN',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isPro ? Colors.white : Colors.black,
                  ),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.sync, color: Colors.white, size: 20),
                    tooltip: 'Sync Subscription Status',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () async {
                      final updated = await ref
                          .read(subscriptionControllerProvider.notifier)
                          .syncWithSupabaseServer(
                            email: therapist.email,
                            phone: therapist.phone,
                            userId: therapist.id,
                          );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppTheme.primaryTeal,
                            content: Text(
                              updated.isPro
                                  ? '✅ Subscription verified: ${updated.activePlanName} is active!'
                                  : '✅ Subscription state synced with cloud.',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                      );
                    },
                    child: Text(
                      isPro ? 'Manage' : 'Upgrade Plan',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isPro ? subState.activePlanName : '5 Free Invoices Quota',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isPro
                ? (subState.proExpiresAt != null
                    ? 'Active until ${subState.proExpiresAt!.day}/${subState.proExpiresAt!.month}/${subState.proExpiresAt!.year}'
                    : 'Unlimited Lifetime Access')
                : '${subState.remainingFreeInvoices} of ${subState.freeQuota} free receipts left on this device.',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryTeal),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out?'),
        content: const Text('You will need to set up or verify your credentials again upon logging in.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authControllerProvider.notifier).logout();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Log Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class EditProfileScreen extends ConsumerStatefulWidget {
  final Therapist therapist;
  const EditProfileScreen({super.key, required this.therapist});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _clinicNameController;
  late TextEditingController _qualificationController;
  late TextEditingController _regController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _upiController;
  late TextEditingController _addressController;
  late TextEditingController _workHoursController;

  late String _practiceType;
  String? _logoPath;
  String? _signaturePath;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.therapist.name);
    _clinicNameController = TextEditingController(text: widget.therapist.clinicName);
    _qualificationController = TextEditingController(text: widget.therapist.qualification);
    _regController = TextEditingController(text: widget.therapist.registrationNumber);
    _phoneController = TextEditingController(text: widget.therapist.phone);
    _emailController = TextEditingController(text: widget.therapist.email);
    _upiController = TextEditingController(text: widget.therapist.upiId ?? '');
    _addressController = TextEditingController(text: widget.therapist.address ?? '');
    _workHoursController = TextEditingController(text: widget.therapist.workHours);
    _practiceType = widget.therapist.practiceType;
    _logoPath = widget.therapist.logoPath;
    _signaturePath = widget.therapist.signaturePath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _clinicNameController.dispose();
    _qualificationController.dispose();
    _regController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _upiController.dispose();
    _addressController.dispose();
    _workHoursController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 75,
    );
    if (picked != null) {
      setState(() => _logoPath = picked.path);
    }
  }

  Future<void> _pickSignature() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 250,
      imageQuality: 75,
    );
    if (picked != null) {
      setState(() => _signaturePath = picked.path);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final logoB64 = await ImageUtils.fileToBase64(_logoPath);
    final sigB64 = await ImageUtils.fileToBase64(_signaturePath);

    final updated = widget.therapist.copyWith(
      name: _nameController.text.trim(),
      clinicName: _clinicNameController.text.trim(),
      practiceType: _practiceType,
      qualification: _qualificationController.text.trim(),
      registrationNumber: _regController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      upiId: _upiController.text.trim(),
      address: _addressController.text.trim(),
      workHours: _workHoursController.text.trim(),
      logoPath: _logoPath,
      signaturePath: _signaturePath,
      logoBase64: logoB64 ?? widget.therapist.logoBase64,
      signatureBase64: sigB64 ?? widget.therapist.signatureBase64,
    );

    await ref.read(authControllerProvider.notifier).updateTherapist(updated);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.successGreen,
          content: Text('Profile updated successfully!'),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Practice Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Logo & Signature Pickers
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GestureDetector(
                    onTap: _pickLogo,
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: _logoPath != null && File(_logoPath!).existsSync()
                              ? FileImage(File(_logoPath!))
                              : null,
                          child: _logoPath == null
                              ? const Icon(Icons.add_photo_alternate, color: AppTheme.primaryTeal)
                              : null,
                        ),
                        const SizedBox(height: 6),
                        const Text('Clinic Logo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _pickSignature,
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: _signaturePath != null && File(_signaturePath!).existsSync()
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(File(_signaturePath!), fit: BoxFit.contain),
                                )
                              : const Icon(Icons.gesture, color: AppTheme.primaryTeal),
                        ),
                        const SizedBox(height: 6),
                        const Text('Signature', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name *'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _clinicNameController,
                decoration: const InputDecoration(labelText: 'Clinic / Practice Name'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _practiceType,
                decoration: const InputDecoration(labelText: 'Practice Type'),
                items: PhysioPresets.practiceTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(
                      type,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _practiceType = val);
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _qualificationController,
                decoration: const InputDecoration(labelText: 'Qualifications *'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _regController,
                decoration: const InputDecoration(labelText: 'Registration Number *'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone *'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _upiController,
                decoration: const InputDecoration(labelText: 'UPI ID (For Patient Payments)'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Clinic Address / Territory'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _workHoursController,
                decoration: const InputDecoration(labelText: 'Work / Consultation Hours'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _save,
                  child: const Text('Save Practice Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
