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
  Stream<List<Map<String, dynamic>>>? _documentsStream;
  String? _documentsChildUid;
  final Set<String> _deletingDocuments = {};

  Future<void> _pickAndUpload(String childUid, String parentUid) async {
    const typeGroup = XTypeGroup(
      label: 'documents',
      extensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
    );
    setState(() => _uploading = true);
    try {
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) return;
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
    } catch (error, stackTrace) {
      debugPrint('Unable to upload vault document: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Document upload failed. Please try again.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deleteDocument(String documentId) async {
    if (!_deletingDocuments.add(documentId)) return;
    setState(() {});
    try {
      await _repo.deleteDocument(documentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document deleted.')));
      }
    } catch (error, stackTrace) {
      debugPrint('Unable to delete vault document: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Document could not be deleted. Please try again.'),
        ));
      }
    } finally {
      _deletingDocuments.remove(documentId);
      if (mounted) setState(() {});
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
    if (_documentsChildUid != child.uid) {
      _documentsChildUid = child.uid;
      _documentsStream = _repo.watchDocuments(child.uid);
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
        stream: _documentsStream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                      'Documents could not be loaded. Check your connection and try again.'),
                  TextButton(
                    onPressed: () => setState(() {
                      _documentsStream = _repo.watchDocuments(child.uid);
                    }),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
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
                    icon: _deletingDocuments.contains(d['id'])
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline),
                    onPressed: _deletingDocuments.contains(d['id'])
                        ? null
                        : () => _deleteDocument(d['id'] as String),
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
