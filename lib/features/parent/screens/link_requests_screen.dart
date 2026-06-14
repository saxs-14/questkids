import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/parent_provider.dart';
import '../../../providers/auth_provider.dart';

class LinkRequestsScreen extends StatefulWidget {
  const LinkRequestsScreen({super.key});

  @override
  State<LinkRequestsScreen> createState() => _LinkRequestsScreenState();
}

class _LinkRequestsScreenState extends State<LinkRequestsScreen> {
  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final parent = context.read<ParentProvider>();
    if (auth.user != null) parent.loadParentData(auth.user!.uid);
  }

  @override
  Widget build(BuildContext context) {
    final parent = context.watch<ParentProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Link Requests')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Incoming Requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (parent.pendingRequests.isEmpty) const Text('No incoming requests'),
          ...parent.pendingRequests.map((r) => Card(
                child: ListTile(
                  title: Text(r['requestingParentName'] ?? 'Unknown'),
                  subtitle: Text('For ${r['childName'] ?? ''} — ${r['linkMethod'] ?? ''}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    ElevatedButton(onPressed: () async {
                      await parent.approveLinkRequest(r['id'], r['childUid'], r['requestingParentUid']);
                    }, child: const Text('Approve')),
                    const SizedBox(width: 8),
                    OutlinedButton(onPressed: () async { await parent.declineLinkRequest(r['id']); }, child: const Text('Decline')),
                  ]),
                ),
              )),

          const SizedBox(height: 16),
          const Text('Outgoing Requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (parent.outgoingRequests.isEmpty) const Text('No outgoing requests'),
          ...parent.outgoingRequests.map((r) => Card(
                child: ListTile(
                  title: Text(r['childName'] ?? 'Unknown'),
                  subtitle: Text('Status: ${r['status'] ?? 'pending'}'),
                  trailing: r['status'] == 'pending'
                      ? OutlinedButton(onPressed: () async { /* cancel logic */ }, child: const Text('Cancel'))
                      : null,
                ),
              )),
        ]),
      ),
    );
  }
}
