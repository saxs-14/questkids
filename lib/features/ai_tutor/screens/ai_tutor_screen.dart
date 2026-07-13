import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/ai_tutor_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/rewards_provider.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/quick_prompt_chip.dart';
import '../widgets/questy_avatar.dart';
import '../widgets/recommendation_card.dart';

class AiTutorScreen extends StatefulWidget {
  final bool embedded;
  const AiTutorScreen({super.key, this.embedded = false});

  @override
  State<AiTutorScreen> createState() => _AiTutorScreenState();
}

class _AiTutorScreenState extends State<AiTutorScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _picker = ImagePicker();
  bool _showQuickPrompts = true;

  static const _seenAiNoticePrefKey = 'questy_ai_notice_seen';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<AiTutorProvider>().initSession(user);
        _loadRecommendation();
      }
      await _maybeShowFirstOpenNotice();
    });
  }

  Future<void> _maybeShowFirstOpenNotice() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_seenAiNoticePrefKey) == true) return;
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Text('🤖 ', style: TextStyle(fontSize: 22)),
            Expanded(child: Text('Meet Questy!')),
          ],
        ),
        content: const Text(
          "Questy is an AI helper, not a real person. It's here to help you "
          'learn — but it can make mistakes, so always check with a teacher '
          "or parent too. A grown-up checks any answer you report, and you "
          "should never share personal info (like your address or phone "
          'number) with Questy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
    await prefs.setBool(_seenAiNoticePrefKey, true);
  }

  Future<void> _loadRecommendation() async {
    final user = context.read<AuthProvider>().user;
    final rewards = context.read<RewardsProvider>();
    if (user == null) return;

    final subjectScores = <String, int>{};
    for (final entry in rewards.subjectCounts.entries) {
      subjectScores[entry.key] = (entry.value * 20).clamp(0, 100);
    }

    await context.read<AiTutorProvider>().loadRecommendation(
          name: user.name.split(' ').first,
          grade: user.grade,
          subjectScores: subjectScores,
          streakDays: rewards.streakDays,
          totalPoints: rewards.totalPoints,
        );
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    _textCtrl.clear();
    setState(() => _showQuickPrompts = false);
    await context.read<AiTutorProvider>().sendMessage(text);
    _scrollToBottom();
  }

  Future<void> _pickImage() async {
    XFile? image;
    try {
      image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 85,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(PermissionService.friendlyMessage(e)),
            action: PermissionService.isPermissionDenied(e)
                ? const SnackBarAction(
                    label: 'Settings',
                    onPressed: PermissionService.openSettings,
                  )
                : null,
          ),
        );
      }
      return;
    }
    if (image == null) return;
    final bytes = await image.readAsBytes();
    setState(() => _showQuickPrompts = false);
    if (mounted) {
      await context.read<AiTutorProvider>().sendImageMessage(
            imageBytes: bytes,
            prompt: 'Please help me with this homework question 📸',
          );
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tutor = context.watch<AiTutorProvider>();
    final authUser = context.read<AuthProvider>().user;
    final firstName = authUser?.name.split(' ').first ?? 'there';
    final userAvatarUrl = authUser?.avatarUrl;

    final body = Column(
      children: [
        // Recommendation banner
        if (tutor.recommendation != null || tutor.recommendationLoading)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: RecommendationCard(
              recommendation: tutor.recommendation ?? '',
              isLoading: tutor.recommendationLoading,
            ),
          ),

        // Messages
        Expanded(
          child: tutor.messages.isEmpty
              ? _WelcomeBanner(firstName: firstName, onPrompt: _sendMessage)
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: tutor.messages.length,
                  itemBuilder: (_, i) => ChatBubble(
                    message: tutor.messages[i],
                    userAvatarUrl: userAvatarUrl,
                  ),
                ),
        ),

        // Quick prompts (shown below messages when chat is new)
        if (_showQuickPrompts &&
            tutor.messages.length <= 1 &&
            tutor.messages.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quick questions:', style: AppTextStyles.label),
                const SizedBox(height: 8),
                Wrap(
                  children: AiTutorProvider.quickPrompts
                      .map((p) => QuickPromptChip(
                          label: p, onTap: () => _sendMessage(p)))
                      .toList(),
                ),
              ],
            ),
          ),

        // Input bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              if (widget.embedded)
                IconButton(
                  icon: Icon(
                    tutor.isMuted ? Icons.volume_off : Icons.volume_up,
                    color: AppColors.primary,
                  ),
                  onPressed: () => context.read<AiTutorProvider>().toggleMute(),
                  tooltip: tutor.isMuted ? 'Unmute Questy' : 'Mute Questy',
                ),
              IconButton(
                icon:
                    const Icon(Icons.image_outlined, color: AppColors.primary),
                onPressed: _pickImage,
                tooltip: 'Upload homework photo',
              ),
              Expanded(
                child: TextField(
                  controller: _textCtrl,
                  decoration: InputDecoration(
                    hintText: 'Ask Questy anything...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppColors.primary.withValues(alpha: 0.07),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: _sendMessage,
                  maxLines: null,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _sendMessage(_textCtrl.text),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: tutor.isTyping
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const QuestyAvatar(size: 38),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Questy',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('Your Learning Star ✨',
                        style: TextStyle(fontSize: 11, color: Colors.white70)),
                  ],
                ),
              ],
            ),
          ],
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(tutor.isMuted ? Icons.volume_off : Icons.volume_up),
            onPressed: () => context.read<AiTutorProvider>().toggleMute(),
            tooltip: tutor.isMuted ? 'Unmute Questy' : 'Mute Questy',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<AiTutorProvider>().clearMessages();
              final user = context.read<AuthProvider>().user;
              if (user != null) {
                context.read<AiTutorProvider>().initSession(user);
              }
              setState(() => _showQuickPrompts = true);
            },
            tooltip: 'New conversation',
          ),
        ],
      ),
      body: body,
    );
  }
}

// ── Welcome banner shown before the first message ──────────────────────────

class _WelcomeBanner extends StatelessWidget {
  final String firstName;
  final void Function(String) onPrompt;

  const _WelcomeBanner({required this.firstName, required this.onPrompt});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        children: [
          // Kids + Questy illustration
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Left child
              Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C4DFF).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                        child: Text('👦', style: TextStyle(fontSize: 28))),
                  ),
                  const SizedBox(height: 4),
                  Text('Ask',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),

              // Speech arrows
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    const Text('→',
                        style:
                            TextStyle(fontSize: 22, color: Color(0xFFFFB800))),
                    const SizedBox(height: 4),
                    const Text('←',
                        style:
                            TextStyle(fontSize: 22, color: Color(0xFF5C35F5))),
                  ],
                ),
              ),

              // Questy (center, bigger)
              Column(
                children: [
                  const QuestyAvatar(size: 72),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB800).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              const Color(0xFFFFB800).withValues(alpha: 0.40)),
                    ),
                    child: const Text('Questy',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFCC8800))),
                  ),
                ],
              ),

              // Speech arrows right side
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    const Text('←',
                        style:
                            TextStyle(fontSize: 22, color: Color(0xFFFFB800))),
                    const SizedBox(height: 4),
                    const Text('→',
                        style:
                            TextStyle(fontSize: 22, color: Color(0xFF5C35F5))),
                  ],
                ),
              ),

              // Right child
              Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE91E63).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                        child: Text('👧', style: TextStyle(fontSize: 28))),
                  ),
                  const SizedBox(height: 4),
                  Text('Learn',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          Text(
            'Hi $firstName! 👋',
            style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'I\'m Questy — your personal learning star! ✨\nAsk me anything about school.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // Quick prompt chips in welcome state
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: AiTutorProvider.quickPrompts
                .map((p) => QuickPromptChip(label: p, onTap: () => onPrompt(p)))
                .toList(),
          ),
        ],
      ),
    );
  }
}
