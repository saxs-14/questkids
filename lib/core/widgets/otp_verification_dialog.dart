import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Step-up email-code verification for a sensitive action (see
/// functions/src/parent/actionOtp.ts). Sends a code via requestActionOtp
/// as soon as the dialog opens, lets the user enter it, then calls
/// [onSubmit] with the code -- [onSubmit] should perform the actual
/// protected action and rethrow on failure. A wrong/expired code just
/// re-shows the entry field with an error instead of closing the dialog,
/// so the user can retry or request a new code without starting over.
class OtpVerificationDialog {
  static Future<bool> show(
    BuildContext context, {
    required String action,
    required String title,
    required String message,
    required Future<void> Function(String otpCode) onSubmit,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _OtpDialogContent(
        action: action,
        title: title,
        message: message,
        onSubmit: onSubmit,
      ),
    );
    return result ?? false;
  }
}

class _OtpDialogContent extends StatefulWidget {
  final String action;
  final String title;
  final String message;
  final Future<void> Function(String otpCode) onSubmit;

  const _OtpDialogContent({
    required this.action,
    required this.title,
    required this.message,
    required this.onSubmit,
  });

  @override
  State<_OtpDialogContent> createState() => _OtpDialogContentState();
}

class _OtpDialogContentState extends State<_OtpDialogContent> {
  final _codeController = TextEditingController();
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
    _codeController.dispose();
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
          .call({'action': widget.action});
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

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from your email.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onSubmit(code);
      if (mounted) Navigator.of(context).pop(true);
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title, style: AppTextStyles.h4),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message, style: AppTextStyles.bodyMedium),
          const SizedBox(height: 16),
          if (_sendingCode)
            const Center(child: Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(),
            ))
          else
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '6-digit code',
                counterText: '',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.error)),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: _resendCooldownSeconds > 0 || _sendingCode ? null : _requestCode,
            child: Text(
              _resendCooldownSeconds > 0
                  ? 'Resend code in ${_resendCooldownSeconds}s'
                  : 'Resend code',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitting || _sendingCode ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Verify'),
        ),
      ],
    );
  }
}
