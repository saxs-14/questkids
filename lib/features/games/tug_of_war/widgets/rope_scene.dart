import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Animated rope-and-flag scene for Tug of War.
///
/// [flagPosition] in [-1.0, 1.0]:
///   -1.0 = flag fully pulled to opponent's side
///    0.0 = center (tied)
///   +1.0 = flag fully pulled to player's side
///
/// Uses [AnimationController] + [Tween] for smooth 400 ms transitions.
class RopeScene extends StatefulWidget {
  final double flagPosition;
  final String playerEmoji;
  final String opponentEmoji;
  final String opponentName;

  const RopeScene({
    super.key,
    required this.flagPosition,
    this.playerEmoji = '🧑',
    this.opponentEmoji = '👾',
    this.opponentName = 'Opponent',
  });

  @override
  State<RopeScene> createState() => _RopeSceneState();
}

class _RopeSceneState extends State<RopeScene>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  double _prevFlag = 0.0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _anim = AlwaysStoppedAnimation(widget.flagPosition);
    _prevFlag = widget.flagPosition;
  }

  @override
  void didUpdateWidget(RopeScene old) {
    super.didUpdateWidget(old);
    if (old.flagPosition != widget.flagPosition) {
      final from = _anim.value;
      _anim = Tween<double>(begin: from, end: widget.flagPosition).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
      );
      _ctrl.forward(from: 0.0);
      _prevFlag = widget.flagPosition;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final centerX = w / 2;
        // Flag travels ±(centerX - 32) from center
        final maxOffset = (centerX - 32).clamp(40.0, 200.0);

        return AnimatedBuilder(
          animation: _anim,
          builder: (context, _) {
            final pos = _anim.value;
            final flagX = centerX + pos * maxOffset;
            // -pos = opponent pulling (flag goes left = player losing)
            final playerPulling = pos > _prevFlag || pos > 0;
            final opponentPulling = pos < _prevFlag || pos < 0;

            return Stack(
              children: [
                // Background split
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        color: AppColors.blue.withAlpha(25),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        color: AppColors.accent.withAlpha(25),
                      ),
                    ),
                  ],
                ),

                // Rope
                Positioned(
                  top: h * 0.55,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 6,
                    color: const Color(0xFF795548),
                  ),
                ),

                // Player character (left side)
                Positioned(
                  left: 8,
                  top: h * 0.35,
                  child: _CharacterWidget(
                    emoji: widget.playerEmoji,
                    isPulling: playerPulling,
                    isLosing: pos < -0.3,
                    facingRight: true,
                  ),
                ),

                // Opponent character (right side)
                Positioned(
                  right: 8,
                  top: h * 0.35,
                  child: _CharacterWidget(
                    emoji: widget.opponentEmoji,
                    isPulling: opponentPulling,
                    isLosing: pos > 0.3,
                    facingRight: false,
                  ),
                ),

                // Flag (red triangle marker)
                Positioned(
                  left: flagX - 12,
                  top: h * 0.42,
                  child: const _FlagWidget(),
                ),

                // Center line
                Positioned(
                  left: centerX - 1,
                  top: h * 0.38,
                  width: 2,
                  height: h * 0.28,
                  child: Container(
                    color: Colors.black26,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _CharacterWidget extends StatelessWidget {
  final String emoji;
  final bool isPulling;
  final bool isLosing;
  final bool facingRight;

  const _CharacterWidget({
    required this.emoji,
    required this.isPulling,
    required this.isLosing,
    required this.facingRight,
  });

  @override
  Widget build(BuildContext context) {
    // Winning side leans forward; losing side stumbles back
    final angle = isLosing
        ? (facingRight ? 0.3 : -0.3)
        : (isPulling ? (facingRight ? -0.2 : 0.2) : 0.0);

    return Transform.rotate(
      angle: angle,
      child: Text(emoji, style: const TextStyle(fontSize: 40)),
    );
  }
}

class _FlagWidget extends StatelessWidget {
  const _FlagWidget();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Flag cloth
        Container(
          width: 24,
          height: 16,
          color: AppColors.accent,
        ),
        // Pole
        Container(
          width: 2,
          height: 20,
          color: AppColors.textPrimary,
        ),
      ],
    );
  }
}
