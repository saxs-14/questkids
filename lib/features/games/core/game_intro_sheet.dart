import 'package:flutter/material.dart';

import '../../../core/constants/game_catalog.dart';
import 'game_theme.dart';

/// Shown before every game launches. Tells the learner (and any adult
/// looking over their shoulder) what they're about to learn and why this
/// particular mechanic teaches it — see CLAUDE.md Phase 2 item 5.
class GameIntroSheet extends StatelessWidget {
  final GameCatalogEntry entry;
  final VoidCallback onStart;

  const GameIntroSheet({super.key, required this.entry, required this.onStart});

  /// Shows the sheet, then calls [onStart] if the learner taps "Let's play!".
  static Future<void> show(
    BuildContext context, {
    required GameCatalogEntry entry,
    required VoidCallback onStart,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GameIntroSheet(entry: entry, onStart: onStart),
    );
  }

  @override
  Widget build(BuildContext context) {
    final identity = engineIdentityFor(entry.engineType);

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Row(
              children: [
                Text(entry.emoji, style: const TextStyle(fontSize: 40)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.title,
                    style: GameTheme.display(20, color: Colors.black87),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _EngineTaglineChip(identity: identity),
            const SizedBox(height: 20),
            _InfoRow(
              icon: Icons.flag_outlined,
              label: 'You will learn',
              value: entry.learningObjective,
            ),
            const SizedBox(height: 14),
            _InfoRow(
              icon: Icons.psychology_outlined,
              label: 'How it teaches',
              value: entry.mechanicReason,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _StatPill(label: entry.difficulty, icon: Icons.speed),
                const SizedBox(width: 10),
                _StatPill(
                    label: '+${entry.xpReward} XP', icon: Icons.star_rounded),
                const SizedBox(width: 10),
                _StatPill(
                    label: '+${entry.coinsReward}',
                    icon: Icons.monetization_on_outlined),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: identity.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape:
                      RoundedRectangleBorder(borderRadius: GameTheme.rounded),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  onStart();
                },
                child: const Text("Let's play!",
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EngineTaglineChip extends StatelessWidget {
  final GameEngineIdentity identity;
  const _EngineTaglineChip({required this.identity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: identity.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(identity.icon, size: 16, color: identity.accent),
          const SizedBox(width: 6),
          Text(
            identity.tagline,
            style: GameTheme.body(13,
                color: identity.accent, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.black54),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GameTheme.body(12, color: Colors.black54)),
              const SizedBox(height: 2),
              Text(value, style: GameTheme.body(15, color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final IconData icon;
  const _StatPill({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.black54),
          const SizedBox(width: 4),
          Text(label, style: GameTheme.body(12, color: Colors.black87)),
        ],
      ),
    );
  }
}
