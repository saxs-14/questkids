import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/chat_message_model.dart';
import '../../../providers/auth_provider.dart';
import 'questy_avatar.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessageModel message;

  const ChatBubble({super.key, required this.message});

  Future<void> _showReportSheet(BuildContext context) async {
    final reasons = [
      'Confusing or wrong answer',
      'Made me uncomfortable',
      'Not appropriate for school',
      'Something else',
    ];
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'Report this answer',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'A grown-up will check this. Why are you reporting it?',
                style: TextStyle(color: Colors.black54),
              ),
            ),
            for (final r in reasons)
              ListTile(
                title: Text(r),
                onTap: () => Navigator.of(sheetContext).pop(r),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (reason == null || !context.mounted) return;

    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) return;

    await FirestoreService().reportAiMessage(
      uid: uid,
      messageText: message.text,
      reason: reason,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks — a grown-up will take a look.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (message.isLoading) {
      return _TypingIndicator();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: message.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isUser) ...[
            const QuestyAvatar(size: 36),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: message.isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!message.isUser) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: Text(
                      'AI · Questy',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
                GestureDetector(
                  onLongPress: message.isUser
                      ? null
                      : () => _showReportSheet(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: message.isUser
                          ? AppColors.primary
                          : Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(
                            message.isUser ? 20 : 4),
                        bottomRight: Radius.circular(
                            message.isUser ? 4 : 20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: message.isUser
                              ? AppColors.primary.withValues(alpha: 0.3)
                              : Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      message.text,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: message.isUser ? Colors.white : null,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            _UserAvatar(),
          ],
        ],
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C4DFF), Color(0xFF5C35F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.30),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Center(
        child: Text('👧', style: TextStyle(fontSize: 19)),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      )..repeat(reverse: true),
    );
    _anims = _controllers
        .map((c) => Tween<double>(begin: 0, end: 1).animate(c))
        .toList();
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) _controllers[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const QuestyAvatar(size: 36),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return AnimatedBuilder(
                  animation: _anims[i],
                  builder: (_, __) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 8,
                    height: 8 + (_anims[i].value * 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB800)
                          .withValues(alpha: 0.4 + _anims[i].value * 0.6),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
