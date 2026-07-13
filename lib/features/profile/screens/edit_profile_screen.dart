import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/app_button.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../auth/widgets/grade_selector.dart';

class EditProfileScreen extends StatefulWidget {
  final String initialName;
  final String initialSurname;
  final String initialGrade;
  final String initialLanguage;

  const EditProfileScreen({
    super.key,
    required this.initialName,
    required this.initialSurname,
    required this.initialGrade,
    required this.initialLanguage,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const _saLanguages = [
    'English',
    'Afrikaans',
    'isiZulu',
    'isiXhosa',
    'siSwati',
    'isiNdebele',
    'Sesotho',
    'Northern Sotho',
    'Setswana',
    'Tshivenda',
    'Xitsonga',
  ];

  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.initialName);
  late final _surnameCtrl = TextEditingController(text: widget.initialSurname);
  late String _grade = widget.initialGrade;
  late String _language = widget.initialLanguage;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _surnameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid != null) {
      await UserRepository().updateUser(uid, {
        'name': _nameCtrl.text.trim(),
        'surname': _surnameCtrl.text.trim(),
        'grade': _grade,
        'preferredLanguage': _language,
      });
    }
    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'First Name'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _surnameCtrl,
                  decoration: const InputDecoration(labelText: 'Surname'),
                ),
                const SizedBox(height: 16),
                GradeSelector(
                  selectedGrade: _grade,
                  onGradeChanged: (g) => setState(() => _grade = g),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _language,
                  decoration:
                      const InputDecoration(labelText: 'Preferred Language'),
                  items: _saLanguages
                      .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _language = v);
                  },
                ),
                const SizedBox(height: 32),
                AppButton(
                  label: 'Save Changes',
                  isLoading: _saving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
