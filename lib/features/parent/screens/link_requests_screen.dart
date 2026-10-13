import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/parent_provider.dart';
import '../../../providers/auth_provider.dart';

class LinkRequestsScreen extends StatefulWidget {
  const LinkRequestsScreen({super.key});

  @override
  State<LinkRequestsScreen> createState() => _LinkRequestsScreenState();
}

class _LinkRequestsScreenState extends State<LinkRequestsScreen> {
  final Set<String> _pendingActions = {};

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final parent = context.read<ParentProvider>();
    if (auth.user != null) parent.loadParentData(auth.user!.uid);
  }

  Future<void> _runAction(
    String requestId,
    String actionName,
    Future<void> Function() action,
  ) async {
    if (!_pendingActions.add(requestId)) return;
    setState(() {});
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Link request $actionName.')),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Unable to $actionName link request: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Could not $actionName the link request. Please try again.'),
          ),
        );
      }
    } finally {
      _pendingActions.remove(requestId);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final parent = context.watch<ParentProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Link Requests')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (parent.errorMessage != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.cloud_off_outlined),
                title: const Text('Parent data could not be loaded.'),
                subtitle: const Text('Check your connection and retry.'),
                trailing: TextButton(
                  onPressed: parent.isLoading
                      ? null
                      : () {
                          final uid =
                              context.read<AuthProvider>().user?.uid;
                          if (uid != null) parent.loadParentData(uid);
                        },
                  child: const Text('Retry'),
                ),
              ),
            ),
          Text('Incoming Requests', style: AppTextStyles.h4),
          const SizedBox(height: 8),
          if (parent.pendingRequests.isEmpty)
            const Text('No incoming requests'),
          ...parent.pendingRequests.map((r) => Card(
                child: ListTile(
                  title: Text(r['requestingParentName'] ?? 'Unknown'),
                  subtitle: Text(
                      'For ${r['childName'] ?? ''} — ${r['linkMethod'] ?? ''}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    ElevatedButton(
                        onPressed: _pendingActions.contains(r['id'])
                            ? null
                            : () => _runAction(
                                  r['id'] as String,
                                  'approved',
                                  () => parent.approveLinkRequest(
                                      r['id'] as String),
                                ),
                        child: const Text('Approve')),
                    const SizedBox(width: 8),
                    OutlinedButton(
                        onPressed: _pendingActions.contains(r['id'])
                            ? null
                            : () => _runAction(
                                  r['id'] as String,
                                  'declined',
                                  () => parent.declineLinkRequest(
                                      r['id'] as String),
                                ),
                        child: const Text('Decline')),
                  ]),
                ),
              )),
          const SizedBox(height: 16),
          Text('Outgoing Requests', style: AppTextStyles.h4),
          const SizedBox(height: 8),
          if (parent.outgoingRequests.isEmpty)
            const Text('No outgoing requests'),
          ...parent.outgoingRequests.map((r) => Card(
                child: ListTile(
                  title: Text(r['childName'] ?? 'Unknown'),
                  subtitle: Text('Status: ${r['status'] ?? 'pending'}'),
                  trailing: r['status'] == 'pending'
                      ? OutlinedButton(
                          onPressed: _pendingActions.contains(r['id'])
                              ? null
                              : () => _runAction(
                                    r['id'] as String,
                                    'cancelled',
                                    () => parent.cancelLinkRequest(
                                        r['id'] as String),
                                  ),
                          child: const Text('Cancel'))
                      : null,
                ),
              )),
        ]),
      ),
    );
  }
}
