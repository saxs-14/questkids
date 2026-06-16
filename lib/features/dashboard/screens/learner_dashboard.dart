import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/widgets/responsive_scaffold.dart';
import '../../grade4/grade4_hub.dart';
import '../../../data/repositories/user_repository.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../offline/widgets/offline_banner.dart';
import '../../offline/widgets/sync_button.dart';
import '../../offline/screens/offline_screen.dart';
import '../../quests/screens/quests_screen.dart';
import '../../rewards/screens/rewards_screen.dart';
import '../../ai_tutor/screens/ai_tutor_screen.dart';

// ---------------------------------------------------------------------------
// Inline color constants (brand palette for the gaming dashboard)
// ---------------------------------------------------------------------------
class _DC {
  static const Color heroGradientStart = Color(0xFF5C35F5);
  static const Color heroGradientEnd   = Color(0xFF9C27B0);
  static const Color mathColor         = Color(0xFFFF6B35);
  static const Color scienceColor      = Color(0xFF00BFA5);
  static const Color englishColor      = Color(0xFFE91E63);
  static const Color gold              = Color(0xFFFFD700);
  static const Color challengeStart    = Color(0xFFFF8C00);
  static const Color challengeEnd      = Color(0xFFFFBF00);
  static const Color coinColor         = Color(0xFFFFD700);
  static const Color streakColor       = Color(0xFFFF6D00);
  static const Color badgeColor        = Color(0xFF7C4DFF);
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

  final StorageService _storage  = StorageService();
  final UserRepository _userRepo = UserRepository();

  @override
  Widget build(BuildContext context) {
    final auth  = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    final user  = auth.user;

    return ResponsiveScaffold(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (i) => setState(() => _selectedIndex = i),
      destinations: const [
        ResponsiveDestination(
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
            label: 'Home'),
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
            label: 'QuestBot'),
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
                            color: Colors.white,
                            fontWeight: FontWeight.w700),
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
                user?.grade == 'Grade 4'
                    ? Grade4Hub(user: user)
                    : _LearnerHomeTab(user: user),
                const _QuestsTab(),
                const _RewardsTab(),
                const _AiTutorTab(),
                _ProfileTab(
                    user: user,
                    storage: _storage,
                    userRepo: _userRepo),
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

  int get _level       => ((user?.totalPoints as int?) ?? 0) ~/ 100 + 1;
  int get _totalPoints => (user?.totalPoints as int?) ?? 0;
  int get _streakDays  => (user?.streakDays  as int?) ?? 0;
  int get _coins       => (user?.totalPoints as int?) ?? 0;

  String get _firstName {
    final name = user?.name as String?;
    if (name == null || name.isEmpty) return 'Learner';
    return name.split(' ').first;
  }

  String get _grade => (user?.grade as String?) ?? 'Grade 1';

  @override
  Widget build(BuildContext context) {
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
                _StatsRow(coins: _coins, streakDays: _streakDays),
                const SizedBox(height: 24),
                const _DailyChallengeCard(),
                const SizedBox(height: 24),
              ],
            ),
          ),

          const _FeaturedGamesSection(),
          const SizedBox(height: 24),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProgressSection(),
                SizedBox(height: 32),
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
  final int    level;
  final int    totalPoints;
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
          bottomLeft:  Radius.circular(32),
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
                  style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.80)),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    grade,
                    style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700),
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
                              color: Colors.white,
                              fontSize: 28,
                              height: 1.0),
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
                    color: _DC.gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
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

  const _StatsRow({required this.coins, required this.streakDays});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.white;
    final shadow = isDark
        ? Colors.transparent
        : Colors.black.withValues(alpha: 0.06);

    Widget card({
      required String emoji,
      required String label,
      required String value,
      required Color  accentColor,
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
              BoxShadow(color: shadow, blurRadius: 8, offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 4),
              Text(
                value,
                style: AppTextStyles.h4.copyWith(color: accentColor, fontSize: 16),
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
        card(emoji: '🪙', label: 'Coins', value: '$coins', accentColor: _DC.coinColor),
        const SizedBox(width: 10),
        card(emoji: '🔥', label: 'Streak', value: '${streakDays}d', accentColor: _DC.streakColor),
        const SizedBox(width: 10),
        card(emoji: '🏅', label: 'Badges', value: '0', accentColor: _DC.badgeColor),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Daily Challenge Card
// ---------------------------------------------------------------------------
class _DailyChallengeCard extends StatelessWidget {
  const _DailyChallengeCard();

  @override
  Widget build(BuildContext context) {
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
            'Complete 3 games today',
            style: AppTextStyles.h4.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: 0,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.30),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '0 / 3 completed',
            style: AppTextStyles.bodySmall.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _DC.challengeStart,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(
                'Start',
                style: AppTextStyles.button.copyWith(
                    color: _DC.challengeStart, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Featured Games — full-bleed horizontal scroll, fixed 160px item width
// ---------------------------------------------------------------------------
class _FeaturedGamesSection extends StatelessWidget {
  const _FeaturedGamesSection();

  static const _games = [
    _GameData(title: 'Multiplication Master', emoji: '🔢',
        gradient: [Color(0xFFFF6B35), Color(0xFFFF8C66)]),
    _GameData(title: 'Water Cycle Adventure', emoji: '💧',
        gradient: [Color(0xFF00BFA5), Color(0xFF00E5CC)]),
    _GameData(title: 'Grammar Hero Run', emoji: '🏃',
        gradient: [Color(0xFFE91E63), Color(0xFFFF4081)]),
    _GameData(title: 'SA Provinces Explorer', emoji: '🗺️',
        gradient: [Color(0xFF43A047), Color(0xFF66BB6A)]),
  ];

  @override
  Widget build(BuildContext context) {
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
            itemCount: _games.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 14),
                child: _GameCardWidget(data: _games[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GameData {
  final String title;
  final String emoji;
  final List<Color> gradient;

  const _GameData({
    required this.title,
    required this.emoji,
    required this.gradient,
  });
}

class _GameCardWidget extends StatelessWidget {
  final _GameData data;

  const _GameCardWidget({required this.data});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const QuestsScreen()),
      ),
      child: Container(
        width: 160,
        height: 180,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: data.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: data.gradient.first.withValues(alpha: 0.40),
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
              Text(data.emoji, style: const TextStyle(fontSize: 48)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '→ Play',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                        fontSize: 12),
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
// Progress Section
// ---------------------------------------------------------------------------
class _ProgressSection extends StatelessWidget {
  const _ProgressSection();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('📊 Your Progress', style: AppTextStyles.h3),
        const SizedBox(height: 16),
        _SubjectProgressBar(label: 'Maths', emoji: '🔢', value: 0.65,
            color: _DC.mathColor, isDark: isDark),
        const SizedBox(height: 14),
        _SubjectProgressBar(label: 'Science', emoji: '🔬', value: 0.45,
            color: _DC.scienceColor, isDark: isDark),
        const SizedBox(height: 14),
        _SubjectProgressBar(label: 'English', emoji: '📖', value: 0.80,
            color: _DC.englishColor, isDark: isDark),
      ],
    );
  }
}

class _SubjectProgressBar extends StatelessWidget {
  final String label;
  final String emoji;
  final double value;
  final Color  color;
  final bool   isDark;

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
  final dynamic      user;
  final StorageService storage;
  final UserRepository userRepo;

  const _ProfileTab({
    required this.user,
    required this.storage,
    required this.userRepo,
  });

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  bool _isUploading = false;

  Future<void> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final image  = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() => _isUploading = true);

      final bytes     = await image.readAsBytes();
      final extension = image.name.split('.').last;

      final url = await widget.storage.uploadAvatar(
        uid:       widget.user.uid,
        imageFile: bytes,
        extension: extension,
      );

      if (url != null && mounted) {
        await widget.userRepo.updateUser(widget.user.uid, {'avatarUrl': url});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile picture updated!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth     = context.watch<AuthProvider>();
    final isDark   = Theme.of(context).brightness == Brightness.dark;
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
                bottomLeft:  Radius.circular(36),
                bottomRight: Radius.circular(36),
              ),
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      backgroundImage: widget.user?.avatarUrl != null
                          ? NetworkImage(widget.user!.avatarUrl!)
                          : null,
                      child: widget.user?.avatarUrl == null
                          ? Text(
                              widget.user?.name.isNotEmpty == true
                                  ? widget.user!.name[0].toUpperCase()
                                  : '?',
                              style: AppTextStyles.score.copyWith(color: Colors.white),
                            )
                          : null,
                    ),
                    GestureDetector(
                      onTap: _isUploading ? null : _pickAndUploadImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _isUploading
                              ? Colors.grey
                              : Colors.white.withValues(alpha: 0.90),
                          shape: BoxShape.circle,
                          border: Border.all(color: _DC.heroGradientStart, width: 2),
                        ),
                        child: _isUploading
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      _DC.heroGradientStart),
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.camera_alt,
                                color: _DC.heroGradientStart, size: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  widget.user?.name ?? 'Learner',
                  style: AppTextStyles.h2.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.user?.grade ?? 'Grade 1',
                  style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.80)),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                            color: Colors.white,
                            fontWeight: FontWeight.w700),
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
                    icon: Icons.star_rounded, iconColor: _DC.gold,
                    label: 'Total Points',
                    value: '${widget.user?.totalPoints ?? 0}',
                  ),
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
                    icon: Icons.cake_rounded, iconColor: _DC.englishColor,
                    label: 'Member Since',
                    value: _formatDate(widget.user?.createdAt),
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.only(
                left: isMobile ? 16 : 24,
                right: isMobile ? 16 : 24,
                bottom: 40),
            child: OutlinedButton.icon(
              onPressed: () {
                auth.signOut();
                Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (route) => false);
              },
              icon: const Icon(Icons.logout, color: AppColors.error),
              label: const Text('Sign Out',
                  style: TextStyle(color: AppColors.error)),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(isMobile ? double.infinity : 200, 52),
                side: const BorderSide(color: AppColors.error, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
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
  final Color    iconColor;
  final String   label;
  final String   value;

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
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.bodySmall.copyWith(fontSize: 11)),
              const SizedBox(height: 2),
              Text(value, style: AppTextStyles.bodyMedium),
            ],
          ),
          const Spacer(),
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
