import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:invoizo/core/constants/physio_presets.dart';
import 'package:invoizo/core/theme/app_theme.dart';
import 'package:invoizo/modules/auth/controller/auth_controller.dart';
import 'package:invoizo/modules/home/view/home_scaffold.dart';
import 'package:invoizo/modules/login/model/user_model.dart';
import 'package:invoizo/modules/subscription/controller/subscription_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _signInFormKey = GlobalKey<FormState>();
  final _signUpFormKey = GlobalKey<FormState>();

  // Mode: false = Sign In, true = Register Practice
  bool _isSignUpMode = false;
  bool _isLoading = false;

  // Sign In Controllers
  final _signInEmailController = TextEditingController();
  final _signInPasswordController = TextEditingController();
  bool _isSignInPasswordObscured = true;

  // Register Controllers
  final _signUpEmailController = TextEditingController();
  final _signUpPasswordController = TextEditingController();
  bool _isSignUpPasswordObscured = true;

  final _nameController = TextEditingController();
  final _clinicNameController = TextEditingController();
  final _qualificationController = TextEditingController();
  final _regNumberController = TextEditingController();
  final _phoneController = TextEditingController();
  final _upiIdController = TextEditingController();
  final _addressController = TextEditingController();
  final _workHoursController = TextEditingController(text: '9:00 AM - 7:00 PM');

  String _practiceType = 'Freelance / Home Visit Physiotherapist';
  File? _logoFile;

  @override
  void dispose() {
    _signInEmailController.dispose();
    _signInPasswordController.dispose();
    _signUpEmailController.dispose();
    _signUpPasswordController.dispose();
    _nameController.dispose();
    _clinicNameController.dispose();
    _qualificationController.dispose();
    _regNumberController.dispose();
    _phoneController.dispose();
    _upiIdController.dispose();
    _addressController.dispose();
    _workHoursController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 75,
    );
    if (pickedFile != null) {
      setState(() {
        _logoFile = File(pickedFile.path);
      });
    }
  }

  // ==========================================
  // SIGN IN FLOW
  // ==========================================
  Future<void> _handleSignIn() async {
    if (!_signInFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _signInEmailController.text.trim();
      final password = _signInPasswordController.text;

      final result = await ref.read(authControllerProvider.notifier).signIn(
            email: email,
            password: password,
          );

      if (!mounted) return;

      if (result.isSuccess) {
        final therapist = ref.read(authControllerProvider).therapist;
        if (therapist != null) {
          // Immediately sync subscription state
          ref.read(subscriptionControllerProvider.notifier).syncWithSupabaseServer(
                email: therapist.email,
                phone: therapist.phone,
                userId: therapist.id,
              );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.successGreen,
            content: Text(
              therapist != null && therapist.name.isNotEmpty
                  ? 'Welcome back, ${therapist.name}!'
                  : 'Signed in successfully!',
            ),
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScaffold()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.dangerRed,
            content: Text(result.message),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.dangerRed,
            content: Text('Sign in failed: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================================
  // REGISTER / SIGN UP FLOW
  // ==========================================
  Future<void> _handleSignUp() async {
    if (!_signUpFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _signUpEmailController.text.trim();
      final password = _signUpPasswordController.text;

      final therapist = Therapist(
        name: _nameController.text.trim(),
        clinicName: _clinicNameController.text.trim(),
        practiceType: _practiceType,
        qualification: _qualificationController.text.trim(),
        registrationNumber: _regNumberController.text.trim(),
        phone: _phoneController.text.trim(),
        email: email,
        upiId: _upiIdController.text.trim(),
        workHours: _workHoursController.text.trim(),
        logoPath: _logoFile?.path,
        address: _addressController.text.trim(),
      );

      final result = await ref.read(authControllerProvider.notifier).signUp(
            email: email,
            password: password,
            therapist: therapist,
          );

      if (!mounted) return;

      if (result.isSuccess) {
        final savedTherapist = ref.read(authControllerProvider).therapist ?? therapist;
        // Sync subscription state
        ref.read(subscriptionControllerProvider.notifier).syncWithSupabaseServer(
              email: savedTherapist.email,
              phone: savedTherapist.phone,
              userId: savedTherapist.id,
            );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.successGreen,
            content: Text(result.message),
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScaffold()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.dangerRed,
            content: Text(result.message),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.dangerRed,
            content: Text('Registration note: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.primaryTealDark, AppTheme.primaryTeal],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Official Logo
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            isDark ? 'assets/icons/logo_dark.png' : 'assets/icons/logo_light.png',
                            height: 72,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: Text(
                          _isSignUpMode
                              ? 'Set up your practice profile & cloud sync'
                              : 'Sign in to access your practice & patient receipts',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Segmented Mode Switcher (Sign In vs Register Practice)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if (_isSignUpMode) setState(() => _isSignUpMode = false);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: !_isSignUpMode
                                        ? AppTheme.primaryTeal
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Sign In',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: !_isSignUpMode ? Colors.white : Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if (!_isSignUpMode) setState(() => _isSignUpMode = true);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _isSignUpMode
                                        ? AppTheme.primaryTeal
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Register Practice',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: _isSignUpMode ? Colors.white : Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Animated View based on mode
                      if (!_isSignUpMode) _buildSignInForm() else _buildSignUpForm(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // SIGN IN VIEW
  // ==========================================
  Widget _buildSignInForm() {
    return Form(
      key: _signInFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _signInEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email Address *',
              hintText: 'e.g. physio@example.com',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email address';
              return null;
            },
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _signInPasswordController,
            obscureText: _isSignInPasswordObscured,
            decoration: InputDecoration(
              labelText: 'Password *',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _isSignInPasswordObscured ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () =>
                    setState(() => _isSignInPasswordObscured = !_isSignInPasswordObscured),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 22),

          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSignIn,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'SIGN IN TO PRACTICE',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text("Don't have a practice account? ", style: TextStyle(fontSize: 12)),
              TextButton(
                onPressed: () => setState(() => _isSignUpMode = true),
                child: const Text('Register Practice', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SIGN UP / REGISTER FORM
  // ==========================================
  Widget _buildSignUpForm() {
    return Form(
      key: _signUpFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo / Stamp Picker
          Center(
            child: GestureDetector(
              onTap: _pickLogo,
              child: Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border.all(color: AppTheme.primaryTeal, width: 1.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _logoFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(_logoFile!, fit: BoxFit.cover),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate, color: AppTheme.primaryTeal),
                          SizedBox(height: 4),
                          Text(
                            'Clinic Logo',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryTeal,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Account Credentials
          TextFormField(
            controller: _signUpEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email Address (For Account & Cloud Sync) *',
              hintText: 'e.g. physio@example.com',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email address';
              return null;
            },
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _signUpPasswordController,
            obscureText: _isSignUpPasswordObscured,
            decoration: InputDecoration(
              labelText: 'Create Password *',
              hintText: 'Minimum 6 characters',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _isSignUpPasswordObscured ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () =>
                    setState(() => _isSignUpPasswordObscured = !_isSignUpPasswordObscured),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),

          // Practitioner Full Name
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Full Name with Title *',
              hintText: 'e.g. Dr. Rajesh Kumar, PT',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Practitioner name is required' : null,
          ),
          const SizedBox(height: 12),

          // Clinic / Practice Name
          TextFormField(
            controller: _clinicNameController,
            decoration: const InputDecoration(
              labelText: 'Clinic / Practice Name',
              hintText: 'e.g. Apex Physio Rehab / Freelance Home Visit',
              prefixIcon: Icon(Icons.local_hospital_outlined),
            ),
          ),
          const SizedBox(height: 12),

          // Practice Type
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _practiceType,
            decoration: const InputDecoration(
              labelText: 'Practice Type',
              prefixIcon: Icon(Icons.work_outline),
            ),
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
          const SizedBox(height: 12),

          // Qualifications
          TextFormField(
            controller: _qualificationController,
            decoration: const InputDecoration(
              labelText: 'Qualifications *',
              hintText: 'e.g. BPT, MPT (Ortho), MIAP',
              prefixIcon: Icon(Icons.school_outlined),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Qualifications required' : null,
          ),
          const SizedBox(height: 12),

          // Registration Number
          TextFormField(
            controller: _regNumberController,
            decoration: const InputDecoration(
              labelText: 'Council / Registration Number *',
              hintText: 'e.g. PT-2023-4567 / IAP-8910',
              prefixIcon: Icon(Icons.verified_user_outlined),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Registration number required' : null,
          ),
          const SizedBox(height: 12),

          // Phone
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Contact Phone Number *',
              hintText: 'e.g. +91 98765 43210',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Phone number required' : null,
          ),
          const SizedBox(height: 12),

          // UPI ID
          TextFormField(
            controller: _upiIdController,
            decoration: const InputDecoration(
              labelText: 'UPI ID for Patient Payments (Optional)',
              hintText: 'e.g. therapist@okaxis / 9876543210@upi',
              prefixIcon: Icon(Icons.qr_code),
            ),
          ),
          const SizedBox(height: 12),

          // Address
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Clinic Address / Territory Served',
              hintText: 'e.g. 2nd Floor, City Center / Home Visits South Zone',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 12),

          // Consultation Hours
          TextFormField(
            controller: _workHoursController,
            decoration: const InputDecoration(
              labelText: 'Consultation Hours',
              hintText: 'e.g. 9:00 AM - 7:00 PM',
              prefixIcon: Icon(Icons.access_time_outlined),
            ),
          ),
          const SizedBox(height: 22),

          // Submit
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSignUp,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'REGISTER PRACTICE & START INVOICING',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
            ),
          ),
          const SizedBox(height: 14),

          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Already have an account? ', style: TextStyle(fontSize: 12)),
              TextButton(
                onPressed: () => setState(() => _isSignUpMode = false),
                child: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
