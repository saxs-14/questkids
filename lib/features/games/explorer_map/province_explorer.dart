import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../core/content_pack_loader.dart';
import '../core/game_config.dart';
import '../core/game_theme.dart';
import '../tug_of_war/widgets/game_result_overlay.dart';
import 'explorer_map_config.dart';
import 'explorer_map_session.dart';

/// SA Provinces Explorer — scaffolded Learn → Easy → Hard progression on a
/// code-drawn (no copyrighted assets) map of South Africa.
class ProvinceExplorer extends StatefulWidget {
  final GameConfig config;
  final dynamic user;

  const ProvinceExplorer({super.key, required this.config, required this.user});

  @override
  State<ProvinceExplorer> createState() => _ProvinceExplorerState();
}

class _ProvinceExplorerState extends State<ProvinceExplorer> {
  ExplorerMapSession? _session;
  ExplorerMode? _mode;

  bool _easyUnlocked = false;
  bool _hardUnlocked = false;
  Map<String, dynamic>? _pack;

  static const _kEasy = 'explorer_easy_unlocked';
  static const _kHard = 'explorer_hard_unlocked';

  String get _uid => (widget.user?.uid as String?) ?? '';

  @override
  void initState() {
    super.initState();
    _loadUnlocks();
    loadContentPack(widget.config).then((pack) {
      if (mounted) _pack = pack;
    });
  }

  Future<void> _loadUnlocks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _easyUnlocked = prefs.getBool(_kEasy) ?? false;
        _hardUnlocked = prefs.getBool(_kHard) ?? false;
      });
    } catch (_) {/* offline default: locked */}
  }

  Future<void> _unlock(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, true);
    } catch (_) {/* best effort */}
  }

  void _start(ExplorerMode mode) {
    final modeStr = mode.name;
    final cfg = widget.config.copyWith(
      extras: {...widget.config.extras, 'mode': modeStr},
    );
    setState(() {
      _mode = mode;
      _session = ExplorerMapSession(cfg, _uid, pack: _pack)..startSession();
    });
  }

  void _exitToHub({bool completed = false}) {
    final finishedMode = _mode;
    _session?.dispose();
    setState(() {
      _session = null;
      _mode = null;
    });
    if (completed && finishedMode == ExplorerMode.learn && !_easyUnlocked) {
      setState(() => _easyUnlocked = true);
      _unlock(_kEasy);
    } else if (completed && finishedMode == ExplorerMode.easy && !_hardUnlocked) {
      setState(() => _hardUnlocked = true);
      _unlock(_kHard);
    }
  }

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null || _mode == null) {
      return _ModeHub(
        easyUnlocked: _easyUnlocked,
        hardUnlocked: _hardUnlocked,
        onPick: _start,
        onClose: () => Navigator.of(context).pop(),
      );
    }

    return ChangeNotifierProvider.value(
      value: _session!,
      child: Consumer<ExplorerMapSession>(
        builder: (ctx, session, _) {
          if (session.isFinished && session.result != null) {
            return GameResultOverlay(
              result: session.result!,
              playerScore: session.correctCount,
              opponentScore: session.totalQuestions,
              opponentName: '',
              onPlayAgain: () => _start(_mode!),
              onContinue: () => _exitToHub(completed: true),
            );
          }
          switch (session.mode) {
            case ExplorerMode.learn:
              return _LearnView(session: session, onBack: _exitToHub);
            case ExplorerMode.easy:
              return _EasyView(session: session, onBack: _exitToHub);
            case ExplorerMode.hard:
              return _HardView(session: session, onBack: _exitToHub);
          }
        },
      ),
    );
  }
}

// ── Mode hub ─────────────────────────────────────────────────────────────────
class _ModeHub extends StatelessWidget {
  final bool easyUnlocked;
  final bool hardUnlocked;
  final void Function(ExplorerMode) onPick;
  final VoidCallback onClose;

  const _ModeHub({
    required this.easyUnlocked,
    required this.hardUnlocked,
    required this.onPick,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D47A1),
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
            const SizedBox(height: 8),
            const Text('🗺️', style: TextStyle(fontSize: 56)),
            Text('SA Provinces Explorer',
                style: GameTheme.display(24, color: Colors.white)),
            Text('Learn the map, then test yourself!',
                style: GameTheme.body(14, color: Colors.white70)),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _ModeCard(
                    emoji: '🧭',
                    title: 'Learn',
                    subtitle: 'Explore freely — tap each province to discover it',
                    locked: false,
                    onTap: () => onPick(ExplorerMode.learn),
                  ),
                  const SizedBox(height: 14),
                  _ModeCard(
                    emoji: '⭐',
                    title: 'Easy Quiz',
                    subtitle: 'A province lights up — pick its name',
                    locked: !easyUnlocked,
                    lockedHint: 'Finish Learn to unlock',
                    onTap: () => onPick(ExplorerMode.easy),
                  ),
                  const SizedBox(height: 14),
                  _ModeCard(
                    emoji: '🔥',
                    title: 'Hard Quiz',
                    subtitle: 'Read the clue — tap the right province on the map',
                    locked: !hardUnlocked,
                    lockedHint: 'Finish the Easy Quiz to unlock',
                    onTap: () => onPick(ExplorerMode.hard),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final bool locked;
  final String? lockedHint;
  final VoidCallback onTap;

  const _ModeCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.locked,
    required this.onTap,
    this.lockedHint,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: locked ? 0.55 : 1,
      child: Material(
        color: Colors.white,
        borderRadius: GameTheme.rounded,
        child: InkWell(
          borderRadius: GameTheme.rounded,
          onTap: locked ? null : onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 78),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 38)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: GameTheme.display(18,
                              color: AppColors.socialSciences)),
                      Text(
                        locked ? (lockedHint ?? 'Locked') : subtitle,
                        style: GameTheme.body(13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(locked ? Icons.lock : Icons.chevron_right,
                    color: AppColors.socialSciences),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared scaffold for the three mode views ──────────────────────────────────
class _ModeScaffold extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final Widget child;
  final double progress;

  const _ModeScaffold({
    required this.title,
    required this.onBack,
    required this.child,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D47A1),
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                Expanded(
                  child: Text(title,
                      textAlign: TextAlign.center,
                      style: GameTheme.display(17, color: Colors.white)),
                ),
                const SizedBox(width: 48),
              ],
            ),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white24,
              color: AppColors.socialSciences,
              minHeight: 6,
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

// ── Learn view ────────────────────────────────────────────────────────────────
class _LearnView extends StatelessWidget {
  final ExplorerMapSession session;
  final void Function({bool completed}) onBack;
  const _LearnView({required this.session, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final total = session.mapConfig.provinces.length;
    final info = session.infoProvince;
    return _ModeScaffold(
      title: 'Learn  •  ${session.discovered.length}/$total discovered',
      onBack: () => onBack(),
      progress: total == 0 ? 0 : session.discovered.length / total,
      child: Stack(
        children: [
          _MapStage(
            provinces: session.mapConfig.provinces,
            styleFor: (p) {
              final found = session.discovered.contains(p.id);
              return _PinStyle(
                color: found ? p.color : Colors.white24,
                label: found ? p.emoji : '?',
                opacity: found ? 1 : 0.85,
              );
            },
            onTap: (p) => session.discover(p.id),
          ),
          if (info != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _InfoCard(province: info)
                  .animate()
                  .fadeIn(duration: 200.ms)
                  .slideY(begin: 0.3, end: 0),
            ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final ProvincePin province;
  const _InfoCard({required this.province});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: GameTheme.rounded,
        boxShadow: GameTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(province.emoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(province.name,
                        style: GameTheme.display(20, color: province.color)),
                    if (province.capital.isNotEmpty)
                      Text('Capital: ${province.capital}',
                          style: GameTheme.body(13,
                              color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (province.facts.isNotEmpty)
            Text('💡 ${province.facts.first}',
                style: GameTheme.body(14, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

// ── Easy view (recognition) ────────────────────────────────────────────────────
class _EasyView extends StatelessWidget {
  final ExplorerMapSession session;
  final void Function({bool completed}) onBack;
  const _EasyView({required this.session, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final correct = session.currentCorrectProvince;
    return _ModeScaffold(
      title: 'Easy  •  ${session.questionIndex + 1}/${session.totalQuestions}',
      onBack: () => onBack(),
      progress: session.progressFraction,
      child: Column(
        children: [
          Expanded(
            flex: 5,
            child: _MapStage(
              provinces: session.mapConfig.provinces,
              styleFor: (p) {
                final isTarget = p.id == correct?.id;
                return _PinStyle(
                  color: isTarget ? AppColors.gold : p.color.withValues(alpha: 0.35),
                  label: p.emoji,
                  pulse: isTarget,
                  ring: isTarget ? AppColors.gold : null,
                );
              },
            ),
          ),
          if (session.feedbackFact != null)
            _FeedbackBanner(
              fact: session.feedbackFact!,
              correct: session.lastAnswerCorrect ?? false,
            ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text('Which province is highlighted?',
                      style: GameTheme.display(16, color: Colors.white)),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: session.currentOptions.map((p) {
                        final selected = session.selectedId == p.id;
                        Color bg = p.color;
                        if (selected) {
                          bg = (session.lastAnswerCorrect == true)
                              ? GameTheme.positive
                              : GameTheme.gentleMiss;
                        }
                        return GestureDetector(
                          onTap: session.awaitingNext
                              ? null
                              : () => session.submitAnswer(p.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            constraints: const BoxConstraints(
                                minHeight: GameTheme.minTapTarget),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 12),
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(
                                  color: selected ? Colors.white : Colors.white30,
                                  width: selected ? 2.5 : 1),
                            ),
                            child: Text(p.name,
                                style: GameTheme.display(15, color: Colors.white)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hard view (recall — tap on map) ─────────────────────────────────────────────
class _HardView extends StatelessWidget {
  final ExplorerMapSession session;
  final void Function({bool completed}) onBack;
  const _HardView({required this.session, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final lit = session.litProvinceIds;
    final correctId = session.currentCorrectProvince?.id;
    return _ModeScaffold(
      title: 'Hard  •  ${session.questionIndex + 1}/${session.totalQuestions}',
      onBack: () => onBack(),
      progress: session.progressFraction,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: GameTheme.rounded,
              ),
              child: Text(session.prompt,
                  textAlign: TextAlign.center,
                  style: GameTheme.display(16, color: AppColors.socialSciences)),
            ),
          ),
          Expanded(
            child: _MapStage(
              provinces: session.mapConfig.provinces,
              styleFor: (p) {
                final isLit = lit.contains(p.id);
                final selected = session.selectedId == p.id;
                Color color = isLit ? p.color : p.color.withValues(alpha: 0.18);
                Color? ring;
                if (session.awaitingNext) {
                  if (p.id == correctId) {
                    color = GameTheme.positive;
                    ring = Colors.white;
                  } else if (selected) {
                    color = GameTheme.gentleMiss;
                  }
                }
                return _PinStyle(
                  color: color,
                  label: p.emoji,
                  opacity: isLit ? 1 : 0.6,
                  ring: ring,
                );
              },
              onTap: session.awaitingNext ? null : (p) => session.submitAnswer(p.id),
            ),
          ),
          if (session.feedbackFact != null)
            _FeedbackBanner(
              fact: session.feedbackFact!,
              correct: session.lastAnswerCorrect ?? false,
            ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: OutlinedButton.icon(
              onPressed: session.hintActive || session.awaitingNext
                  ? null
                  : session.useHint,
              icon: const Icon(Icons.lightbulb_outline, color: Colors.white),
              label: Text(session.hintActive ? 'Hint used' : 'Use a hint',
                  style: GameTheme.body(14, color: Colors.white)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white54),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared map stage ────────────────────────────────────────────────────────────
class _PinStyle {
  final Color color;
  final String label;
  final bool pulse;
  final double opacity;
  final Color? ring;
  const _PinStyle({
    required this.color,
    required this.label,
    this.pulse = false,
    this.opacity = 1,
    this.ring,
  });
}

class _MapStage extends StatelessWidget {
  final List<ProvincePin> provinces;
  final _PinStyle Function(ProvincePin) styleFor;
  final void Function(ProvincePin)? onTap;

  const _MapStage({
    required this.provinces,
    required this.styleFor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final h = c.maxHeight;
      return Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CustomPaint(size: Size(w, h), painter: _MapBackdropPainter()),
            ),
          ),
          for (final p in provinces)
            Positioned(
              left: p.position.dx * (w - 56) + 16,
              top: p.position.dy * (h - 56) + 12,
              child: _Marker(
                pin: p,
                style: styleFor(p),
                onTap: onTap == null ? null : () => onTap!(p),
              ),
            ),
        ],
      );
    });
  }
}

class _Marker extends StatelessWidget {
  final ProvincePin pin;
  final _PinStyle style;
  final VoidCallback? onTap;

  const _Marker({required this.pin, required this.style, this.onTap});

  @override
  Widget build(BuildContext context) {
    Widget dot = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: GameTheme.minTapTarget,
      height: GameTheme.minTapTarget,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: style.opacity),
        shape: BoxShape.circle,
        border: Border.all(color: style.ring ?? Colors.white, width: style.ring != null ? 3 : 2),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 5)],
      ),
      child: Text(style.label, style: const TextStyle(fontSize: 18)),
    );

    if (style.pulse) {
      dot = dot
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(begin: 1, end: 1.18, duration: 700.ms, curve: Curves.easeInOut);
    }

    return Semantics(
      label: pin.name,
      button: onTap != null,
      child: GestureDetector(onTap: onTap, child: dot),
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  final String fact;
  final bool correct;
  const _FeedbackBanner({required this.fact, required this.correct});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: (correct ? GameTheme.positive : GameTheme.gentleMiss)
            .withValues(alpha: 0.95),
        borderRadius: GameTheme.rounded,
      ),
      child: Row(
        children: [
          Text(correct ? '✅' : '💡', style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(fact, style: GameTheme.body(13, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

/// Stylised explorer-map backdrop: ocean gradient, a soft landmass, a
/// latitude/longitude graticule, and a compass rose in the corner.
class _MapBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final ocean = Rect.fromLTWH(0, 0, w, h);
    canvas.drawRect(
      ocean,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1976D2), Color(0xFF0D47A1), Color(0xFF01579B)],
        ).createShader(ocean),
    );

    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = 1;
    for (double x = w * 0.1; x < w; x += w * 0.12) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), grid);
    }
    for (double y = h * 0.1; y < h; y += h * 0.14) {
      canvas.drawLine(Offset(0, y), Offset(w, y), grid);
    }

    final land = Path();
    land.moveTo(w * 0.30, h * 0.20);
    land.cubicTo(w * 0.55, h * 0.10, w * 0.80, h * 0.22, w * 0.78, h * 0.45);
    land.cubicTo(w * 0.76, h * 0.70, w * 0.58, h * 0.88, w * 0.42, h * 0.80);
    land.cubicTo(w * 0.24, h * 0.72, w * 0.18, h * 0.45, w * 0.22, h * 0.34);
    land.cubicTo(w * 0.24, h * 0.26, w * 0.26, h * 0.22, w * 0.30, h * 0.20);
    land.close();
    canvas.drawPath(
        land, Paint()..color = const Color(0xFF66BB6A).withValues(alpha: 0.55));
    canvas.drawPath(
      land,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final cc = Offset(w * 0.12, h * 0.14);
    const r = 16.0;
    final rosePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(cc, r, rosePaint);
    for (int i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      canvas.drawLine(cc + Offset(math.cos(a), math.sin(a)) * r,
          cc - Offset(math.cos(a), math.sin(a)) * r, rosePaint);
    }
    final needle = Path()
      ..moveTo(cc.dx, cc.dy - r - 4)
      ..lineTo(cc.dx - 4, cc.dy)
      ..lineTo(cc.dx + 4, cc.dy)
      ..close();
    canvas.drawPath(needle, Paint()..color = const Color(0xFFFF5252));
  }

  @override
  bool shouldRepaint(_MapBackdropPainter old) => false;
}
