import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/game_catalog.dart';
import '../../games/core/game_config.dart';
import '../../games/core/game_intro_sheet.dart';
import '../../games/core/game_router.dart';
import '../../../providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Grade 1 World Map  — animated illustrated map showing 13 game locations.
// Each location card launches the matching game engine.
// ─────────────────────────────────────────────────────────────────────────────

class Grade1WorldMap extends StatefulWidget {
  const Grade1WorldMap({super.key});

  @override
  State<Grade1WorldMap> createState() => _Grade1WorldMapState();
}

class _Grade1WorldMapState extends State<Grade1WorldMap>
    with TickerProviderStateMixin {
  late AnimationController _cloudCtrl;
  late AnimationController _pulseCtrl;

  static const _mathColor    = Color(0xFFFF8C00);
  static const _englishColor = Color(0xFF5C35F5);
  static const _lsColor      = Color(0xFF2E7D32);

  // 13 world-map locations in display order (snake path)
  static const _locations = [
    _Loc('math_g1_counting',  '🏟️', 'The Arena',       _mathColor,    'Mathematics'),
    _Loc('math_g1_addition',  '🏝️', 'Treasure Island', _mathColor,    'Mathematics'),
    _Loc('math_g1_subtraction','🦁', 'Safari Park',     _mathColor,    'Mathematics'),
    _Loc('math_g1_mountain',  '⛰️', 'Mountain Peak',   _mathColor,    'Mathematics'),
    _Loc('math_g1_multiples', '⚙️', 'Magic Workshop',  _mathColor,    'Mathematics'),
    _Loc('eng_g1_phonics',    '🔤', 'Alphabet Castle', _englishColor, 'English'),
    _Loc('eng_g1_reading',    '🌈', 'Rainbow Kingdom', _englishColor, 'English'),
    _Loc('eng_g1_grammar',    '🌻', 'Magic Garden',    _englishColor, 'English'),
    _Loc('ls_g1_body',        '🧍', 'Health Lab',      _lsColor,      'Life Skills'),
    _Loc('ls_g1_feelings',    '😊', 'Emotion Factory', _lsColor,      'Life Skills'),
    _Loc('ls_g1_safety',      '🦸', 'Hero HQ',         _lsColor,      'Life Skills'),
    _Loc('ls_g1_community',   '🏘️', 'Community Town',  _lsColor,      'Life Skills'),
    _Loc('ls_g1_habits',      '🍎', 'Healthy City',    _lsColor,      'Life Skills'),
  ];

  // Winding path positions: 0=left  1=center  2=right
  static const _positions = [1, 0, 2, 0, 2, 1, 0, 2, 1, 0, 2, 0, 2];

  @override
  void initState() {
    super.initState();
    _cloudCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _cloudCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _launch(String catalogId) {
    final entry = GameCatalog.all.where((e) => e.id == catalogId).firstOrNull;
    if (entry == null) return;
    final user = context.read<AuthProvider>().user;

    GameIntroSheet.show(
      context,
      entry: entry,
      onStart: () {
        final config = GameConfig(
          engineType: entry.engineType,
          subject:    entry.subject,
          grade:      user?.grade ?? 'grade1',
          topicId:    entry.topicId,
          subtopicId: entry.subtopicId,
          difficulty: entry.difficulty,
          extras:     entry.extras,
          catalogId:  entry.id,
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GameRouter(config: config, user: user)),
        );
      },
    );
  }

  // Which subject group this index belongs to
  static String _subjectAt(int i) => _locations[i].subject;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return Stack(
      children: [
        // ── Sky + hills background ─────────────────────────────────────────
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF42A5F5), Color(0xFF80CBC4), Color(0xFFA5D6A7)],
                stops: [0.0, 0.35, 0.70, 1.0],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),

        // ── Animated clouds ────────────────────────────────────────────────
        AnimatedBuilder(
          animation: _cloudCtrl,
          builder: (_, __) {
            final dx = _cloudCtrl.value * w * 1.5;
            return Stack(
              children: [
                Positioned(top: 30,  left: dx - w * 0.1,  child: _Cloud(size: 80,  opacity: 0.45)),
                Positioned(top: 60,  left: dx - w * 0.55, child: _Cloud(size: 110, opacity: 0.35)),
                Positioned(top: 18,  left: dx + w * 0.40, child: _Cloud(size: 65,  opacity: 0.40)),
                Positioned(top: 90,  left: dx - w * 0.80, child: _Cloud(size: 95,  opacity: 0.30)),
              ],
            );
          },
        ),

        // ── Scrollable map content ─────────────────────────────────────────
        CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(child: _MapHeader()),

            // Game items
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    if (i >= _locations.length) return null;

                    // Subject section divider before first game of each group
                    final isFirst = i == 0 || _subjectAt(i) != _subjectAt(i - 1);
                    final loc  = _locations[i];
                    final pos  = _positions[i];
                    final entry = GameCatalog.all.where((e) => e.id == loc.id).firstOrNull;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (isFirst) _SubjectBanner(subject: loc.subject, color: loc.color),

                        // Game node + connector arrow below (except last)
                        _GameNode(
                          loc: loc,
                          entry: entry,
                          position: pos,
                          pulseCtrl: _pulseCtrl,
                          onTap: () => _launch(loc.id),
                        ),

                        if (i < _locations.length - 1)
                          _PathArrow(
                            fromPos: pos,
                            toPos: _positions[i + 1],
                            fromColor: loc.color,
                            toColor: _locations[i + 1].color,
                          ),
                      ],
                    );
                  },
                  childCount: _locations.length,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data record for each world-map location
// ─────────────────────────────────────────────────────────────────────────────

class _Loc {
  final String id;
  final String emoji;
  final String location;
  final Color color;
  final String subject;

  const _Loc(this.id, this.emoji, this.location, this.color, this.subject);
}

// ─────────────────────────────────────────────────────────────────────────────
// Map header
// ─────────────────────────────────────────────────────────────────────────────

class _MapHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 170,
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
      child: Column(
        children: [
          const Text('✨ Learning World ✨',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                  shadows: [Shadow(color: Color(0x880D47A1), blurRadius: 12, offset: Offset(0, 3))])),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Grade 1 — 13 Adventures await!',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Subject section banner (Mathematics / English / Life Skills)
// ─────────────────────────────────────────────────────────────────────────────

class _SubjectBanner extends StatelessWidget {
  final String subject;
  final Color color;

  const _SubjectBanner({required this.subject, required this.color});

  static const _icons = {
    'Mathematics': '🔢',
    'English':     '📖',
    'Life Skills': '🌟',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        children: [
          Expanded(child: Container(height: 2, decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color.withValues(alpha: 0), color]),
          ))),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.40), blurRadius: 12, offset: const Offset(0, 3))],
            ),
            child: Text(
              '${_icons[subject] ?? '📚'} $subject',
              style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5),
            ),
          ),
          Expanded(child: Container(height: 2, decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withValues(alpha: 0)]),
          ))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual game node (location card)
// position: 0=left  1=center  2=right
// ─────────────────────────────────────────────────────────────────────────────

class _GameNode extends StatelessWidget {
  final _Loc loc;
  final GameCatalogEntry? entry;
  final int position;      // 0/1/2
  final AnimationController pulseCtrl;
  final VoidCallback onTap;

  const _GameNode({
    required this.loc,
    required this.entry,
    required this.position,
    required this.pulseCtrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final xp = entry?.xpReward ?? 50;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: switch (position) {
          0 => MainAxisAlignment.start,
          2 => MainAxisAlignment.end,
          _ => MainAxisAlignment.center,
        },
        children: [
          GestureDetector(
            onTap: onTap,
            child: AnimatedBuilder(
              animation: pulseCtrl,
              builder: (_, child) {
                final scale = 1.0 + pulseCtrl.value * 0.03;
                return Transform.scale(scale: scale, child: child);
              },
              child: Container(
                width: 155,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [loc.color, _darken(loc.color, 0.2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: loc.color.withValues(alpha: 0.50),
                      blurRadius: 16,
                      offset: const Offset(0, 5),
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.12),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Emoji circle
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.40), width: 2),
                      ),
                      child: Center(
                        child: Text(loc.emoji, style: const TextStyle(fontSize: 28)),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Game title
                    Text(
                      entry?.title ?? loc.id,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Location name
                    Text(
                      loc.location,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.80),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // XP badge + PLAY button row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '⭐ $xp XP',
                            style: const TextStyle(
                              color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'PLAY',
                            style: TextStyle(
                              color: loc.color,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _darken(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Path arrow connector between two game nodes
// ─────────────────────────────────────────────────────────────────────────────

class _PathArrow extends StatelessWidget {
  final int fromPos;
  final int toPos;
  final Color fromColor;
  final Color toColor;

  const _PathArrow({
    required this.fromPos,
    required this.toPos,
    required this.fromColor,
    required this.toColor,
  });

  @override
  Widget build(BuildContext context) {
    // Arrow direction text based on position movement
    final icon = (toPos > fromPos) ? '↘' : (toPos < fromPos) ? '↙' : '↓';
    final align = switch (fromPos) {
      0 => Alignment.centerLeft,
      2 => Alignment.centerRight,
      _ => Alignment.center,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Align(
        alignment: align,
        child: Padding(
          padding: const EdgeInsets.only(left: 20, right: 20),
          child: Text(
            icon,
            style: TextStyle(
              fontSize: 24,
              color: fromColor.withValues(alpha: 0.70),
              shadows: [Shadow(color: Colors.black.withValues(alpha: 0.20), blurRadius: 4)],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fluffy cloud shape
// ─────────────────────────────────────────────────────────────────────────────

class _Cloud extends StatelessWidget {
  final double size;
  final double opacity;

  const _Cloud({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: SizedBox(
        width: size * 1.8,
        height: size * 0.7,
        child: CustomPaint(painter: _CloudPainter()),
      ),
    );
  }
}

class _CloudPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white;
    final cx = size.width / 2;
    final cy = size.height * 0.6;
    final r  = size.height * 0.5;
    canvas.drawCircle(Offset(cx, cy), r, p);
    canvas.drawCircle(Offset(cx - r * 0.8, cy + r * 0.1), r * 0.75, p);
    canvas.drawCircle(Offset(cx + r * 0.8, cy + r * 0.1), r * 0.75, p);
    canvas.drawCircle(Offset(cx - r * 0.4, cy - r * 0.4), r * 0.65, p);
    canvas.drawCircle(Offset(cx + r * 0.5, cy - r * 0.35), r * 0.60, p);
    canvas.drawRect(
      Rect.fromLTRB(cx - r * 1.6, cy, cx + r * 1.6, cy + r * 0.5),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
