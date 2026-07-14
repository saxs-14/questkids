import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../data/repositories/messaging_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../messaging/screens/message_thread_screen.dart';

class MessagesListScreen extends StatelessWidget {
  const MessagesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().user?.uid ?? '';
    final repo = MessagingRepository();

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: StreamBuilder(
        stream: repo.watchConversationsForUser(uid),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final conversations = snap.data!;
          if (conversations.isEmpty) {
            return const Center(
                child: Text("No messages yet -- your child's teacher will "
                    'appear here once you message.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: conversations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final c = conversations[i];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.school)),
                  title: Text('About ${c.childName}'),
                  subtitle: Text(
                    c.lastMessage.isEmpty ? 'No messages yet' : c.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: c.lastMessageAt != null
                      ? Text(DateFormat.MMMd().format(c.lastMessageAt!))
                      : null,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MessageThreadScreen(conversation: c),
                    ),
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
