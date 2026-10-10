import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/otp_verification_dialog.dart';
import '../../../data/models/user_model.dart';

class ParentAccessScreen extends StatefulWidget {
  final List<UserModel> children;
  const ParentAccessScreen({super.key, required this.children});

  @override
  State<ParentAccessScreen> createState() => _ParentAccessScreenState();
}

class _ParentAccessScreenState extends State<ParentAccessScreen> {
  UserModel? _selectedChild;
  List<Map<String, dynamic>> _parents = [];
  // Last-saved permissions per secondary-parent uid, so pending edits in
  // `_parents` can be compared against them to show "unsaved changes" and
  // to support Discard without a round-trip to the server.
  final Map<String, Map<String, bool>> _savedPermissions = {};
  final Set<String> _saving = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedChild = widget.children.isNotEmpty ? widget.children.first : null;
    _load();
  }

  Future<void> _load() async {
    final child = _selectedChild;
    if (child == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('getParentAccess')
          .call({'childUid': child.uid});
      final data = Map<String, dynamic>.from(result.data as Map);
      _parents = (data['parents'] as List<dynamic>? ?? [])
          .map((p) => Map<String, dynamic>.from(p as Map))
          .toList();
      _savedPermissions.clear();
      for (final parent in _parents) {
        _savedPermissions[parent['uid'] as String] =
            Map<String, bool>.from(parent['permissions'] as Map? ?? {});
      }
    } catch (e) {
      _error = 'Unable to load linked parent access.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _hasPendingChanges(Map<String, dynamic> parent) {
    final saved = _savedPermissions[parent['uid']] ?? const {};
    final pending = Map<String, bool>.from(parent['permissions'] as Map? ?? {});
    return !mapEquals(saved, pending);
  }

  void _editPermission(Map<String, dynamic> parent, String key, bool value) {
    setState(() {
      final updated = Map<String, dynamic>.from(parent['permissions'] as Map? ?? {});
      updated[key] = value;
      parent['permissions'] = updated;
    });
  }

  void _discardChanges(Map<String, dynamic> parent) {
    setState(() {
      parent['permissions'] =
          Map<String, bool>.from(_savedPermissions[parent['uid']] ?? const {});
    });
  }

  Future<void> _saveChanges(Map<String, dynamic> parent) async {
    final child = _selectedChild;
    if (child == null) return;
    final parentUid = parent['uid'] as String;
    final pending = Map<String, bool>.from(parent['permissions'] as Map? ?? {});

    final confirmed = await OtpVerificationDialog.show(
      context,
      action: 'setParentPermissions',
      title: 'Confirm access changes',
      message:
          "Enter the 6-digit code we emailed you to confirm these permission changes for ${parent['name'] ?? 'this linked parent'}.",
      onSubmit: (otpCode) async {
        await FirebaseFunctions.instanceFor(region: 'us-central1')
            .httpsCallable('setParentPermissions')
            .call({
          'childUid': child.uid,
          'parentUid': parentUid,
          'permissions': pending,
          'otpCode': otpCode,
        });
      },
    );

    if (!mounted) return;
    if (confirmed) {
      setState(() => _savedPermissions[parentUid] = pending);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Access changes saved.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedChild == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Parent Access')),
        body: const Center(child: Text('No primary-parent children are linked to this account.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Access'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.children.length > 1)
              DropdownButtonFormField<UserModel>(
                initialValue: _selectedChild,
                decoration: const InputDecoration(
                  labelText: 'Child',
                  prefixIcon: Icon(Icons.child_care),
                  border: OutlineInputBorder(),
                ),
                items: widget.children
                    .map((child) => DropdownMenuItem(
                          value: child,
                          child: Text(child.name),
                        ))
                    .toList(),
                onChanged: (child) {
                  setState(() => _selectedChild = child);
                  _load();
                },
              ),
            if (widget.children.length > 1) const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: AppColors.rainbow),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'You are the primary parent. Choose exactly what each linked parent can access, then save to confirm with a one-time code.',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ))
            else if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.error))
            else if (_parents.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No secondary parents are linked to this child yet.'),
                ),
              )
            else
              ..._parents.map((parent) => _parentCard(parent)),
          ],
        ),
      ),
    );
  }

  Widget _parentCard(Map<String, dynamic> parent) {
    final parentUid = parent['uid'] as String;
    final hasChanges = _hasPendingChanges(parent);
    final isSaving = _saving.contains(parentUid);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const CircleAvatar(
                backgroundColor: AppColors.primaryLight,
                child: Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    '${parent['name'] ?? 'Linked parent'} ${parent['surname'] ?? ''}'.trim(),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  Text(
                    parent['email'] ?? '',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ]),
              ),
            ]),
            const Divider(height: 24),
            _switch(parent, 'viewProgress', 'View game progress', 'See scores, games and progress.'),
            _switch(parent, 'viewReports', 'View AI weekly reports', 'Read QuestKids weekly progress reports.'),
            _switch(parent, 'verifyProgress', 'Verify progress', 'Approve or verify completed learning work.'),
            _switch(parent, 'viewMood', 'View mood check-ins', 'See the child mood check-in history.'),
            _switch(parent, 'manageCalendar', 'Manage calendar', 'Create and manage shared calendar/reminders.'),
            if (hasChanges) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Unsaved changes',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: isSaving ? null : () => _discardChanges(parent),
                    child: const Text('Discard'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            setState(() => _saving.add(parentUid));
                            await _saveChanges(parent);
                            if (mounted) setState(() => _saving.remove(parentUid));
                          },
                    child: isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Changes'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _switch(Map<String, dynamic> parent, String key, String title, String subtitle) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      value: parent['permissions']?[key] == true,
      activeThumbColor: AppColors.primary,
      onChanged: (value) => _editPermission(parent, key, value),
    );
  }
}
