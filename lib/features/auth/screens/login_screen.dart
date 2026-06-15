import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/services/navigation_service.dart';
import '../widgets/auth_text_field.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Parent / Teacher
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  
  // Child
  final _childNameCtrl = TextEditingController();
  DateTime _childBirthDate = DateTime.now().subtract(const Duration(days: 365 * 6));

  bool _isChildLogin = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _childNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _childBirthDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _childBirthDate = picked;
      });
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    bool success = false;
    
    if (_isChildLogin) {
      success = await auth.loginChild(
        name: _childNameCtrl.text.trim(),
        birthDate: _childBirthDate,
      );
    } else {
      success = await auth.login(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );
    }
    
    if (success && mounted) {
      final user = auth.user;
      if (user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => NavigationService.getDashboard(user),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login succeeded but profile could not be loaded. Please try again.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Login failed'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildChildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthTextField(
          label: 'Your Name',
          hint: 'Enter your first name',
          controller: _childNameCtrl,
          prefixIcon: Icons.child_care,
          validator: (v) => v!.isEmpty ? 'Please enter your name' : null,
        ),
        const SizedBox(height: 16),
        Text('Your Birthday', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _selectDate(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade50,
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.grey),
                const SizedBox(width: 12),
                Text(
                  '${_childBirthDate.year}-${_childBirthDate.month.toString().padLeft(2,'0')}-${_childBirthDate.day.toString().padLeft(2,'0')}',
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdultForm() {
    return Column(
      children: [
        AuthTextField(
          label: 'Email',
          hint: 'your@email.com',
          controller: _emailCtrl,
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (v) => v!.isEmpty ? 'Please enter your email' : null,
        ),
        const SizedBox(height: 16),
        AuthTextField(
          label: 'Password',
          hint: 'Enter your password',
          controller: _passwordCtrl,
          prefixIcon: Icons.lock_outline,
          isPassword: true,
          validator: (v) => v!.isEmpty ? 'Please enter your password' : null,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
            child: const Text('Forgot Password?',
                style: TextStyle(color: AppColors.primary)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                // Logo & Title
                Center(
                  child: Column(
                     children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('🎮', style: TextStyle(fontSize: 44)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('QuestKids', style: AppTextStyles.h1.copyWith(color: AppColors.primary)),
                      Text('Learn. Play. Grow.', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                
                // Toggle Child/Adult
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isChildLogin = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _isChildLogin ? AppColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text('Child', 
                                style: TextStyle(
                                  color: _isChildLogin ? Colors.white : Colors.grey.shade600,
                                  fontWeight: FontWeight.bold,
                                )
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isChildLogin = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !_isChildLogin ? AppColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text('Parent / Teacher', 
                                style: TextStyle(
                                  color: !_isChildLogin ? Colors.white : Colors.grey.shade600,
                                  fontWeight: FontWeight.bold,
                                )
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                Text('Welcome Back! 👋', style: AppTextStyles.h2),
                const SizedBox(height: 8),
                Text('Sign in to continue your quest',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 32),

                if (_isChildLogin) _buildChildForm() else _buildAdultForm(),
                
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: auth.isLoading ? null : _login,
                  child: auth.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Sign In'),
                ),
                const SizedBox(height: 16),
                
                if (!_isChildLogin) ...[
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('or', style: AppTextStyles.bodySmall),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: auth.isLoading
                        ? null
                        : () async {
                            final success = await auth.signInWithGoogle(
                              role: 'parent',
                              grade: 'Grade 1',
                            );
                            if (!success && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(auth.errorMessage ?? 'Google sign-in failed'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          },
                    icon: const Text('G', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                    label: const Text('Continue with Google'),
                  ),
                ],
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account? ", style: AppTextStyles.bodyMedium),
                    GestureDetector(
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const RegisterScreen())),
                      child: Text('Sign Up',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          )),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
