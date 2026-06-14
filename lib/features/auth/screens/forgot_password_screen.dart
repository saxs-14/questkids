import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_emailCtrl.text.isEmpty) return;
    final auth = context.read<AuthProvider>();
    await auth.resetPassword(_emailCtrl.text.trim());
    if (mounted) setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _sent
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('📧', style: TextStyle(fontSize: 80)),
                    const SizedBox(height: 24),
                    Text('Email Sent!', style: AppTextStyles.h2),
                    const SizedBox(height: 12),
                    Text(
                      'Check your inbox for a password reset link.',
                      style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Back to Login'),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),
                    const Text('🔐', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 24),
                    Text('Forgot Password?', style: AppTextStyles.h2),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your email and we will send you a reset link.',
                      style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 32),
                    AuthTextField(
                      label: 'Email',
                      hint: 'your@email.com',
                      controller: _emailCtrl,
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: auth.isLoading ? null : _send,
                      child: auth.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Send Reset Link'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
