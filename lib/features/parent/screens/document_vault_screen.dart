import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/repositories/parent_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/parent_provider.dart';

class DocumentVaultScreen extends StatefulWidget {
  const DocumentVaultScreen({super.key});

  @override
  State<DocumentVaultScreen> createState() => _DocumentVaultScreenState();
}

class _DocumentVaultScreenState extends State<DocumentVaultScreen> {
  final _repo = ParentRepository();
  bool _uploading = false;

  Future<void> _pickAndUpload(String childUid, String parentUid) async {
    const typeGroup = XTypeGroup(
      label: 'documents',
      extensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await file.readAsBytes();
      await _repo.uploadDocument(
        childUid: childUid,
        uploadedByUid: parentUid,
        fileName: file.name,
        bytes: Uint8List.fromList(bytes),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document uploaded')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parent = context.watch<ParentProvider>();
    final child = parent.selectedChild;
    final parentUid = context.read<AuthProvider>().user?.uid ?? '';

    if (child == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Document Vault')),
        body: const Center(child: Text('Select a child first.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text("${child.name}'s Documents")),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            _uploading ? null : () => _pickAndUpload(child.uid, parentUid),
        icon: _uploading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.upload_file),
        label: Text(_uploading ? 'Uploading...' : 'Upload'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _repo.watchDocuments(child.uid),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!;
          if (docs.isEmpty) {
            return const Center(child: Text('No documents yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final d = docs[i];
              final createdAt = d['createdAt'];
              final dateStr = createdAt is Timestamp
                  ? DateFormat.yMMMd().format(createdAt.toDate())
                  : '';
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.insert_drive_file_outlined,
                      color: AppColors.primary),
                  title: Text(d['fileName'] as String? ?? 'Document',
                      style: AppTextStyles.bodyMedium),
                  subtitle: Text(dateStr),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _repo.deleteDocument(d['id'] as String),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
