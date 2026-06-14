import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/ai_tutor_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/rewards_provider.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/quick_prompt_chip.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<AiTutorProvider>().initSession(user);
        _loadRecommendation();
      }
    });
  }

  Future<void> _loadRecommendation() async {
    final user = context.read<AuthProvider>().user;
    final rewards = context.read<RewardsProvider>();
    if (user == null) return;

    final subjectScores = <String, int>{};
    for (final entry in rewards.subjectCounts.entries) {
      subjectScores[entry.key] =
          (entry.value * 20).clamp(0, 100);
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
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
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

    final body = Column(
        children: [
          // Recommendation banner
          if (tutor.recommendation != null ||
              tutor.recommendationLoading)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  16, 12, 16, 0),
              child: RecommendationCard(
                recommendation:
                    tutor.recommendation ?? '',
                isLoading: tutor.recommendationLoading,
              ),
            ),

          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: tutor.messages.length,
              itemBuilder: (_, i) =>
                  ChatBubble(message: tutor.messages[i]),
            ),
          ),

          // Quick prompts
          if (_showQuickPrompts &&
              tutor.messages.length <= 1)
            Container(
              padding: const EdgeInsets.fromLTRB(
                  16, 8, 16, 0),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text('Quick questions:',
                      style: AppTextStyles.label),
                  const SizedBox(height: 8),
                  Wrap(
                    children: AiTutorProvider.quickPrompts
                        .map((p) => QuickPromptChip(
                              label: p,
                              onTap: () =>
                                  _sendMessage(p),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),

          // Input bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .scaffoldBackgroundColor,
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
                IconButton(
                  icon: const Icon(Icons.image_outlined,
                      color: AppColors.primary),
                  onPressed: _pickImage,
                  tooltip: 'Upload homework photo',
                ),
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    decoration: InputDecoration(
                      hintText:
                          'Ask QuestBot anything...',
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppColors.primary
                          .withValues(alpha: 0.07),
                      contentPadding:
                          const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10),
                    ),
                    textInputAction:
                        TextInputAction.send,
                    onSubmitted: _sendMessage,
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () =>
                      _sendMessage(_textCtrl.text),
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
                            child:
                                CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send,
                            color: Colors.white,
                            size: 20),
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
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🤖', style: TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('QuestBot',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
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
                    const Text('Online',
                        style:
                            TextStyle(fontSize: 11, color: Colors.white70)),
                  ],
                ),
              ],
            ),
          ],
        ),
        automaticallyImplyLeading: false,
        actions: [
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
