import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../core/content_pack_loader.dart';
import '../core/game_config.dart';
import 'circuit_builder_session.dart';

class CircuitBuilderGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const CircuitBuilderGame(
      {super.key, required this.config, required this.user});

  @override
  State<CircuitBuilderGame> createState() => _CircuitBuilderGameState();
}

class _CircuitBuilderGameState extends State<CircuitBuilderGame> {
  late CircuitBuilderSession _session;
  Map<String, dynamic>? _pack;
  bool _ready = false;
  String? _feedbackText;
  bool _showFeedback = false;

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  Future<void> _initSession() async {
    final pack = await loadContentPack(widget.config);
    if (!mounted) return;
    _pack = pack;
    final uid = (widget.user?.uid as String?) ?? '';
    _session = CircuitBuilderSession(widget.config, uid, pack: pack);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _session.startSession());
    _session.addListener(_onSessionChange);
    setState(() => _ready = true);
  }

  @override
  void dispose() {
    if (_ready) {
      _session.removeListener(_onSessionChange);
      _session.dispose();
    }
    super.dispose();
  }

  void _onSessionChange() {
    if (mounted) setState(() {});
    if (_session.isFinished && mounted) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _showResultDialog();
      });
    }
  }

  void _showResultDialog() {
    final result = _session.result;
    if (result == null || !mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
            result.result == 'complete' || result.result == 'win'
                ? '⚡ Circuit Master!'
                : '🔋 Keep Practising!',
            textAlign: TextAlign.center,
            style: AppTextStyles.h3),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Score: ${result.score}%',
              style: AppTextStyles.h2.copyWith(color: AppColors.primary)),
          Text('+${result.xpEarned} XP  •  +${result.coinsEarned} coins',
              style: AppTextStyles.bodyMedium),
        ]),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Done')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _session.removeListener(_onSessionChange);
                _session.dispose();
                final uid = (widget.user?.uid as String?) ?? '';
                _session =
                    CircuitBuilderSession(widget.config, uid, pack: _pack);
                _session.addListener(_onSessionChange);
                _session.startSession();
              });
            },
            child:
                const Text('Play Again', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final blanks = (_session.currentQuestion?['blanks'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    bool allCorrect = true;
    for (int i = 0; i < blanks.length; i++) {
      if (_session.placed[i] != blanks[i]['correctComponent']) {
        allCorrect = false;
        break;
      }
    }
    setState(() {
      _feedbackText = allCorrect
          ? '✅ Correct! Circuit complete!'
          : '❌ Check your connections and try again.';
      _showFeedback = true;
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() => _showFeedback = false);
        _session.submitAnswer(null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final q = _session.currentQuestion;
    if (q == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final blanks = (q['blanks'] as List).cast<Map<String, dynamic>>();
    final bank = (q['bank'] as List).cast<String>();
    final labels = (q['labels'] as Map).cast<String, String>();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.technology,
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('⚡ Circuit Builder',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          Text('${_session.questionIndex + 1} / ${_session.totalQuestions}',
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
                child: Text('${_session.elapsedSeconds}s',
                    style: const TextStyle(color: Colors.white70))),
          ),
        ],
      ),
      body: Column(children: [
        // Progress
        LinearProgressIndicator(
            value: _session.progressFraction,
            minHeight: 4,
            color: AppColors.technology,
            backgroundColor: AppColors.technology.withValues(alpha: 0.2)),

        Expanded(
            child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Description
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.technology.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.technology.withValues(alpha: 0.2)),
              ),
              child: Text(q['description'] as String,
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 20),

            // Circuit diagram
            Text('Circuit Diagram', style: AppTextStyles.h4),
            const SizedBox(height: 8),
            _CircuitDiagram(
                layout: q['layout'] as String,
                blanks: blanks,
                placed: _session.placed),
            const SizedBox(height: 24),

            // Feedback
            if (_showFeedback)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: (_feedbackText?.startsWith('✅') ?? false)
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_feedbackText ?? '',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600)),
              ),

            // Blanks to fill
            Text('Fill the gaps', style: AppTextStyles.h4),
            const SizedBox(height: 8),
            ...blanks.asMap().entries.map((e) {
              final i = e.key;
              final blank = e.value;
              final placed = _session.placed[i];
              return _BlankSlot(
                index: i,
                blank: blank,
                placed: placed,
                labels: labels,
                onClear: () => _session.clearPlacement(i),
              );
            }),
            const SizedBox(height: 20),

            // Component bank
            Text('Component Bank — tap to place', style: AppTextStyles.h4),
            const SizedBox(height: 8),
            Wrap(
                spacing: 10,
                runSpacing: 10,
                children: bank.map((comp) {
                  final alreadyPlaced = _session.placed.values.contains(comp);
                  return _ComponentChip(
                    component: comp,
                    label: labels[comp] ?? comp,
                    used: alreadyPlaced,
                    onTap: alreadyPlaced
                        ? null
                        : () {
                            int? emptyIndex;
                            for (int i = 0; i < blanks.length; i++) {
                              if (_session.placed[i] == null) {
                                emptyIndex = i;
                                break;
                              }
                            }
                            if (emptyIndex != null)
                              _session.placeComponent(emptyIndex, comp);
                          },
                  );
                }).toList()),
          ]),
        )),

        // Submit button
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  _session.allBlanksFilled && !_showFeedback ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.technology,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Check Circuit ⚡',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ]),
    );
  }
}

class _CircuitDiagram extends StatelessWidget {
  final String layout;
  final List<Map<String, dynamic>> blanks;
  final Map<int, String> placed;
  const _CircuitDiagram(
      {required this.layout, required this.blanks, required this.placed});

  @override
  Widget build(BuildContext context) {
    int blankCount = 0;
    final parts = layout.split('?');
    final children = <Widget>[];

    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        children.add(Text(parts[i], style: const TextStyle(fontSize: 22)));
      }
      if (i < parts.length - 1) {
        final blankIdx = blankCount++;
        final placedEmoji = placed[blankIdx] != null
            ? (blanks[blankIdx]['emoji'] as String? ?? '?')
            : null;
        children.add(
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: placedEmoji != null
                  ? AppColors.technology.withValues(alpha: 0.15)
                  : Colors.grey.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: placedEmoji != null
                    ? AppColors.technology
                    : Colors.grey.shade400,
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                placedEmoji ?? (blankIdx + 1).toString(),
                style: TextStyle(
                    fontSize: placedEmoji != null ? 20 : 14,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
        );
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          runSpacing: 8,
          children: children),
    );
  }
}

class _BlankSlot extends StatelessWidget {
  final int index;
  final Map<String, dynamic> blank;
  final String? placed;
  final Map<String, String> labels;
  final VoidCallback onClear;
  const _BlankSlot(
      {required this.index,
      required this.blank,
      required this.placed,
      required this.labels,
      required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: placed != null
            ? AppColors.technology.withValues(alpha: 0.08)
            : Colors.grey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: placed != null
                ? AppColors.technology.withValues(alpha: 0.3)
                : Colors.grey.shade300),
      ),
      child: Row(children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
              color: AppColors.technology, shape: BoxShape.circle),
          child: Center(
              child: Text('${index + 1}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12))),
        ),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              placed != null ? (labels[placed] ?? placed!) : 'Gap ${index + 1}',
              style: AppTextStyles.bodyMedium
                  .copyWith(fontWeight: FontWeight.w600)),
          Text(blank['hint'] as String? ?? '',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary)),
        ])),
        if (placed != null)
          IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onClear,
              color: AppColors.error),
      ]),
    );
  }
}

class _ComponentChip extends StatelessWidget {
  final String component;
  final String label;
  final bool used;
  final VoidCallback? onTap;
  const _ComponentChip(
      {required this.component,
      required this.label,
      required this.used,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: used ? 0.4 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: used
                ? Colors.grey.withValues(alpha: 0.1)
                : AppColors.technology.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: used
                    ? Colors.grey.shade300
                    : AppColors.technology.withValues(alpha: 0.4)),
          ),
          child: Text(label,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: used ? AppColors.textSecondary : AppColors.technology,
              )),
        ),
      ),
    );
  }
}
