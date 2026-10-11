import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/otp_verification_dialog.dart';
import '../../../core/services/navigation_service.dart';
import '../../../providers/auth_provider.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.loginAdmin(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;
    if (!success || auth.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Admin authentication failed.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Email/password alone isn't enough for the most privileged role in
    // the app -- a second factor is required before the portal opens.
    // loginAdmin already fully authenticated this session in Firebase
    // Auth, so a cancelled/failed code must sign back out rather than
    // leave a live admin session sitting on the login screen.
    final verified = await OtpVerificationDialog.show(
      context,
      action: 'adminLogin',
      targetId: auth.user!.email,
      title: 'Verify It\'s You',
      message: 'For admin accounts, we also send a code to your email. Enter it to finish signing in.',
      onSubmit: (otpCode) async {
        await FirebaseFunctions.instanceFor(region: 'us-central1')
            .httpsCallable('verifyAdminLoginOtp')
            .call({'otpCode': otpCode});
      },
    );
    if (!mounted) return;
    if (!verified) {
      await auth.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Admin sign-in cancelled.')),
        );
      }
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => NavigationService.getDashboard(auth.user!)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('QuestKids Admin Portal')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: dark ? AppColors.cardDark : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.admin_panel_settings_rounded, size: 64, color: AppColors.primary),
                          const SizedBox(height: 16),
                          Text('Secure Administration', style: AppTextStyles.h2),
                          const SizedBox(height: 8),
                          Text(
                            'This portal is only for authorised QuestKids administrators. '
                            'Admin access is verified from the Firebase admin role claim; '
                            'a normal parent or child account cannot enter the portal.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Admin email', prefixIcon: Icon(Icons.email_outlined)),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Enter the admin email.' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
                      validator: (value) => value == null || value.isEmpty ? 'Enter the admin password.' : null,
                    ),
                    const SizedBox(height: 24),
                    AppButton(label: 'Enter Admin Portal', isLoading: auth.isLoading, onPressed: _signIn),
                    const SizedBox(height: 16),
                    Text(
                      'Admin accounts are provisioned by an existing administrator. There is no public admin registration.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
