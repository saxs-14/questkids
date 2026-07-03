import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/parent_repository.dart';
import '../../../providers/auth_provider.dart';

class LinkChildScreen extends StatefulWidget {
  const LinkChildScreen({super.key});

  @override
  State<LinkChildScreen> createState() => _LinkChildScreenState();
}

class _LinkChildScreenState extends State<LinkChildScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  UserModel? _foundChild;
  bool _loading = false;
  final ParentRepository _repo = ParentRepository();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    setState(() => _loading = true);
    final child = await _repo.findChildByCode(_codeCtrl.text.trim());
    setState(() {
      _foundChild = child;
      _loading = false;
    });
  }

  Future<void> _findByNameEmail() async {
    setState(() => _loading = true);
    final child = await _repo.findChildByNameAndEmail(
        _nameCtrl.text.trim(), _emailCtrl.text.trim());
    setState(() {
      _foundChild = child;
      _loading = false;
    });
  }

  Future<void> _sendLinkRequest(String linkMethod) async {
    final auth = context.read<AuthProvider>();
    final me = auth.user;
    if (me == null || _foundChild == null) return;
    await _repo.sendLinkRequest({
      'requestingParentUid': me.uid,
      'requestingParentName': me.displayName,
      'requestingParentEmail': me.email,
      'requestingParentRole': me.role,
      'childUid': _foundChild!.uid,
      'childName': _foundChild!.name,
      'primaryParentUid': _foundChild!.parentUid ?? '',
      'status': 'pending',
      'linkMethod': linkMethod,
    });
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Link request sent')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Link a Child')),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Code'),
              Tab(text: 'Name & Email'),
              Tab(text: 'QR')
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Code tab
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(children: [
                    TextField(
                        controller: _codeCtrl,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 6,
                        decoration: const InputDecoration(
                            labelText: '6-character code')),
                    const SizedBox(height: 12),
                    ElevatedButton(
                        onPressed: _loading ? null : _verifyCode,
                        child: _loading
                            ? const CircularProgressIndicator()
                            : const Text('Verify Code')),
                    const SizedBox(height: 12),
                    if (_foundChild != null) _childPreview(_foundChild!),
                    if (_foundChild != null)
                      ElevatedButton(
                          onPressed: () => _sendLinkRequest('code'),
                          child: const Text('Confirm Link')),
                  ]),
                ),

                // Name & Email
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(children: [
                    TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Child Full Name')),
                    const SizedBox(height: 8),
                    TextField(
                        controller: _emailCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Primary Parent Email')),
                    const SizedBox(height: 12),
                    ElevatedButton(
                        onPressed: _loading ? null : _findByNameEmail,
                        child: _loading
                            ? const CircularProgressIndicator()
                            : const Text('Find Child')),
                    const SizedBox(height: 12),
                    if (_foundChild != null) _childPreview(_foundChild!),
                    if (_foundChild != null)
                      ElevatedButton(
                          onPressed: () => _sendLinkRequest('email'),
                          child: const Text('Confirm Link')),
                  ]),
                ),

                // QR
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: kIsWeb
                      ? Column(children: [
                          const Text(
                              'Camera not available on web. Use code input above.'),
                          const SizedBox(height: 12),
                          TextField(
                              controller: _codeCtrl,
                              textCapitalization: TextCapitalization.characters,
                              maxLength: 6,
                              decoration: const InputDecoration(
                                  labelText: 'Enter Code'))
                        ])
                      : const Center(
                          child: Text('QR scanner available on mobile.')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _childPreview(UserModel child) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
            child: Text(child.name.isNotEmpty ? child.name[0] : '?')),
        title: Text(child.name),
        subtitle: Text(child.grade),
        trailing: Text(child.parentUid ?? 'Primary N/A'),
      ),
    );
  }
}
