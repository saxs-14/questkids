import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../games/core/game_config.dart';
import '../../../core/constants/game_catalog.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../games/core/game_router.dart';
import '../../../providers/auth_provider.dart';
import '../../dashboard/screens/grade1_world_map.dart';

// ─────────────────────────────────────────────────────────────────────────────

class QuestsScreen extends StatefulWidget {
  final bool embedded;
  const QuestsScreen({super.key, this.embedded = false});

  @override
  State<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends State<QuestsScreen> {
  String? _selectedSubject;

  // Grade-specific subject lists per CAPS curriculum
  static const _gradeSubjects = {
    'foundation': [   // Grade 1-3
      {'label': 'Mathematics',   'emoji': '🔢', 'color': AppColors.math},
      {'label': 'English',       'emoji': '📖', 'color': AppColors.english},
      {'label': 'Life Skills',   'emoji': '🌟', 'color': AppColors.lifeSkills},
    ],
    'intermediate': [ // Grade 4-6
      {'label': 'Mathematics',             'emoji': '🔢', 'color': AppColors.math},
      {'label': 'English',                 'emoji': '📖', 'color': AppColors.english},
      {'label': 'Life Skills',             'emoji': '🌟', 'color': AppColors.lifeSkills},
      {'label': 'Social Sciences',         'emoji': '🌍', 'color': AppColors.socialSciences},
      {'label': 'Natural Sciences',        'emoji': '🔬', 'color': AppColors.science},
    ],
    'senior': [       // Grade 7
      {'label': 'Mathematics',      'emoji': '🔢', 'color': AppColors.math},
      {'label': 'English',          'emoji': '📖', 'color': AppColors.english},
      {'label': 'Life Skills',      'emoji': '🌟', 'color': AppColors.lifeSkills},
      {'label': 'Social Sciences',  'emoji': '🌍', 'color': AppColors.socialSciences},
      {'label': 'Natural Sciences', 'emoji': '🔬', 'color': AppColors.science},
      {'label': 'Technology',       'emoji': '⚙️', 'color': AppColors.technology},
      {'label': 'EMS',              'emoji': '💰', 'color': Color(0xFF009688)},
    ],
  };

  static String _phaseFor(String gradeKey) {
    final n = int.tryParse(gradeKey.replaceAll(RegExp(r'[^0-9]'), '')) ?? 4;
    if (n <= 3) return 'foundation';
    if (n <= 6) return 'intermediate';
    return 'senior';
  }

  List<Map<String, Object>> _subjectsFor(String gradeKey) =>
      List<Map<String, Object>>.from(
          _gradeSubjects[_phaseFor(gradeKey)] ?? _gradeSubjects['intermediate']!);

  String _defaultSubject(String gradeKey) =>
      (_subjectsFor(gradeKey).first['label'] as String);

  List<GameCatalogEntry> _filteredGames(String gradeKey) {
    final subject = _selectedSubject ?? _defaultSubject(gradeKey);
    return GameCatalog.forGrade(gradeKey)
        .where((g) => g.subject == subject)
        .toList();
  }

  void _launchGame(GameCatalogEntry entry, String grade) {
    final config = _buildConfig(entry, grade);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameRouter(
          config: config,
          user: context.read<AuthProvider>().user,
        ),
      ),
    );
  }

  GameConfig _buildConfig(GameCatalogEntry entry, String grade) {
    return GameConfig(
      engineType: entry.engineType,
      subject: entry.subject,
      grade: grade,
      topicId: entry.topicId,
      subtopicId: entry.subtopicId,
      difficulty: entry.difficulty,
      extras: entry.extras,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final grade = user?.grade ?? 'grade4';
    final gradeKey = grade.toLowerCase().replaceAll(' ', '');

    // Grade 1 gets the immersive world map instead of subject tabs
    if (gradeKey == 'grade1') {
      return const Grade1WorldMap();
    }

    final subjects = _subjectsFor(gradeKey);
    final activeSubject = _selectedSubject ?? _defaultSubject(gradeKey);
    final featured = GameCatalog.featured(gradeKey);
    final games = _filteredGames(gradeKey);

    final body = Column(
      children: [
        // ── Subject tabs (grade-specific, no "All") ───────────────────────────
        Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: subjects.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final f = subjects[i];
                final label = f['label'] as String;
                final emoji = f['emoji'] as String;
                final color = f['color'] as Color;
                final selected = activeSubject == label;

                return GestureDetector(
                  onTap: () => setState(() => _selectedSubject = label),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? color : color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: selected ? color : color.withValues(alpha: 0.30),
                        width: 1.5,
                      ),
                      boxShadow: selected
                          ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 15)),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: selected ? Colors.white : color,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // ── Scrollable body ───────────────────────────────────────────────────
        Expanded(
          child: CustomScrollView(
            slivers: [
              if (featured.isNotEmpty)
                SliverToBoxAdapter(
                  child: _FeaturedBanner(
                    entries: featured,
                    onPlay: (e) => _launchGame(e, gradeKey),
                  ),
                ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    children: [
                      Text(subjects.firstWhere((s) => s['label'] == activeSubject,
                              orElse: () => subjects.first)['emoji'] as String,
                          style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 8),
                      Text(activeSubject, style: AppTextStyles.h3),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${games.length} games',
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.primary, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              if (games.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Center(
                      child: Column(
                        children: [
                          const Text('🎯', style: TextStyle(fontSize: 64)),
                          const SizedBox(height: 16),
                          Text('Games coming soon!', style: AppTextStyles.h3),
                          const SizedBox(height: 4),
                          Text(
                            'More $activeSubject games are on their way',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.crossAxisExtent > 600 ? 3 : 2;
                      return SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _GameCard(
                            entry: games[index],
                            onTap: () => _launchGame(games[index], gradeKey),
                          ),
                          childCount: games.length,
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.72,
                        ),
                      );
                    },
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ],
    );

    if (widget.embedded) return body;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Game Hub',
          style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
        ),
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                const Text('⭐', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 4),
                Text(
                  '${user?.totalPoints ?? 0} XP',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.goldDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: body,
    );
  }
}

// ─── Featured Banner ──────────────────────────────────────────────────────────

class _FeaturedBanner extends StatefulWidget {
  final List<GameCatalogEntry> entries;
  final void Function(GameCatalogEntry) onPlay;

  const _FeaturedBanner({required this.entries, required this.onPlay});

  @override
  State<_FeaturedBanner> createState() => _FeaturedBannerState();
}

class _FeaturedBannerState extends State<_FeaturedBanner> {
  final PageController _pageController = PageController(viewportFraction: 0.92);
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<Color> _gradientForSubject(String subject) {
    switch (subject) {
      case 'Mathematics':
        return AppColors.mathGradient;
      case 'Natural Sciences':
        return AppColors.sciGradient;
      case 'English':
        return AppColors.engGradient;
      case 'Social Sciences':
        return AppColors.sscGradient;
      default:
        return AppColors.heroGradient;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text('Featured Games', style: AppTextStyles.h3),
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.entries.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (_, i) {
              final entry = widget.entries[i];
              final gradient = _gradientForSubject(entry.subject);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: GestureDetector(
                  onTap: () => widget.onPlay(entry),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradient,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: gradient.first.withValues(alpha: 0.40),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -20,
                          top: -20,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 30,
                          bottom: -30,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.20),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        entry.grades.length > 1
                                            ? 'All Grades'
                                            : entry.grade.replaceAll('grade', 'Grade '),
                                        style: GoogleFonts.nunito(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      entry.title,
                                      style: GoogleFonts.nunito(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      entry.description,
                                      style: GoogleFonts.nunito(
                                        fontSize: 12,
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () => widget.onPlay(entry),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              'PLAY NOW',
                                              style: GoogleFonts.nunito(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: gradient.first,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.20),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '⭐ ${entry.xpReward} XP',
                                            style: GoogleFonts.nunito(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 12),
                              Text(
                                entry.emoji,
                                style: const TextStyle(fontSize: 72),
                              ),
                            ],
                          ),
                        ),

                        if (entry.isNew)
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'NEW',
                                style: GoogleFonts.nunito(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        if (widget.entries.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.entries.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentPage == i ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

// ─── Game Card ────────────────────────────────────────────────────────────────

class _GameCard extends StatelessWidget {
  final GameCatalogEntry entry;
  final VoidCallback onTap;

  const _GameCard({required this.entry, required this.onTap});

  List<Color> _gradientForSubject(String subject) {
    switch (subject) {
      case 'Mathematics':
        return AppColors.mathGradient;
      case 'Natural Sciences':
        return AppColors.sciGradient;
      case 'English':
        return AppColors.engGradient;
      case 'Social Sciences':
        return AppColors.sscGradient;
      case 'Technology':
        return [AppColors.technology, const Color(0xFF9C64FF)];
      case 'Life Skills':
        return [AppColors.lifeSkills, const Color(0xFFFFCC02)];
      default:
        return AppColors.heroGradient;
    }
  }

  Widget _difficultyStars(String difficulty) {
    final count = difficulty == 'easy' ? 1 : difficulty == 'medium' ? 2 : 3;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Text(
          '★',
          style: TextStyle(
            fontSize: 12,
            color: i < count
                ? AppColors.goldDark
                : AppColors.textSecondary.withValues(alpha: 0.30),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gradient = _gradientForSubject(entry.subject);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardLight,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: gradient,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -16,
                    bottom: -16,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      entry.emoji,
                      style: const TextStyle(fontSize: 48),
                    ),
                  ),
                  if (entry.isNew)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'NEW',
                          style: GoogleFonts.nunito(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.description,
                      style: GoogleFonts.nunito(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: gradient.first.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        entry.subject,
                        style: GoogleFonts.nunito(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: gradient.first,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _difficultyStars(entry.difficulty),
                        const Spacer(),
                        Row(
                          children: [
                            const Text('⭐', style: TextStyle(fontSize: 10)),
                            const SizedBox(width: 2),
                            Text(
                              '${entry.xpReward}',
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.goldDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
