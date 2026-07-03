import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../core/content_pack_loader.dart';
import '../core/game_config.dart';
import 'budget_builder_session.dart';

const _kNeeds = 'need';
const _kWants = 'want';
const _kSkip = 'skip';

const _bucketConfig = {
  _kNeeds: {'label': 'NEEDS', 'emoji': '✅', 'color': Color(0xFF00897B)},
  _kWants: {'label': 'WANTS', 'emoji': '⭐', 'color': Color(0xFFFF8F00)},
  _kSkip: {'label': 'SKIP', 'emoji': '⛔', 'color': Color(0xFFE53935)},
};

class BudgetBuilderGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const BudgetBuilderGame(
      {super.key, required this.config, required this.user});

  @override
  State<BudgetBuilderGame> createState() => _BudgetBuilderGameState();
}

class _BudgetBuilderGameState extends State<BudgetBuilderGame> {
  late BudgetBuilderSession _session;
  Map<String, dynamic>? _pack;
  bool _ready = false;
  bool _showReview = false;
  bool _submitting = false;

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
    _session = BudgetBuilderSession(widget.config, uid, pack: pack);
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
      Future.delayed(const Duration(milliseconds: 500), () {
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
            result.score >= 70 ? '💰 Budget Boss!' : '📊 Keep Learning!',
            textAlign: TextAlign.center,
            style: AppTextStyles.h3),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${result.score}%',
              style: AppTextStyles.h1.copyWith(color: AppColors.primary)),
          const SizedBox(height: 4),
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
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _session.removeListener(_onSessionChange);
                _session.dispose();
                final uid = (widget.user?.uid as String?) ?? '';
                _session =
                    BudgetBuilderSession(widget.config, uid, pack: _pack);
                _session.addListener(_onSessionChange);
                _showReview = false;
                _submitting = false;
                _session.startSession();
              });
            },
            child: const Text('Play Again'),
          ),
        ],
      ),
    );
  }

  void _submitRound() {
    setState(() => _submitting = true);
    _session.submitAnswer(null);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted)
        setState(() {
          _showReview = false;
          _submitting = false;
        });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final q = _session.currentQuestion;
    if (q == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final items = _session.currentItems;
    final budget = q['budget'] as int;
    final scenario = q['scenario'] as String;
    final totalSpent = items
        .where((item) =>
            _session.categorised[item['name']] == _kNeeds ||
            _session.categorised[item['name']] == _kWants)
        .fold<int>(0, (sum, item) => sum + (item['cost'] as int));
    final remaining = budget - totalSpent;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('💰 Budget Builder',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          Text(
              'Scenario ${_session.questionIndex + 1} / ${_session.totalQuestions}',
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ]),
      ),
      body: Column(children: [
        LinearProgressIndicator(
            value: _session.progressFraction,
            minHeight: 4,
            color: const Color(0xFF00897B),
            backgroundColor: const Color(0xFF00897B).withValues(alpha: 0.2)),

        // Budget header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFF00897B).withValues(alpha: 0.08),
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(scenario,
                      style: AppTextStyles.bodyMedium
                          .copyWith(fontWeight: FontWeight.w600)),
                  Text('Budget: R$budget',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
                ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Spending: R$totalSpent', style: AppTextStyles.bodySmall),
              Text('Left: R$remaining',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: remaining >= 0 ? AppColors.success : AppColors.error,
                  )),
            ]),
          ]),
        ),

        Expanded(
            child: _showReview
                ? _ReviewPanel(items: items, categorised: _session.categorised)
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final item = items[i];
                      final name = item['name'] as String;
                      final chosen = _session.categorised[name];
                      return _ItemCard(
                        item: item,
                        chosen: chosen,
                        onCategory: (cat) => _session.categorise(name, cat),
                      );
                    },
                  )),

        // Action row
        if (!_showReview)
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _session.allCategorised
                    ? () => setState(() => _showReview = true)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Review My Budget 📊',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                  child: OutlinedButton(
                onPressed: () => setState(() => _showReview = false),
                child: const Text('Go Back'),
              )),
              const SizedBox(width: 12),
              Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submitRound,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Submit Budget ✅',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                  )),
            ]),
          ),
      ]),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String? chosen;
  final void Function(String) onCategory;
  const _ItemCard(
      {required this.item, required this.chosen, required this.onCategory});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: chosen != null
            ? (_bucketConfig[chosen]!['color'] as Color).withValues(alpha: 0.07)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: chosen != null
              ? (_bucketConfig[chosen]!['color'] as Color)
                  .withValues(alpha: 0.4)
              : Colors.grey.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(item['emoji'] as String, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(item['name'] as String,
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w700)),
                Text('R${item['cost']}',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
              ])),
          if (chosen != null)
            Chip(
              label: Text(
                  '${_bucketConfig[chosen]!['emoji']} ${_bucketConfig[chosen]!['label']}',
                  style: const TextStyle(fontSize: 11, color: Colors.white)),
              backgroundColor: _bucketConfig[chosen]!['color'] as Color,
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
        ]),
        const SizedBox(height: 10),
        Row(
            children: _bucketConfig.entries.map((e) {
          final isChosen = chosen == e.key;
          return Expanded(
              child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => onCategory(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isChosen
                      ? (e.value['color'] as Color)
                      : (e.value['color'] as Color).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: (e.value['color'] as Color)
                          .withValues(alpha: isChosen ? 1 : 0.3)),
                ),
                child: Column(children: [
                  Text(e.value['emoji'] as String,
                      style: const TextStyle(fontSize: 16)),
                  Text(e.value['label'] as String,
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isChosen
                              ? Colors.white
                              : (e.value['color'] as Color))),
                ]),
              ),
            ),
          ));
        }).toList()),
      ]),
    );
  }
}

class _ReviewPanel extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final Map<String, String> categorised;
  const _ReviewPanel({required this.items, required this.categorised});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Your Budget Summary', style: AppTextStyles.h3),
        const SizedBox(height: 12),
        ...items.map((item) {
          final cat = categorised[item['name']];
          final config = _bucketConfig[cat];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: (config?['color'] as Color? ?? Colors.grey)
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Text(item['emoji'] as String,
                  style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(item['name'] as String,
                      style: AppTextStyles.bodyMedium
                          .copyWith(fontWeight: FontWeight.w600))),
              Text('R${item['cost']}', style: AppTextStyles.bodySmall),
              const SizedBox(width: 8),
              Text('${config?['emoji'] ?? ''} ${config?['label'] ?? '?'}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: (config?['color'] as Color? ?? Colors.grey))),
            ]),
          );
        }),
      ]),
    );
  }
}
