import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/game_catalog.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/ai_tutor_provider.dart';
import '../../../providers/rewards_provider.dart';
import '../../../core/widgets/profile_avatar_picker.dart';
import '../../../core/widgets/responsive_scaffold.dart';
import '../../../core/widgets/app_side_menu.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/profile_settings_tile.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../offline/widgets/offline_banner.dart';
import '../../offline/widgets/sync_button.dart';
import '../../offline/screens/offline_screen.dart';
import '../../quests/screens/quests_screen.dart';
import '../../rewards/screens/rewards_screen.dart';
import '../../ai_tutor/screens/ai_tutor_screen.dart';
import '../../ai_tutor/widgets/recommendation_card.dart';
import '../../parent/widgets/child_qr_code.dart';
import '../../games/core/game_config.dart';
import '../../games/core/game_intro_sheet.dart';
import '../../games/core/game_router.dart';
import '../../games/core/game_theme.dart';
import '../widgets/daily_missions_card.dart';
import '../../../providers/mission_provider.dart';

// ---------------------------------------------------------------------------
// Inline color constants (brand palette for the gaming dashboard)
// ---------------------------------------------------------------------------
class _DC {
  static const Color heroGradientStart = Color(0xFF5C35F5);
  static const Color heroGradientEnd = Color(0xFF9C27B0);
  static const Color mathColor = Color(0xFFFF6B35);
  static const Color scienceColor = Color(0xFF00BFA5);
  static const Color englishColor = Color(0xFFE91E63);
  static const Color gold = Color(0xFFFFD700);
  static const Color challengeStart = Color(0xFFFF8C00);
  static const Color challengeEnd = Color(0xFFFFBF00);
  static const Color coinColor = Color(0xFFFFD700);
  static const Color streakColor = Color(0xFFFF6D00);
  static const Color badgeColor = Color(0xFF7C4DFF);
}

// ---------------------------------------------------------------------------
// Root widget
// ---------------------------------------------------------------------------
class LearnerDashboard extends StatefulWidget {
  const LearnerDashboard({super.key});

  @override
  State<LearnerDashboard> createState() => _LearnerDashboardState();
}

class _LearnerDashboardState extends State<LearnerDashboard> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthProvider>().user?.uid;
      if (uid != null) {
        context.read<RewardsProvider>()
          ..loadRewards(uid)
          ..watchRewards(uid);
        context.read<MissionProvider>().watchMissions(uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    final user = auth.user;

    return ResponsiveScaffold(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (i) => setState(() => _selectedIndex = i),
      drawer: AppSideMenu(user: user),
      destinations: const [
        ResponsiveDestination(
            icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
        ResponsiveDestination(
            icon: Icons.explore_outlined,
            activeIcon: Icons.explore,
            label: 'Quests'),
        ResponsiveDestination(
            icon: Icons.emoji_events_outlined,
            activeIcon: Icons.emoji_events,
            label: 'Rewards'),
        ResponsiveDestination(
            icon: Icons.smart_toy_outlined,
            activeIcon: Icons.smart_toy,
            label: 'Questy'),
        ResponsiveDestination(
            icon: Icons.person_outline,
            activeIcon: Icons.person,
            label: 'Profile'),
        ResponsiveDestination(
            icon: Icons.offline_pin_outlined,
            activeIcon: Icons.offline_pin,
            label: 'Offline'),
      ],
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'QuestKids',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Text(
              user?.grade ?? 'Grade 1',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(theme.isDark ? Icons.wb_sunny : Icons.nightlight_round),
            onPressed: theme.toggleTheme,
          ),
          const SyncButton(),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => setState(() => _selectedIndex = 4),
              child: CircleAvatar(
                backgroundColor: Colors.white24,
                backgroundImage: user?.avatarUrl != null
                    ? NetworkImage(user!.avatarUrl!)
                    : null,
                child: user?.avatarUrl == null
                    ? Text(
                        user?.name.isNotEmpty == true
                            ? user!.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _LearnerHomeTab(user: user),
                const _QuestsTab(),
                const _RewardsTab(),
                const _AiTutorTab(),
                _ProfileTab(user: user),
                const _OfflineTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Home Tab — scrollable column of gaming sections
// ---------------------------------------------------------------------------
class _LearnerHomeTab extends StatelessWidget {
  final dynamic user;

  const _LearnerHomeTab({required this.user});

  double get _xpProgress {
    final pts = (user?.totalPoints as int?) ?? 0;
    return (pts % 100) / 100.0;
  }

  int get _level => ((user?.totalPoints as int?) ?? 0) ~/ 100 + 1;
  int get _totalPoints => (user?.totalPoints as int?) ?? 0;
  int get _streakDays => (user?.streakDays as int?) ?? 0;
  int get _coins => (user?.totalPoints as int?) ?? 0;

  String get _firstName {
    final name = user?.name as String?;
    if (name == null || name.isEmpty) return 'Learner';
    return name.split(' ').first;
  }

  String get _grade => (user?.grade as String?) ?? 'Grade 1';

  @override
  Widget build(BuildContext context) {
    final rewards = context.watch<RewardsProvider>();
    final badgeCount = rewards.badges.length;
    final gradeKey = _grade.toLowerCase().replaceAll(' ', '');

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroSection(
            firstName: _firstName,
            grade: _grade,
            level: _level,
            totalPoints: _totalPoints,
            xpProgress: _xpProgress,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _StatsRow(
                    coins: _coins,
                    streakDays: _streakDays,
                    badgeCount: badgeCount),
                const SizedBox(height: 24),
                const DailyMissionsCard(),
                const SizedBox(height: 24),
                _DailyChallengeCard(user: user),
                const SizedBox(height: 24),
                _QuestyTipCard(user: user),
                const SizedBox(height: 24),
              ],
            ),
          ),
          _FeaturedGamesSection(gradeKey: gradeKey),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProgressSection(rewards: rewards, gradeKey: gradeKey),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero Section
// ---------------------------------------------------------------------------
class _HeroSection extends StatelessWidget {
  final String firstName;
  final String grade;
  final int level;
  final int totalPoints;
  final double xpProgress;

  const _HeroSection({
    required this.firstName,
    required this.grade,
    required this.level,
    required this.totalPoints,
    required this.xpProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_DC.heroGradientStart, _DC.heroGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello $firstName! 👋',
                  style: AppTextStyles.h2.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ready to learn today?',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: Colors.white.withValues(alpha: 0.80)),
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    grade,
                    style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              SizedBox(
                width: 88,
                height: 88,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 6,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withValues(alpha: 0.25)),
                    ),
                    CircularProgressIndicator(
                      value: xpProgress,
                      strokeWidth: 6,
                      valueColor: const AlwaysStoppedAnimation<Color>(_DC.gold),
                      strokeCap: StrokeCap.round,
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$level',
                          style: AppTextStyles.h2.copyWith(
                              color: Colors.white, fontSize: 28, height: 1.0),
                        ),
                        Text(
                          'LVL',
                          style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '⭐ $totalPoints XP',
                style: AppTextStyles.bodySmall.copyWith(
                    color: _DC.gold, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats Row  — three Expanded cards inside a bounded Row (no scroll)
// ---------------------------------------------------------------------------
class _StatsRow extends StatelessWidget {
  final int coins;
  final int streakDays;
  final int badgeCount;

  const _StatsRow(
      {required this.coins,
      required this.streakDays,
      required this.badgeCount});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.07) : Colors.white;
    final shadow =
        isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.06);

    Widget card({
      required String emoji,
      required String label,
      required String value,
      required Color accentColor,
    }) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: accentColor.withValues(alpha: 0.25), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: shadow, blurRadius: 8, offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 4),
              Text(
                value,
                style:
                    AppTextStyles.h4.copyWith(color: accentColor, fontSize: 16),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        card(
            emoji: '🪙',
            label: 'Coins',
            value: '$coins',
            accentColor: _DC.coinColor),
        const SizedBox(width: 10),
        card(
            emoji: '🔥',
            label: 'Streak',
            value: '${streakDays}d',
            accentColor: _DC.streakColor),
        const SizedBox(width: 10),
        card(
            emoji: '🏅',
            label: 'Badges',
            value: '$badgeCount',
            accentColor: _DC.badgeColor),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Daily Challenge Card
// ---------------------------------------------------------------------------
class _DailyChallengeCard extends StatelessWidget {
  final dynamic user;
  const _DailyChallengeCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final rewards = context.watch<RewardsProvider>();
    final completed = rewards.questsCompleted % 3;
    const target = 3;
    final progress = completed / target;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_DC.challengeStart, _DC.challengeEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _DC.challengeStart.withValues(alpha: 0.40),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '🎯 Daily Challenge',
              style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 11),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Complete $target games today',
            style: AppTextStyles.h4.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.30),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$completed / $target completed',
            style: AppTextStyles.bodySmall.copyWith(
                color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QuestsScreen()),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _DC.challengeStart,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(
                completed >= target ? '✅ Done!' : 'Start',
                style: AppTextStyles.button
                    .copyWith(color: _DC.challengeStart, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Questy's Tip — proactive, once-a-day recommendation on the home tab so
// Questy isn't only reachable from its own dashboard destination.
// ---------------------------------------------------------------------------
class _QuestyTipCard extends StatefulWidget {
  final dynamic user;
  const _QuestyTipCard({required this.user});

  @override
  State<_QuestyTipCard> createState() => _QuestyTipCardState();
}

class _QuestyTipCardState extends State<_QuestyTipCard> {
  static const _dateKey = 'questy_tip_date';
  static const _textKey = 'questy_tip_text';

  String? _tip;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTip());
  }

  String get _today {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadTip() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedDate = prefs.getString(_dateKey);
    final cachedText = prefs.getString(_textKey);

    if (cachedDate == _today && cachedText != null && cachedText.isNotEmpty) {
      if (mounted) {
        setState(() {
          _tip = cachedText;
          _loading = false;
        });
      }
      return;
    }

    if (!mounted) return;
    final rewards = context.read<RewardsProvider>();
    final subjectScores = <String, int>{};
    for (final entry in rewards.subjectCounts.entries) {
      subjectScores[entry.key] = (entry.value * 20).clamp(0, 100);
    }

    final tutor = context.read<AiTutorProvider>();
    await tutor.loadRecommendation(
      name: _firstNameOf(widget.user),
      grade: (widget.user?.grade as String?) ?? 'Grade 1',
      subjectScores: subjectScores,
      streakDays: rewards.streakDays,
      totalPoints: rewards.totalPoints,
    );

    final tip = tutor.recommendation;
    if (tip != null && tip.isNotEmpty) {
      await prefs.setString(_dateKey, _today);
      await prefs.setString(_textKey, tip);
    }
    if (mounted) {
      setState(() {
        _tip = tip;
        _loading = false;
      });
    }
  }

  String _firstNameOf(dynamic user) {
    final name = user?.name as String?;
    if (name == null || name.isEmpty) return 'Learner';
    return name.split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && (_tip == null || _tip!.isEmpty)) {
      return const SizedBox.shrink();
    }
    return RecommendationCard(
      recommendation: _tip ?? '',
      isLoading: _loading,
    );
  }
}

// ---------------------------------------------------------------------------
// Featured Games — reads from GameCatalog for the learner's grade
// ---------------------------------------------------------------------------
class _FeaturedGamesSection extends StatelessWidget {
  final String gradeKey;
  const _FeaturedGamesSection({required this.gradeKey});

  List<Color> _gradientForSubject(String subject) {
    return switch (subject) {
      'Mathematics' => const [Color(0xFFFF6B35), Color(0xFFFF8C66)],
      'Natural Sciences' => const [Color(0xFF00BFA5), Color(0xFF00E5CC)],
      'English' => const [Color(0xFFE91E63), Color(0xFFFF4081)],
      'Social Sciences' => const [Color(0xFF43A047), Color(0xFF66BB6A)],
      'Technology' => const [Color(0xFF7C4DFF), Color(0xFF9C6FFF)],
      'EMS' => const [Color(0xFF009688), Color(0xFF26A69A)],
      'Life Skills' => const [Color(0xFFFF9800), Color(0xFFFFB74D)],
      _ => const [Color(0xFF5C35F5), Color(0xFF9C27B0)],
    };
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    var featured = GameCatalog.featured(gradeKey);
    if (featured.isEmpty)
      featured = GameCatalog.forGrade(gradeKey).take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('🎮 Play Now', style: AppTextStyles.h3),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: featured.length,
            itemBuilder: (context, index) {
              final entry = featured[index];
              final gradient = _gradientForSubject(entry.subject);
              return Padding(
                padding: const EdgeInsets.only(right: 14),
                child: _CatalogGameCard(
                  entry: entry,
                  gradient: gradient,
                  user: user,
                  gradeKey: gradeKey,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CatalogGameCard extends StatelessWidget {
  final GameCatalogEntry entry;
  final List<Color> gradient;
  final dynamic user;
  final String gradeKey;

  const _CatalogGameCard({
    required this.entry,
    required this.gradient,
    required this.user,
    required this.gradeKey,
  });

  void _launch(BuildContext context) {
    GameIntroSheet.show(
      context,
      entry: entry,
      onStart: () {
        final config = GameConfig(
          engineType: entry.engineType,
          subject: entry.subject,
          grade: gradeKey,
          topicId: entry.topicId,
          subtopicId: entry.subtopicId,
          difficulty: entry.difficulty,
          extras: entry.extras,
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GameRouter(config: config, user: user),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _launch(context),
      child: Container(
        width: 160,
        height: 180,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.40),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(entry.emoji, style: const TextStyle(fontSize: 48)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        engineIdentityFor(entry.engineType).icon,
                        size: 12,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          engineIdentityFor(entry.engineType).tagline,
                          style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w600,
                              fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
    );
  }
}

// ---------------------------------------------------------------------------
// Progress Section — reads from RewardsProvider.subjectCounts
// ---------------------------------------------------------------------------
class _ProgressSection extends StatelessWidget {
  final RewardsProvider rewards;
  final String gradeKey;
  const _ProgressSection({required this.rewards, required this.gradeKey});

  static const _foundation = [
    {
      'key': 'Mathematics',
      'label': 'Maths',
      'emoji': '🔢',
      'color': _DC.mathColor,
      'max': 5
    },
    {
      'key': 'English',
      'label': 'English',
      'emoji': '📖',
      'color': _DC.englishColor,
      'max': 5
    },
    {
      'key': 'Life Skills',
      'label': 'Life Skills',
      'emoji': '🌟',
      'color': Color(0xFFFF9800),
      'max': 5
    },
  ];
  static const _intermediate = [
    {
      'key': 'Mathematics',
      'label': 'Maths',
      'emoji': '🔢',
      'color': _DC.mathColor,
      'max': 10
    },
    {
      'key': 'English',
      'label': 'English',
      'emoji': '📖',
      'color': _DC.englishColor,
      'max': 10
    },
    {
      'key': 'Natural Sciences',
      'label': 'Science',
      'emoji': '🔬',
      'color': _DC.scienceColor,
      'max': 10
    },
    {
      'key': 'Social Sciences',
      'label': 'Social',
      'emoji': '🌍',
      'color': Color(0xFF43A047),
      'max': 10
    },
    {
      'key': 'Life Skills',
      'label': 'Life Skills',
      'emoji': '🌈',
      'color': Color(0xFFFF9800),
      'max': 5
    },
  ];
  static const _senior = [
    {
      'key': 'Mathematics',
      'label': 'Maths',
      'emoji': '🔢',
      'color': _DC.mathColor,
      'max': 10
    },
    {
      'key': 'English',
      'label': 'English',
      'emoji': '📖',
      'color': _DC.englishColor,
      'max': 10
    },
    {
      'key': 'Natural Sciences',
      'label': 'Science',
      'emoji': '🔬',
      'color': _DC.scienceColor,
      'max': 10
    },
    {
      'key': 'Social Sciences',
      'label': 'Social',
      'emoji': '🌍',
      'color': Color(0xFF43A047),
      'max': 10
    },
    {
      'key': 'Technology',
      'label': 'Technology',
      'emoji': '💡',
      'color': Color(0xFF7C4DFF),
      'max': 10
    },
    {
      'key': 'EMS',
      'label': 'EMS',
      'emoji': '💰',
      'color': Color(0xFF009688),
      'max': 10
    },
    {
      'key': 'Life Skills',
      'label': 'Life Skills',
      'emoji': '🌈',
      'color': Color(0xFFFF9800),
      'max': 5
    },
  ];

  List<Map<String, Object>> get _config {
    final n = int.tryParse(gradeKey.replaceAll(RegExp(r'[^0-9]'), '')) ?? 4;
    if (n <= 3) return _foundation;
    if (n <= 6) return _intermediate;
    return _senior;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final counts = rewards.subjectCounts;

    final bars = _config.map((s) {
      final count = counts[s['key'] as String] ?? 0;
      final max = s['max'] as int;
      final value = max > 0 ? (count / max).clamp(0.0, 1.0) : 0.0;
      return _SubjectProgressBar(
        label: s['label'] as String,
        emoji: s['emoji'] as String,
        value: value,
        color: s['color'] as Color,
        isDark: isDark,
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('📊 Your Progress', style: AppTextStyles.h3),
        const SizedBox(height: 16),
        ...bars.map((b) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: b,
            )),
      ],
    );
  }
}

class _SubjectProgressBar extends StatelessWidget {
  final String label;
  final String emoji;
  final double value;
  final Color color;
  final bool isDark;

  const _SubjectProgressBar({
    required this.label,
    required this.emoji,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).round();
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label,
                      style: AppTextStyles.bodyMedium
                          .copyWith(fontWeight: FontWeight.w600)),
                  Text('$pct%',
                      style: AppTextStyles.bodySmall.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 10,
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : color.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Quests Tab
// ---------------------------------------------------------------------------
class _QuestsTab extends StatelessWidget {
  const _QuestsTab();

  @override
  Widget build(BuildContext context) => const QuestsScreen(embedded: true);
}

// ---------------------------------------------------------------------------
// Rewards Tab
// ---------------------------------------------------------------------------
class _RewardsTab extends StatelessWidget {
  const _RewardsTab();

  @override
  Widget build(BuildContext context) => const RewardsScreen(embedded: true);
}

// ---------------------------------------------------------------------------
// AI Tutor Tab
// ---------------------------------------------------------------------------
class _AiTutorTab extends StatelessWidget {
  const _AiTutorTab();

  @override
  Widget build(BuildContext context) => const AiTutorScreen(embedded: true);
}

// ---------------------------------------------------------------------------
// Profile Tab — gradient header + stats card + sign-out
// ---------------------------------------------------------------------------
class _ProfileTab extends StatefulWidget {
  final dynamic user;

  const _ProfileTab({required this.user});

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 36, 20, 40),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_DC.heroGradientStart, _DC.heroGradientEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(36),
                bottomRight: Radius.circular(36),
              ),
            ),
            child: Column(
              children: [
                const ProfileAvatarPicker(radius: 60, initialsColor: Colors.white),
                const SizedBox(height: 14),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.user?.name ?? 'Learner',
                      style: AppTextStyles.h2.copyWith(color: Colors.white),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/edit_profile'),
                      child: const Icon(Icons.edit, color: Colors.white70, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.user?.grade ?? 'Grade 1',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: Colors.white.withValues(alpha: 0.80)),
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('⭐', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.user?.totalPoints ?? 0} XP',
                        style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 24, vertical: 24),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: _DC.heroGradientStart.withValues(alpha: 0.15),
                    width: 1.5),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  _ProfileStatRow(
                    icon: Icons.star_rounded,
                    iconColor: _DC.gold,
                    label: 'Total Points',
                    value: '${widget.user?.totalPoints ?? 0}',
                  ),
                  const Divider(height: 1, indent: 56),
                  Builder(builder: (context) {
                    final rewards = context.watch<RewardsProvider>();
                    return _ProfileStatRow(
                      icon: Icons.military_tech_rounded,
                      iconColor: _DC.badgeColor,
                      label: 'Level',
                      value:
                          '${rewards.level} ${rewards.levelEmoji} ${rewards.levelTitle}',
                    );
                  }),
                  const Divider(height: 1, indent: 56),
                  _ProfileStatRow(
                    icon: Icons.local_fire_department_rounded,
                    iconColor: _DC.streakColor,
                    label: 'Current Streak',
                    value: '${widget.user?.streakDays ?? 0} days',
                  ),
                  const Divider(height: 1, indent: 56),
                  _ProfileStatRow(
                    icon: Icons.school_rounded,
                    iconColor: _DC.heroGradientStart,
                    label: 'Grade',
                    value: widget.user?.grade ?? 'Not set',
                  ),
                  const Divider(height: 1, indent: 56),
                  _ProfileStatRow(
                    icon: Icons.cake_rounded,
                    iconColor: _DC.englishColor,
                    label: 'Member Since',
                    value: _formatDate(widget.user?.createdAt),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🏅 Achievements', style: AppTextStyles.h4),
                const SizedBox(height: 12),
                Builder(builder: (context) {
                  final badges = context.watch<RewardsProvider>().badges;
                  if (badges.isEmpty) {
                    return const AppEmptyState(
                      emoji: '🏅',
                      title: 'No badges yet',
                      message: 'Complete quests to start earning badges!',
                    );
                  }
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: badges.map((badge) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _DC.gold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: _DC.gold.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(badge.icon,
                                style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 6),
                            Text(badge.name,
                                style: AppTextStyles.bodySmall.copyWith(
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                }),
              ],
            ),
          ),
          if (widget.user?.childLinkCode != null) ...[
            const SizedBox(height: 24),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _DC.heroGradientStart.withValues(alpha: 0.15),
                      width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('👨‍👩‍👧 Parent Connection', style: AppTextStyles.h4),
                    const SizedBox(height: 8),
                    Text(
                      (widget.user?.linkedParentUids?.isNotEmpty ?? false)
                          ? '✅ Linked to ${widget.user!.linkedParentUids.length} parent(s)'
                          : 'Not linked to a parent yet',
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Ask your parent to scan this code or enter it in their app to connect:',
                      style: AppTextStyles.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: ChildQrCode(code: widget.user!.childLinkCode!),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Padding(
            padding: EdgeInsets.only(
                left: isMobile ? 16 : 24,
                right: isMobile ? 16 : 24,
                bottom: 40),
            child: const ProfileSettingsTile(),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _ProfileStatRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _ProfileStatRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(value,
                    style: AppTextStyles.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right,
              color: AppColors.textSecondary.withValues(alpha: 0.60), size: 20),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Offline Tab
// ---------------------------------------------------------------------------
class _OfflineTab extends StatelessWidget {
  const _OfflineTab();

  @override
  Widget build(BuildContext context) => const OfflineScreen(embedded: true);
}
