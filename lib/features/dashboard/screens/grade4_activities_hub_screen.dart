import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/rewards_provider.dart';
import '../../games/core/game_config.dart';
import '../../games/multiples_grid/multiples_grid_game.dart';

// ────────────────────────────────────────────────────────────────────────────
// Grade 4 Learning Activities Hub
//
// Structured learning activity map featuring Grade 4 CAPS curriculum mini-games
// across English, Mathematics, Natural Sciences & Technology, and Social Sciences.
// ────────────────────────────────────────────────────────────────────────────

class Grade4ActivitiesHubScreen extends StatefulWidget {
  const Grade4ActivitiesHubScreen({super.key});

  @override
  State<Grade4ActivitiesHubScreen> createState() =>
      _Grade4ActivitiesHubScreenState();
}

class _Grade4ActivitiesHubScreenState extends State<Grade4ActivitiesHubScreen> {
  int _earnedCoins = 250;
  int _earnedStars = 15;
  double _levelProgress = 0.65;
  String _activeTab = 'All';

  final Set<String> _completedActivities = {};

  void _onActivityCompleted(String activityId, int stars, int coins) {
    setState(() {
      _completedActivities.add(activityId);
      _earnedStars += stars;
      _earnedCoins += coins;
      _levelProgress = (_levelProgress + 0.08).clamp(0.0, 1.0);
    });

    final uid = context.read<AuthProvider>().user?.uid;
    if (uid != null) {
      try {
        context.read<RewardsProvider>().loadRewards(uid);
      } catch (_) {}
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            const Text('🌟', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Awesome Job! +$stars Stars and +$coins Coins!',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F4FD),
      appBar: _buildHeader(context),
      body: Column(
        children: [
          // Filter Tabs
          _buildFilterBar(),

          // Main Scrollable Activities Hub
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_activeTab == 'All' || _activeTab == 'English') ...[
                    _buildSectionHeader(
                      title: 'ENGLISH ACTIVITIES',
                      icon: Icons.menu_book,
                      gradient: const [Color(0xFF2196F3), Color(0xFF1976D2)],
                    ),
                    const SizedBox(height: 12),
                    _buildEnglishRow(),
                    const SizedBox(height: 24),
                  ],
                  if (_activeTab == 'All' || _activeTab == 'Maths') ...[
                    _buildSectionHeader(
                      title: 'MATHEMATICS ACTIVITIES',
                      icon: Icons.calculate,
                      gradient: const [Color(0xFF1E88E5), Color(0xFF1565C0)],
                    ),
                    const SizedBox(height: 12),
                    _buildMathsRow(),
                    const SizedBox(height: 24),
                  ],
                  if (_activeTab == 'All' || _activeTab == 'Science') ...[
                    _buildSectionHeader(
                      title: 'NATURAL SCIENCES & TECHNOLOGY',
                      icon: Icons.eco,
                      gradient: const [Color(0xFF43A047), Color(0xFF2E7D32)],
                    ),
                    const SizedBox(height: 12),
                    _buildScienceRow(),
                    const SizedBox(height: 24),
                  ],
                  if (_activeTab == 'All' || _activeTab == 'Social') ...[
                    _buildSectionHeader(
                      title: 'SOCIAL SCIENCES',
                      icon: Icons.public,
                      gradient: const [Color(0xFF5E35B1), Color(0xFF4527A0)],
                    ),
                    const SizedBox(height: 12),
                    _buildSocialSciencesRow(),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ),

          // Bottom Reward Progression Bar
          _buildBottomQuestBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildHeader(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF1E88E5),
      elevation: 3,
      leading: IconButton(
        icon: const CircleAvatar(
          backgroundColor: Colors.white24,
          child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, color: Color(0xFFFFD54F), size: 22),
          SizedBox(width: 8),
          Text(
            'Grade 4 Learning Hub',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 19,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Text('⭐', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 4),
              Text(
                '$_earnedStars',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    final tabs = ['All', 'English', 'Maths', 'Science', 'Social'];
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final tab = tabs[i];
          final isSelected = _activeTab == tab;
          return GestureDetector(
            onTap: () => setState(() => _activeTab = tab),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF1E88E5) : const Color(0xFFEEF3F8),
                borderRadius: BorderRadius.circular(20),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF1E88E5).withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  tab,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.blueGrey.shade800,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required List<Color> gradient,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 15,
              letterSpacing: 0.8,
            ),
          ),
          const Spacer(),
          const Icon(Icons.edit, color: Colors.white70, size: 18),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // English Activities
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildEnglishRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildCard(
            title: 'Spelling Bee',
            stars: 125,
            subtitle: 'Listen to the word and type how you spell it.',
            iconData: '🐝',
            previewWidget: _buildSpellingBeePreview(),
            onTap: () => _openSpellingBeeModal(),
          ),
          const SizedBox(width: 12),
          _buildCard(
            title: 'Word Builder',
            stars: 150,
            subtitle: 'Drag the letters to build the correct word.',
            iconData: '🐶',
            previewWidget: _buildWordBuilderPreview(),
            onTap: () => _openWordBuilderModal(),
          ),
          const SizedBox(width: 12),
          _buildCard(
            title: 'Match the Word',
            stars: 175,
            subtitle: 'Drag the word to match the correct picture.',
            iconData: '🍎',
            previewWidget: _buildMatchWordPreview(),
            onTap: () => _openMatchWordModal(),
          ),
          const SizedBox(width: 12),
          _buildCard(
            title: 'Complete the Sentence',
            stars: 200,
            subtitle: 'Drag the correct word into the blank.',
            iconData: '📖',
            previewWidget: _buildCompleteSentencePreview(),
            onTap: () => _openCompleteSentenceModal(),
          ),
          const SizedBox(width: 12),
          _buildCard(
            title: 'Synonyms Match',
            stars: 140,
            subtitle: 'Match the words that have the same meaning.',
            iconData: '🔗',
            previewWidget: _buildSynonymsPreview(),
            onTap: () => _openSynonymsModal(),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Mathematics Activities
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildMathsRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildCard(
            title: 'Multiples Matrix',
            stars: 180,
            subtitle: 'Connect glowing cubes in sequential order.',
            iconData: '🎲',
            previewWidget: _buildMultiplesMatrixPreview(),
            onTap: () => _launchMultiplesGridGame(),
          ),
          const SizedBox(width: 12),
          _buildCard(
            title: 'Solve and Drag',
            stars: 160,
            subtitle: 'Solve the sum and drag the correct answer.',
            iconData: '➕',
            previewWidget: _buildSolveDragPreview(),
            onTap: () => _openSolveDragModal(),
          ),
          const SizedBox(width: 12),
          _buildCard(
            title: 'Number Patterns',
            stars: 150,
            subtitle: 'Look at the pattern and fill in missing numbers.',
            iconData: '🔢',
            previewWidget: _buildNumberPatternsPreview(),
            onTap: () => _openNumberPatternsModal(),
          ),
          const SizedBox(width: 12),
          _buildCard(
            title: 'Times Table Challenge',
            stars: 180,
            subtitle: 'Work out the multiplication answer.',
            iconData: '🧮',
            previewWidget: _buildTimesTablePreview(),
            onTap: () => _openTimesTableModal(),
          ),
          const SizedBox(width: 12),
          _buildCard(
            title: 'Shape Explorer',
            stars: 140,
            subtitle: 'Drag the name to the correct shape.',
            iconData: '📐',
            previewWidget: _buildShapeExplorerPreview(),
            onTap: () => _openShapeExplorerModal(),
          ),
          const SizedBox(width: 12),
          _buildCard(
            title: 'Money Game',
            stars: 170,
            subtitle: 'Count South African coins and drag the amount.',
            iconData: '💰',
            previewWidget: _buildMoneyGamePreview(),
            onTap: () => _openMoneyGameModal(),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Natural Sciences Activities
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildScienceRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildCard(
            title: 'Living vs Non-Living',
            stars: 160,
            subtitle: 'Drag each picture to the correct category.',
            iconData: '🌱',
            previewWidget: _buildLivingNonLivingPreview(),
            onTap: () => _openLivingNonLivingModal(),
          ),
          const SizedBox(width: 12),
          _buildCard(
            title: 'Plant Parts',
            stars: 150,
            subtitle: 'Drag the names to label parts of the plant.',
            iconData: '🌸',
            previewWidget: _buildPlantPartsPreview(),
            onTap: () => _openPlantPartsModal(),
          ),
          const SizedBox(width: 12),
          _buildCard(
            title: 'Animal Habitats',
            stars: 170,
            subtitle: 'Match each animal to its home.',
            iconData: '🦁',
            previewWidget: _buildAnimalHabitatsPreview(),
            onTap: () => _openAnimalHabitatsModal(),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Social Sciences Activities
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildSocialSciencesRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildCard(
            title: 'Map Symbols Match',
            stars: 160,
            subtitle: 'Match the map symbol to what it represents.',
            iconData: '🗺️',
            previewWidget: _buildMapSymbolsPreview(),
            onTap: () => _openMapSymbolsModal(),
          ),
          const SizedBox(width: 12),
          _buildCard(
            title: 'Compass Directions',
            stars: 150,
            subtitle: 'Help the boy reach school by choosing directions.',
            iconData: '🧭',
            previewWidget: _buildCompassDirectionsPreview(),
            onTap: () => _openCompassDirectionsModal(),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Reusable Activity Card Container
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildCard({
    required String title,
    required int stars,
    required String subtitle,
    required String iconData,
    required Widget previewWidget,
    required VoidCallback onTap,
  }) {
    final isDone = _completedActivities.contains(title);

    return Container(
      width: 250,
      height: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDone ? const Color(0xFF4CAF50) : const Color(0xFFE2EDF8),
          width: isDone ? 2.5 : 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top header: Title pill & Stars badge
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E88E5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        const Text('⭐', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 3),
                        Text(
                          '$stars',
                          style: TextStyle(
                            color: isDone ? const Color(0xFF4CAF50) : Colors.orange.shade800,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Subtitle Instruction
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.blueGrey.shade600,
                    fontSize: 11,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),

                // Interactive Mini-game Preview Area
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F9FD),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE1EEF8)),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: previewWidget,
                  ),
                ),

                const SizedBox(height: 8),
                // Tap to Play action button
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isDone ? const Color(0xFFE8F5E9) : const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      isDone ? '✓ Completed • Play Again' : 'Play Activity ▶',
                      style: TextStyle(
                        color: isDone ? const Color(0xFF2E7D32) : const Color(0xFF1565C0),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Preview Widgets for Cards
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildSpellingBeePreview() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.volume_up, color: Color(0xFF1E88E5), size: 24),
            SizedBox(width: 8),
            Text('🐝', style: TextStyle(fontSize: 28)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            5,
            (i) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 18,
              height: 22,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blueGrey.shade300),
                borderRadius: BorderRadius.circular(4),
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWordBuilderPreview() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('🐶', style: TextStyle(fontSize: 32)),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: ['D', 'O', 'G'].map((char) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF1E88E5)),
              ),
              child: Text(
                char,
                style: const TextStyle(
                  color: Color(0xFF1E88E5),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMatchWordPreview() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🍎', style: TextStyle(fontSize: 18)),
            SizedBox(height: 6),
            Text('📘', style: TextStyle(fontSize: 18)),
            SizedBox(height: 6),
            Text('🐱', style: TextStyle(fontSize: 18)),
          ],
        ),
        const Icon(Icons.swap_horiz, color: Color(0xFF1E88E5), size: 20),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: ['cat', 'book', 'apple'].map((w) {
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9C4),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(w, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCompleteSentencePreview() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('👧 📚', style: TextStyle(fontSize: 24)),
        const SizedBox(height: 6),
        const Text(
          'The girl is ___ a book',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFE1BEE7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text('reading', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildSynonymsPreview() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('big', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            SizedBox(height: 6),
            Text('happy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            SizedBox(height: 6),
            Text('fast', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          ],
        ),
        Text('⟷', style: TextStyle(color: Colors.green, fontSize: 20, fontWeight: FontWeight.bold)),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('large', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
            SizedBox(height: 6),
            Text('joyful', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
            SizedBox(height: 6),
            Text('quick', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
          ],
        ),
      ],
    );
  }

  Widget _buildMultiplesMatrixPreview() {
    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 5,
      crossAxisSpacing: 3,
      mainAxisSpacing: 3,
      children: [3, 6, 9, 12, 15, 18, 21, 24, 27, 30]
          .map((n) => Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF9800), Color(0xFFE65100)],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    '$n',
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildSolveDragPreview() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF1E88E5)),
          ),
          child: const Text(
            '36 + 27 = [ 63 ]',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF1565C0)),
          ),
        ),
        const SizedBox(height: 8),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('⭐ ⭐ ⭐', style: TextStyle(fontSize: 16)),
          ],
        ),
      ],
    );
  }

  Widget _buildNumberPatternsPreview() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          '2, 4, 6, [8], [10], 12',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF1E88E5)),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          children: [8, 9, 10, 12]
              .map((n) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.blueGrey.shade300),
                    ),
                    child: Text('$n', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildTimesTablePreview() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1B382B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF795548), width: 3),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '7 × 6 = 42',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
          ),
          SizedBox(height: 4),
          Text(
            'Chalkboard Challenge',
            style: TextStyle(color: Colors.white70, fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _buildShapeExplorerPreview() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Text('🟩', style: TextStyle(fontSize: 22)),
        Text('🔺', style: TextStyle(fontSize: 22)),
        Text('🔵', style: TextStyle(fontSize: 22)),
        Text('🟨', style: TextStyle(fontSize: 22)),
      ],
    );
  }

  Widget _buildMoneyGamePreview() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(radius: 12, backgroundColor: Color(0xFFFFD54F), child: Text('R5', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
            SizedBox(width: 4),
            CircleAvatar(radius: 10, backgroundColor: Color(0xFFB0BEC5), child: Text('R2', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold))),
            SizedBox(width: 4),
            CircleAvatar(radius: 10, backgroundColor: Color(0xFFB0BEC5), child: Text('R2', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold))),
            SizedBox(width: 4),
            CircleAvatar(radius: 8, backgroundColor: Color(0xFFFFCC80), child: Text('R1', style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold))),
          ],
        ),
        SizedBox(height: 6),
        Text('Total = R10', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF2E7D32), fontSize: 12)),
      ],
    );
  }

  Widget _buildLivingNonLivingPreview() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Column(
            children: [
              Text('Living', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
              SizedBox(height: 2),
              Text('🌳 🐕', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFECEFF1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Column(
            children: [
              Text('Non-Living', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              SizedBox(height: 2),
              Text('🪨 🚲', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlantPartsPreview() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('🌸 (Flower)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.pink)),
        Text('🌿 (Stem & Leaf)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
        Text('🌱 (Roots in soil)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.brown)),
      ],
    );
  }

  Widget _buildAnimalHabitatsPreview() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('🐟 ➔ Water', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        Text('🐻‍❄️ ➔ Mountains', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        Text('🦁 ➔ Savannah', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildMapSymbolsPreview() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('➕ ➔ Hospital', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        Text('✉️ ➔ Post Office', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        Text('⛽ ➔ Petrol Station', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildCompassDirectionsPreview() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('👦', style: TextStyle(fontSize: 22)),
        Text(' ➔ ⬆️ North ➔ ➡️ East ➔ ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        Text('🏫', style: TextStyle(fontSize: 22)),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Bottom Quest Progress Bar
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildBottomQuestBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D47A1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            const Text('🏆', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            const Text(
              'Great Job!',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 16),
            Container(
              height: 24,
              width: 1,
              color: Colors.white24,
            ),
            const SizedBox(width: 16),
            Row(
              children: [
                const Text('🪙', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 4),
                Text(
                  '$_earnedCoins',
                  style: const TextStyle(
                    color: Color(0xFFFFD54F),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Row(
              children: [
                const Text('⭐', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 4),
                Text(
                  '$_earnedStars',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Next Level',
                  style: TextStyle(color: Colors.white70, fontSize: 10),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 90,
                  height: 8,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _levelProgress,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF00E676)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            const Text('🎁', style: TextStyle(fontSize: 22)),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Modal Mini-Game Launchers
  // ──────────────────────────────────────────────────────────────────────────

  void _launchMultiplesGridGame() {
    final user = context.read<AuthProvider>().user;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiplesGridGame(
          config: const GameConfig(
            grade: 'Grade 4',
            subject: 'Mathematics',
            topicId: 'multiplication',
            subtopicId: 'multiples_grid',
            engineType: 'multiplesGrid',
          ),
          user: user,
        ),
      ),
    ).then((_) {
      _onActivityCompleted('Multiples Matrix', 25, 50);
    });
  }

  void _openSpellingBeeModal() {
    _showInteractiveDialog(
      title: 'Spelling Bee',
      wordToSpell: 'BEAUTIFUL',
      hint: 'Word meaning very pleasing to look at',
      onSolved: () => _onActivityCompleted('Spelling Bee', 15, 30),
    );
  }

  void _openWordBuilderModal() {
    _showWordBuilderDialog(
      word: 'PUPPY',
      letters: ['P', 'U', 'P', 'P', 'Y', 'D', 'O', 'G'],
      onSolved: () => _onActivityCompleted('Word Builder', 15, 30),
    );
  }

  void _openMatchWordModal() {
    _showMatchDialog(
      title: 'Match the Word',
      pairs: {
        '🍎 Apple': 'apple',
        '📘 Book': 'book',
        '🐱 Cat': 'cat',
      },
      onSolved: () => _onActivityCompleted('Match the Word', 20, 35),
    );
  }

  void _openCompleteSentenceModal() {
    _showMultipleChoiceDialog(
      title: 'Complete the Sentence',
      prompt: 'The girl is ________ a book.',
      options: ['reading', 'read', 'reads', 'reader'],
      correctAnswer: 'reading',
      onSolved: () => _onActivityCompleted('Complete the Sentence', 20, 40),
    );
  }

  void _openSynonymsModal() {
    _showMatchDialog(
      title: 'Synonyms Match',
      pairs: {
        'Big': 'Large',
        'Happy': 'Joyful',
        'Fast': 'Quick',
      },
      onSolved: () => _onActivityCompleted('Synonyms Match', 15, 30),
    );
  }

  void _openSolveDragModal() {
    _showMultipleChoiceDialog(
      title: 'Solve and Drag',
      prompt: '36 + 27 = ?',
      options: ['63', '53', '43', '73'],
      correctAnswer: '63',
      onSolved: () => _onActivityCompleted('Solve and Drag', 20, 35),
    );
  }

  void _openNumberPatternsModal() {
    _showMultipleChoiceDialog(
      title: 'Number Patterns',
      prompt: 'What comes next in: 2, 4, 6, 8, __, 12',
      options: ['10', '9', '11', '14'],
      correctAnswer: '10',
      onSolved: () => _onActivityCompleted('Number Patterns', 15, 30),
    );
  }

  void _openTimesTableModal() {
    _showMultipleChoiceDialog(
      title: 'Times Table Challenge',
      prompt: '7 × 6 = ?',
      options: ['42', '48', '36', '49'],
      correctAnswer: '42',
      onSolved: () => _onActivityCompleted('Times Table Challenge', 20, 40),
    );
  }

  void _openShapeExplorerModal() {
    _showMultipleChoiceDialog(
      title: 'Shape Explorer',
      prompt: 'Which shape has 3 sides and 3 angles?',
      options: ['Triangle', 'Square', 'Circle', 'Rectangle'],
      correctAnswer: 'Triangle',
      onSolved: () => _onActivityCompleted('Shape Explorer', 15, 30),
    );
  }

  void _openMoneyGameModal() {
    _showMultipleChoiceDialog(
      title: 'Money Game (Rands)',
      prompt: 'Count: R5 + R2 + R2 + R1 + R1 + R1 = ?',
      options: ['R12', 'R10', 'R11', 'R15'],
      correctAnswer: 'R12',
      onSolved: () => _onActivityCompleted('Money Game', 20, 35),
    );
  }

  void _openLivingNonLivingModal() {
    _showMultipleChoiceDialog(
      title: 'Living vs Non-Living',
      prompt: 'Which of the following is a LIVING thing?',
      options: ['Tree', 'Rock', 'Bicycle', 'Chair'],
      correctAnswer: 'Tree',
      onSolved: () => _onActivityCompleted('Living vs Non-Living', 20, 35),
    );
  }

  void _openPlantPartsModal() {
    _showMultipleChoiceDialog(
      title: 'Plant Parts',
      prompt: 'Which part of the plant absorbs water and nutrients from the soil?',
      options: ['Roots', 'Flower', 'Stem', 'Leaf'],
      correctAnswer: 'Roots',
      onSolved: () => _onActivityCompleted('Plant Parts', 15, 30),
    );
  }

  void _openAnimalHabitatsModal() {
    _showMultipleChoiceDialog(
      title: 'Animal Habitats',
      prompt: 'Where is the natural habitat of a fish?',
      options: ['Water', 'Desert', 'Mountains', 'Forest'],
      correctAnswer: 'Water',
      onSolved: () => _onActivityCompleted('Animal Habitats', 20, 35),
    );
  }

  void _openMapSymbolsModal() {
    _showMultipleChoiceDialog(
      title: 'Map Symbols Match',
      prompt: 'What does a red cross ➕ symbol represent on a map?',
      options: ['Hospital', 'Post Office', 'Petrol Station', 'Camp Site'],
      correctAnswer: 'Hospital',
      onSolved: () => _onActivityCompleted('Map Symbols Match', 20, 35),
    );
  }

  void _openCompassDirectionsModal() {
    _showMultipleChoiceDialog(
      title: 'Compass Directions',
      prompt: 'If you are facing North, which direction is directly to your right?',
      options: ['East', 'West', 'South', 'North-West'],
      correctAnswer: 'East',
      onSolved: () => _onActivityCompleted('Compass Directions', 15, 30),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Generic Interactive Dialog Helpers
  // ──────────────────────────────────────────────────────────────────────────

  void _showMultipleChoiceDialog({
    required String title,
    required String prompt,
    required List<String> options,
    required String correctAnswer,
    required VoidCallback onSolved,
  }) {
    final shuffled = List<String>.from(options)..shuffle(math.Random());
    String? selected;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isCorrect = selected == correctAnswer;
          final isAnswered = selected != null;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                const Icon(Icons.star, color: Colors.orange, size: 24),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    prompt,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0D47A1),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: shuffled.map((opt) {
                    final isThisSelected = selected == opt;
                    Color btnColor = Colors.white;
                    if (isAnswered) {
                      if (opt == correctAnswer) {
                        btnColor = const Color(0xFFC8E6C9);
                      } else if (isThisSelected) {
                        btnColor = const Color(0xFFFFCDD2);
                      }
                    }

                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: btnColor,
                        foregroundColor: Colors.black87,
                        elevation: isThisSelected ? 4 : 1,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isThisSelected ? const Color(0xFF1E88E5) : Colors.grey.shade300,
                            width: isThisSelected ? 2 : 1,
                          ),
                        ),
                      ),
                      onPressed: isAnswered
                          ? null
                          : () {
                              setDialogState(() => selected = opt);
                              if (opt == correctAnswer) {
                                Future.delayed(const Duration(milliseconds: 900), () {
                                  if (ctx.mounted) Navigator.of(ctx).pop();
                                  onSolved();
                                });
                              }
                            },
                      child: Text(opt, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    );
                  }).toList(),
                ),
                if (isAnswered && !isCorrect) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Try again! Tap the correct choice.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showInteractiveDialog({
    required String title,
    required String wordToSpell,
    required String hint,
    required VoidCallback onSolved,
  }) {
    String typed = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                const Text('🐝', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(hint, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Text(
                    typed.isEmpty ? 'Type spelling...' : typed,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('').map((letter) {
                    return SizedBox(
                      width: 32,
                      height: 36,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: const Color(0xFFE3F2FD),
                          foregroundColor: const Color(0xFF0D47A1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () {
                          if (typed.length < wordToSpell.length) {
                            setDialogState(() => typed += letter);
                            if (typed == wordToSpell) {
                              Future.delayed(const Duration(milliseconds: 700), () {
                                if (ctx.mounted) Navigator.of(ctx).pop();
                                onSolved();
                              });
                            }
                          }
                        },
                        child: Text(letter, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => setDialogState(() => typed = ''),
                  icon: const Icon(Icons.backspace, size: 18),
                  label: const Text('Clear'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showWordBuilderDialog({
    required String word,
    required List<String> letters,
    required VoidCallback onSolved,
  }) {
    List<String> currentLetters = [];
    final available = List<String>.from(letters)..shuffle(math.Random());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Row(
              children: [
                Text('🐶', style: TextStyle(fontSize: 24)),
                SizedBox(width: 8),
                Text('Word Builder', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Spell: PUPPY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9C4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Text(
                    currentLetters.isEmpty ? '[ _ _ _ _ _ ]' : currentLetters.join(' '),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 4),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: available.map((char) {
                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        setDialogState(() => currentLetters.add(char));
                        if (currentLetters.join('') == word) {
                          Future.delayed(const Duration(milliseconds: 700), () {
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            onSolved();
                          });
                        }
                      },
                      child: Text(char, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setDialogState(() => currentLetters.clear()),
                  child: const Text('Reset Letters'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showMatchDialog({
    required String title,
    required Map<String, String> pairs,
    required VoidCallback onSolved,
  }) {
    final keys = pairs.keys.toList();
    final values = pairs.values.toList()..shuffle(math.Random());
    String? selectedKey;
    final matched = <String>{};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Tap an item on the left, then its match on the right:'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: keys.map((k) {
                          final isMatched = matched.contains(k);
                          final isSelected = selectedKey == k;

                          return GestureDetector(
                            onTap: isMatched ? null : () => setDialogState(() => selectedKey = k),
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isMatched
                                    ? const Color(0xFFC8E6C9)
                                    : (isSelected ? const Color(0xFFFFE082) : Colors.white),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade400),
                              ),
                              child: Center(child: Text(k, style: const TextStyle(fontWeight: FontWeight.bold))),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: values.map((v) {
                          final isMatched = matched.any((k) => pairs[k] == v);

                          return GestureDetector(
                            onTap: isMatched
                                ? null
                                : () {
                                    if (selectedKey != null) {
                                      if (pairs[selectedKey] == v) {
                                        setDialogState(() {
                                          matched.add(selectedKey!);
                                          selectedKey = null;
                                        });
                                        if (matched.length == keys.length) {
                                          Future.delayed(const Duration(milliseconds: 700), () {
                                            if (ctx.mounted) Navigator.of(ctx).pop();
                                            onSolved();
                                          });
                                        }
                                      } else {
                                        setDialogState(() => selectedKey = null);
                                      }
                                    }
                                  },
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isMatched ? const Color(0xFFC8E6C9) : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade400),
                              ),
                              child: Center(child: Text(v, style: const TextStyle(fontWeight: FontWeight.bold))),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
