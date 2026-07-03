import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';

/// Visual + copy identity for one game engine — separate from subject colour
/// (Maths/Science/English/...), this is what makes the *mechanic* itself
/// recognisable across subjects: two Maths games using different engines
/// should look and feel different, not just have different questions.
class GameEngineIdentity {
  final Color accent;
  final IconData icon;
  final String tagline;
  const GameEngineIdentity({
    required this.accent,
    required this.icon,
    required this.tagline,
  });
}

/// One identity per engine, keyed by the `engineType` constants in
/// [AppConstants]. Keep this in sync with GameRouter's switch — every
/// engine GameRouter can launch should have an identity here.
const Map<String, GameEngineIdentity> gameEngineIdentities = {
  AppConstants.engineTugOfWar: GameEngineIdentity(
    accent: Color(0xFFE53935),
    icon: Icons.bolt,
    tagline: 'Race & Recall',
  ),
  AppConstants.engineAdventureJourney: GameEngineIdentity(
    accent: Color(0xFF3F51B5),
    icon: Icons.auto_stories,
    tagline: 'Explore & Decide',
  ),
  AppConstants.engineRunnerCollector: GameEngineIdentity(
    accent: Color(0xFF7CB342),
    icon: Icons.directions_run,
    tagline: 'Sort on the Run',
  ),
  AppConstants.engineExplorerMap: GameEngineIdentity(
    accent: Color(0xFF00ACC1),
    icon: Icons.travel_explore,
    tagline: 'Find & Discover',
  ),
  AppConstants.engineMultiplesMerge: GameEngineIdentity(
    accent: Color(0xFFAB47BC),
    icon: Icons.merge_type,
    tagline: 'Merge & Multiply',
  ),
  AppConstants.engineSequenceBuilder: GameEngineIdentity(
    accent: Color(0xFFFFA726),
    icon: Icons.format_list_numbered,
    tagline: 'Order & Build',
  ),
  AppConstants.engineCircuitBuilder: GameEngineIdentity(
    accent: Color(0xFF2979FF),
    icon: Icons.electrical_services,
    tagline: 'Connect & Power',
  ),
  AppConstants.engineBudgetBuilder: GameEngineIdentity(
    accent: Color(0xFF2E7D32),
    icon: Icons.savings,
    tagline: 'Plan & Spend',
  ),
  AppConstants.engineNumberCountingDuel: GameEngineIdentity(
    accent: Color(0xFFF9A825),
    icon: Icons.pin,
    tagline: 'Count & Race',
  ),
};

/// Fallback identity for any engineType not (yet) in [gameEngineIdentities].
const _fallbackEngineIdentity = GameEngineIdentity(
  accent: AppColors.primary,
  icon: Icons.sports_esports,
  tagline: 'Play & Learn',
);

GameEngineIdentity engineIdentityFor(String engineType) =>
    gameEngineIdentities[engineType] ?? _fallbackEngineIdentity;

/// Centralised design tokens for **all** mini-games.
///
/// Every game must pull its font, radii, shadows, subject colour identity and
/// feedback styling from here — no scattered magic numbers. Subject identity is
/// fixed by the brief: Maths = orange, Natural Sciences = teal, English = pink,
/// Social Sciences = green.
class GameTheme {
  GameTheme._();

  // ── Spacing / shape tokens ──────────────────────────────────────────────
  static const double radius = 20;
  static const double radiusSmall = 14;
  static const double radiusLarge = 28;
  static const double pad = 16;
  static const double minTapTarget = 48; // accessibility: ≥ 48dp

  static BorderRadius get rounded => BorderRadius.circular(radius);
  static BorderRadius get roundedSmall => BorderRadius.circular(radiusSmall);

  static List<BoxShadow> softShadow(Color tint) => [
        BoxShadow(
          color: tint.withValues(alpha: 0.28),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
  ];

  // ── Typography — rounded, friendly, large for young readers ─────────────
  static TextStyle display(double size,
          {Color? color, FontWeight weight = FontWeight.w700}) =>
      GoogleFonts.fredoka(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: 0.2,
      );

  static TextStyle body(double size,
          {Color? color, FontWeight weight = FontWeight.w600}) =>
      GoogleFonts.baloo2(fontSize: size, fontWeight: weight, color: color);

  // ── Subject identity ────────────────────────────────────────────────────
  static Color subjectColor(String subject) {
    final s = subject.toLowerCase();
    if (s.contains('math')) return AppColors.math; // orange
    if (s.contains('science') && s.contains('natural'))
      return AppColors.science;
    if (s.contains('science') && s.contains('social'))
      return AppColors.socialSciences;
    if (s.contains('english')) return AppColors.english; // pink
    if (s.contains('social')) return AppColors.socialSciences; // green
    if (s.contains('science')) return AppColors.science; // teal
    if (s.contains('technology')) return AppColors.technology;
    if (s.contains('life')) return AppColors.lifeSkills;
    return AppColors.primary;
  }

  static List<Color> subjectGradient(String subject) {
    switch (subjectColor(subject)) {
      case AppColors.math:
        return AppColors.mathGradient;
      case AppColors.science:
        return AppColors.sciGradient;
      case AppColors.english:
        return AppColors.engGradient;
      case AppColors.socialSciences:
        return AppColors.sscGradient;
      default:
        return AppColors.heroGradient;
    }
  }

  // ── Feedback colours (gentle — no harsh red for young learners) ─────────
  static const Color positive = AppColors.success;
  static const Color gentleMiss = Color(0xFFFFB74D); // warm amber, not red

  // ── Grade helpers ───────────────────────────────────────────────────────
  /// Normalises 'Grade 4' / 'grade4' / '4' → integer 1..7 (default 4).
  static int gradeNumber(String? grade) {
    if (grade == null) return 4;
    final digits = RegExp(r'\d+').firstMatch(grade)?.group(0);
    final n = int.tryParse(digits ?? '') ?? 4;
    return n.clamp(1, 7);
  }
}

/// A small Questy mascot bubble that cheers on success / encourages on a miss.
/// Pure code-drawn (emoji + speech bubble) — no bundled assets.
class MascotBubble extends StatelessWidget {
  final String message;
  final bool positive;
  const MascotBubble({super.key, required this.message, this.positive = true});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(positive ? '🤖' : '🤖', style: const TextStyle(fontSize: 30)),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: GameTheme.rounded,
              boxShadow: GameTheme.cardShadow,
            ),
            child: Text(
              message,
              style: GameTheme.body(
                15,
                color: positive ? GameTheme.positive : const Color(0xFFE65100),
                weight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
