import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class QuestStartOverlay extends StatefulWidget {
  final String questTitle;
  final String subject;
  final String difficulty;
  final VoidCallback onComplete;

  const QuestStartOverlay({
    super.key,
    required this.questTitle,
    required this.subject,
    required this.difficulty,
    required this.onComplete,
  });

  @override
  State<QuestStartOverlay> createState() => _QuestStartOverlayState();
}

class _QuestStartOverlayState extends State<QuestStartOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _bgCtrl;
  late final AnimationController _logoCtrl;
  late final AnimationController _textCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _exitCtrl;

  late final Animation<double> _bgFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _titleFade;
  late final Animation<double> _pulseScale;
  late final Animation<double> _exitFade;

  String get _subjectEmoji {
    switch (widget.subject) {
      case 'Math':
        return '🔢';
      case 'Science':
        return '🔬';
      case 'English':
        return '📖';
      case 'Social Sciences':
        return '🌍';
      default:
        return '⚔️';
    }
  }

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _exitCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));

    _bgFade = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeIn);
    _logoScale = Tween<double>(begin: 0.2, end: 1.0)
        .animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoFade = CurvedAnimation(
        parent: _logoCtrl,
        curve: const Interval(0.0, 0.25, curve: Curves.easeIn));
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.6), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));
    _titleFade = CurvedAnimation(parent: _textCtrl, curve: Curves.easeIn);
    _pulseScale = Tween<double>(begin: 0.97, end: 1.03)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _exitFade = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn));

    // Choreograph the entrance sequence
    _bgCtrl.forward().then((_) {
      _logoCtrl.forward().then((_) {
        _textCtrl.forward().then((_) async {
          await Future.delayed(const Duration(milliseconds: 1000));
          if (mounted) {
            _pulseCtrl.stop();
            _exitCtrl.forward().then((_) {
              if (mounted) widget.onComplete();
            });
          }
        });
      });
    });
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _pulseCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  Color get _difficultyColor {
    switch (widget.difficulty.toLowerCase()) {
      case 'easy':
        return AppColors.green;
      case 'medium':
        return AppColors.orange;
      case 'hard':
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _exitFade,
      child: FadeTransition(
        opacity: _bgFade,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A0040), Color(0xFF2D1B69), Color(0xFF0D0D2E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              // Animated particle field
              const Positioned.fill(child: _StarParticles()),

              // Main content
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Pulsing logo circle
                      ScaleTransition(
                        scale: _logoScale,
                        child: FadeTransition(
                          opacity: _logoFade,
                          child: ScaleTransition(
                            scale: _pulseScale,
                            child: Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    AppColors.primary.withValues(alpha: 0.4),
                                    AppColors.primaryDark
                                        .withValues(alpha: 0.1),
                                  ],
                                ),
                                border: Border.all(
                                  color: AppColors.gold.withValues(alpha: 0.6),
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        AppColors.gold.withValues(alpha: 0.3),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  _subjectEmoji,
                                  style: const TextStyle(fontSize: 60),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Text block
                      SlideTransition(
                        position: _titleSlide,
                        child: FadeTransition(
                          opacity: _titleFade,
                          child: Column(
                            children: [
                              // "QUEST BEGINS!" banner
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppColors.gold, Color(0xFFFFB300)],
                                  ),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Text(
                                  '⚔️  QUEST BEGINS!  ⚔️',
                                  style: AppTextStyles.h3.copyWith(
                                    color: const Color(0xFF1A0040),
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Quest title
                              Text(
                                widget.questTitle,
                                style: AppTextStyles.h2.copyWith(
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.8),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 16),

                              // Subject + difficulty chips
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _QuestChip(
                                    text: widget.subject,
                                    color: AppColors.primaryLight,
                                  ),
                                  const SizedBox(width: 10),
                                  _QuestChip(
                                    text: widget.difficulty,
                                    color: _difficultyColor,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestChip extends StatelessWidget {
  final String text;
  final Color color;
  const _QuestChip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

// ── Animated star particle field ──────────────────────────────────────────────

class _StarParticles extends StatefulWidget {
  const _StarParticles();

  @override
  State<_StarParticles> createState() => _StarParticlesState();
}

class _StarParticlesState extends State<_StarParticles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _rng = Random(42);
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..repeat();
    _particles = List.generate(
      20,
      (i) => _Particle(
        x: _rng.nextDouble(),
        y: _rng.nextDouble(),
        speed: 0.1 + _rng.nextDouble() * 0.25,
        size: 8.0 + _rng.nextDouble() * 14,
        phase: _rng.nextDouble(),
        emoji: ['⭐', '✨', '💫', '🌟', '⚡', '🔥'][i % 6],
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return CustomPaint(
          painter: _ParticlePainter(
            particles: _particles,
            progress: _ctrl.value,
          ),
        );
      },
    );
  }
}

class _Particle {
  final double x;
  final double y;
  final double speed;
  final double size;
  final double phase;
  final String emoji;

  const _Particle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.phase,
    required this.emoji,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  const _ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final p in particles) {
      final t = (progress + p.phase) % 1.0;
      final y = (p.y - t * p.speed) % 1.0;
      final opacity = (sin(t * pi) * 0.7).clamp(0.0, 1.0);

      tp.text = TextSpan(
        text: p.emoji,
        style: TextStyle(
            fontSize: p.size, color: Colors.white.withValues(alpha: opacity)),
      );
      tp.layout();
      tp.paint(canvas, Offset(p.x * size.width, y * size.height));
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}
