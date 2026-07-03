import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/services/navigation_service.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/role_selector.dart';
import '../widgets/grade_selector.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Basic Details
  final _nameCtrl = TextEditingController();
  final _surnameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  String _title = 'Mr';
  String _gender = 'Male';
  String _role = 'parent';

  // Teacher
  String _teacherGrade = 'Grade 1';

  // Parent
  final _childNameCtrl = TextEditingController();
  String _childGender = 'Male';
  DateTime _childBirthDate =
      DateTime.now().subtract(const Duration(days: 365 * 6));
  String _childGrade = 'Grade 1';
  final String _relationToChild = 'Father';
  String _parentRole = 'mother'; // mother, father, guardian
  bool _registerChild = true;
  bool _consentGiven = false; // POPIA parent/guardian consent

  int _step =
      0; // 0 = role, 1 = details, 2 = child details (if parent), 3 = teacher details

  @override
  void dispose() {
    _nameCtrl.dispose();
    _surnameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
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

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_role == 'parent' && _registerChild && !_consentGiven) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please confirm parent/guardian consent to continue.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    bool success = false;

    if (_role == 'teacher') {
      success = await auth.registerTeacher(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
        surname: _surnameCtrl.text.trim(),
        title: _title,
        gender: _gender,
        grade: _teacherGrade,
      );
    } else {
      if (_registerChild) {
        success = await auth.registerParent(
          parentEmail: _emailCtrl.text.trim(),
          parentPassword: _passwordCtrl.text.trim(),
          parentName: _nameCtrl.text.trim(),
          parentSurname: _surnameCtrl.text.trim(),
          parentTitle: _title,
          parentGender: _gender,
          relationToChild: _relationToChild,
          childName: _childNameCtrl.text.trim(),
          childGender: _childGender,
          childBirthDate: _childBirthDate,
          childGrade: _childGrade,
          childConsentGiven: _consentGiven,
        );
      } else {
        success = await auth.registerParent(
          parentEmail: _emailCtrl.text.trim(),
          parentPassword: _passwordCtrl.text.trim(),
          parentName: _nameCtrl.text.trim(),
          parentSurname: _surnameCtrl.text.trim(),
          parentTitle: _title,
          parentGender: _gender,
          relationToChild: _relationToChild,
        );
      }
    }

    if (success && mounted) {
      // Navigate to role-based dashboard on success
      final user = auth.user;
      if (user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => NavigationService.getDashboard(user),
          ),
        );
      }
    } else if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Registration failed'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildStep0() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Your Role', style: AppTextStyles.h2),
        const SizedBox(height: 8),
        Text('Choose how you will use QuestKids',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 32),
        RoleSelector(
          selectedRole: _role,
          onRoleChanged: (r) => setState(() => _role = r),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () => setState(() => _step = 1),
          child: const Text('Next →'),
        ),
      ],
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Your Details', style: AppTextStyles.h2),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 1,
              child: DropdownButtonFormField<String>(
                initialValue: _title,
                decoration: const InputDecoration(labelText: 'Title'),
                items: ['Mr', 'Mrs', 'Ms', 'Dr']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _title = v!),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                initialValue: _gender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: ['Male', 'Female', 'Other']
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (v) => setState(() => _gender = v!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AuthTextField(
          label: 'First Name',
          hint: 'Enter your name',
          controller: _nameCtrl,
          prefixIcon: Icons.person_outline,
          validator: (v) => v!.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        AuthTextField(
          label: 'Surname',
          hint: 'Enter your surname',
          controller: _surnameCtrl,
          prefixIcon: Icons.person_outline,
          validator: (v) => v!.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        AuthTextField(
          label: 'Email',
          hint: 'your@email.com',
          controller: _emailCtrl,
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (v) => v!.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        AuthTextField(
          label: 'Password',
          hint: 'Min 6 characters',
          controller: _passwordCtrl,
          prefixIcon: Icons.lock_outline,
          isPassword: true,
          validator: (v) => v!.length < 6 ? 'Min 6 chars' : null,
        ),
        const SizedBox(height: 16),
        AuthTextField(
          label: 'Confirm Password',
          hint: 'Re-enter password',
          controller: _confirmCtrl,
          prefixIcon: Icons.lock_outline,
          isPassword: true,
          validator: (v) => v != _passwordCtrl.text ? 'Mismatch' : null,
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              setState(() => _step = _role == 'parent' ? 2 : 3);
            }
          },
          child: const Text('Next →'),
        ),
      ],
    );
  }

  Widget _buildStep2Parent() {
    final auth = context.watch<AuthProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Child Details', style: AppTextStyles.h2),
        const SizedBox(height: 16),
        Text('Your Role', style: AppTextStyles.bodyMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _parentRole = 'mother'),
                child: Card(
                  color: _parentRole == 'mother'
                      ? AppColors.primary
                      : Colors.white,
                  child: const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Column(children: [
                      Text('👩'),
                      SizedBox(height: 8),
                      Text('Mother')
                    ]),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _parentRole = 'father'),
                child: Card(
                  color: _parentRole == 'father'
                      ? AppColors.primary
                      : Colors.white,
                  child: const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Column(children: [
                      Text('👨'),
                      SizedBox(height: 8),
                      Text('Father')
                    ]),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _parentRole = 'guardian'),
                child: Card(
                  color: _parentRole == 'guardian'
                      ? AppColors.primary
                      : Colors.white,
                  child: const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Column(children: [
                      Text('🧑'),
                      SizedBox(height: 8),
                      Text('Guardian')
                    ]),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(child: Text('Register your child now?')),
            Switch(
              value: _registerChild,
              onChanged: (v) => setState(() => _registerChild = v),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_registerChild) ...[
          AuthTextField(
            label: 'Child First Name',
            hint: 'Child\'s name',
            controller: _childNameCtrl,
            prefixIcon: Icons.child_care,
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _childGender,
                  decoration: const InputDecoration(labelText: 'Child Gender'),
                  items: ['Male', 'Female', 'Other']
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) => setState(() => _childGender = v!),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectDate(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                        '${_childBirthDate.year}-${_childBirthDate.month}-${_childBirthDate.day}'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GradeSelector(
            selectedGrade: _childGrade,
            onGradeChanged: (g) => setState(() => _childGrade = g),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _consentGiven,
            onChanged: (v) => setState(() => _consentGiven = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: Text(
              "I am this child's parent or legal guardian and I consent to "
              'their QuestKids account and to QuestKids collecting and '
              'processing their learning data, in line with our Privacy '
              'Policy (POPIA).',
              style: AppTextStyles.bodySmall,
            ),
          ),
          const SizedBox(height: 8),
        ] else ...[
          Card(
            color: AppColors.surface,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                  'You can link your child later from your dashboard using their Link Code or QR code.',
                  style: AppTextStyles.bodyMedium),
            ),
          ),
          const SizedBox(height: 24),
        ],
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: (auth.isLoading || (_registerChild && !_consentGiven))
              ? null
              : _register,
          child: auth.isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Create Accounts 🚀'),
        ),
      ],
    );
  }

  Widget _buildStep3Teacher() {
    final auth = context.watch<AuthProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Class Details', style: AppTextStyles.h2),
        const SizedBox(height: 16),
        GradeSelector(
          selectedGrade: _teacherGrade,
          onGradeChanged: (g) => setState(() => _teacherGrade = g),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: auth.isLoading ? null : _register,
          child: auth.isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Create Account 🚀'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () {
            if (_step == 0) {
              Navigator.pop(context);
            } else if (_step == 3) {
              setState(() => _step = 1);
            } else {
              setState(() => _step -= 1);
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: () {
              if (_step == 0) return _buildStep0();
              if (_step == 1) return _buildStep1();
              if (_step == 2) return _buildStep2Parent();
              if (_step == 3) return _buildStep3Teacher();
              return const SizedBox();
            }(),
          ),
        ),
      ),
    );
  }
}
