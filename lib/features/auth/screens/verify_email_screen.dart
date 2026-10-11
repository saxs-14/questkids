import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/services/navigation_service.dart';
import '../../../providers/auth_provider.dart';

/// Blocking gate shown to a parent whose email isn't verified yet --
/// reached right after registration, and again on sign-in if they closed
/// the app before finishing it (see NavigationService.getDashboard).
/// Sends the first code on open, reusing the same requestActionOtp /
/// verifyRegistrationEmail pair documented in functions/src/parent/actionOtp.ts.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _codeCtrl = TextEditingController();
  bool _sendingCode = true;
  bool _submitting = false;
  String? _error;
  int _resendCooldownSeconds = 0;

  @override
  void initState() {
    super.initState();
    _requestCode();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    setState(() {
      _sendingCode = true;
      _error = null;
    });
    try {
      await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('requestActionOtp')
          .call({'action': 'verifyEmail'});
      if (mounted) _startResendCooldown();
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() => _error = e.message ?? 'Could not send a verification code.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not send a verification code. Check your connection.');
      }
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  void _startResendCooldown() {
    setState(() => _resendCooldownSeconds = 60);
    Future<void> tick() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      if (_resendCooldownSeconds <= 1) {
        setState(() => _resendCooldownSeconds = 0);
        return;
      }
      setState(() => _resendCooldownSeconds -= 1);
      await tick();
    }
    tick();
  }

  Future<void> _verify() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from your email.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('verifyRegistrationEmail')
          .call({'otpCode': code});
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      auth.markEmailVerified();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => NavigationService.getDashboard(auth.user!)),
      );
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = e.message ?? 'Verification failed. Please try again.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'Something went wrong. Please try again.';
        });
      }
    }
  }

  Future<void> _signOut() async {
    await context.read<AuthProvider>().signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = context.watch<AuthProvider>().user?.email ?? 'your email';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Your Email'),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Sign out',
          onPressed: _submitting ? null : _signOut,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.mark_email_unread_outlined, size: 72, color: AppColors.primary),
              const SizedBox(height: 24),
              Text('One more step', style: AppTextStyles.h2, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                'We sent a 6-digit code to $email. Enter it below to finish setting up your account.',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (_sendingCode)
                const Center(child: CircularProgressIndicator())
              else
                TextField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h3,
                  decoration: const InputDecoration(
                    labelText: '6-digit code',
                    counterText: '',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _verify(),
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.error), textAlign: TextAlign.center),
              ],
              const SizedBox(height: 16),
              TextButton(
                onPressed: _resendCooldownSeconds > 0 || _sendingCode ? null : _requestCode,
                child: Text(
                  _resendCooldownSeconds > 0
                      ? 'Resend code in ${_resendCooldownSeconds}s'
                      : 'Resend code',
                ),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Verify',
                isLoading: _submitting,
                onPressed: _submitting || _sendingCode ? null : _verify,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
