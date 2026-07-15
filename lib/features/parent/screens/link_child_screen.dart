import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/widgets/app_button.dart';
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
                    AppButton(
                        label: 'Verify Code',
                        isLoading: _loading,
                        onPressed: _loading ? null : _verifyCode),
                    const SizedBox(height: 12),
                    if (_foundChild != null) _childPreview(_foundChild!),
                    if (_foundChild != null)
                      AppButton(
                          label: 'Confirm Link',
                          onPressed: () => _sendLinkRequest('code')),
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
                    AppButton(
                        label: 'Find Child',
                        isLoading: _loading,
                        onPressed: _loading ? null : _findByNameEmail),
                    const SizedBox(height: 12),
                    if (_foundChild != null) _childPreview(_foundChild!),
                    if (_foundChild != null)
                      AppButton(
                          label: 'Confirm Link',
                          onPressed: () => _sendLinkRequest('email')),
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
                      : Column(
                          children: [
                            SizedBox(
                              height: 320,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: MobileScanner(
                                  onDetect: (capture) {
                                    if (_loading || _foundChild != null) {
                                      return;
                                    }
                                    final barcodes = capture.barcodes;
                                    if (barcodes.isEmpty) return;
                                    final scanned = barcodes.first.rawValue;
                                    if (scanned == null ||
                                        scanned.length != 6) {
                                      return;
                                    }
                                    _codeCtrl.text = scanned.toUpperCase();
                                    _verifyCode();
                                  },
                                  errorBuilder: (context, error) {
                                    final friendly =
                                        PermissionService.friendlyMessage(
                                            error);
                                    return Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(friendly,
                                                textAlign: TextAlign.center),
                                            const SizedBox(height: 12),
                                            AppButton(
                                              label: 'Open Settings',
                                              variant:
                                                  AppButtonVariant.secondary,
                                              fullWidth: false,
                                              onPressed: PermissionService
                                                  .openSettings,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                                'Point the camera at your child\'s link QR code.'),
                            const SizedBox(height: 12),
                            if (_foundChild != null) _childPreview(_foundChild!),
                            if (_foundChild != null)
                              AppButton(
                                  label: 'Confirm Link',
                                  onPressed: () => _sendLinkRequest('qr')),
                          ],
                        ),
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
