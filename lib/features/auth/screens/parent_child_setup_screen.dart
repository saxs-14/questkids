import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/grade_selector.dart';

class ParentChildSetupScreen extends StatefulWidget {
  const ParentChildSetupScreen({super.key});

  @override
  State<ParentChildSetupScreen> createState() => _ParentChildSetupScreenState();
}

class _ParentChildSetupScreenState extends State<ParentChildSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _childNameCtrl = TextEditingController();
  String _childGender = 'Male';
  DateTime _childBirthDate =
      DateTime.now().subtract(const Duration(days: 365 * 6));
  String _childGrade = 'Grade 1';
  bool _consentGiven = false; // POPIA parent/guardian consent

  bool _isProcessing = false;

  @override
  void dispose() {
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
    if (picked != null) setState(() => _childBirthDate = picked);
  }

  Future<void> _registerChild() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_consentGiven) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Please confirm parent/guardian consent to continue.')),
      );
      return;
    }
    setState(() => _isProcessing = true);
    final auth = context.read<AuthProvider>();
    // assume current user is parent
    final parent = auth.user;
    if (parent == null) return;
    final success = await auth.createChildForParent(
      parentUid: parent.uid,
      childName: _childNameCtrl.text.trim(),
      childGender: _childGender,
      childBirthDate: _childBirthDate,
      childGrade: _childGrade,
      consentGiven: _consentGiven,
      consentGivenBy: parent.displayName,
      consentEmail: parent.email,
    );

    setState(() => _isProcessing = false);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Child created and linked successfully')));
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create child')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add or Link a Child')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add a New Child', style: AppTextStyles.h2),
              const SizedBox(height: 12),
              Form(
                key: _formKey,
                child: Column(children: [
                  AuthTextField(
                    label: 'Child First Name',
                    hint: 'Child\'s name',
                    controller: _childNameCtrl,
                    prefixIcon: Icons.child_care,
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _childGender,
                        decoration: const InputDecoration(labelText: 'Gender'),
                        items: ['Male', 'Female', 'Other']
                            .map((g) =>
                                DropdownMenuItem(value: g, child: Text(g)))
                            .toList(),
                        onChanged: (v) => setState(() => _childGender = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
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
                  ]),
                  const SizedBox(height: 12),
                  GradeSelector(
                      selectedGrade: _childGrade,
                      onGradeChanged: (g) => setState(() => _childGrade = g)),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: _consentGiven,
                    onChanged: (v) =>
                        setState(() => _consentGiven = v ?? false),
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
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: (_isProcessing || !_consentGiven)
                        ? null
                        : _registerChild,
                    child: _isProcessing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Register Child'),
                  ),
                ]),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              Text('Link to an Existing Child', style: AppTextStyles.h2),
              const SizedBox(height: 8),
              Card(
                color: AppColors.surface,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                            'If you already have a child\'s Link Code or QR, you can link to them here.',
                            style: AppTextStyles.bodyMedium),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            // navigate to link child screen (implemented in Section 3)
                            Navigator.pushNamed(context, '/link_child');
                          },
                          child: const Text('Link to Existing Child'),
                        ),
                      ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
