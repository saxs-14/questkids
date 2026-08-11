import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/game_session_model.dart';
import '../core/game_config.dart';
import '../core/game_session_persistence.dart';

// ────────────────────────────────────────────────────────────────────────────
// Ecosystems — Grade 4 Social Sciences: South Africa's biomes (fynbos,
// savanna, grassland, forest, Karoo)
//
// NOTE: this is a DIFFERENT engine from explorer_map/ (engineType
// 'explorerMap'), which is a shared generic engine still used by 4 other
// catalog entries. This engine (engineType 'ecosystems') is registered
// ONLY against ss_g4_biomes.
//
// 4 Zones (5 questions each = 20 total):
//   1. Build the Biome        — tap the correct Climate / Plant / Animal
//      chip for a named biome; each chip is auto-routed to its own typed
//      slot on a postcard-style scene card (not position-in-sequence)
//   2. Biome Basics            — recall MCQ (what defines each biome)
//   3. Where Biomes Are Found  — recall MCQ (which SA regions)
//   4. Biome Animals & Plants  — recall MCQ (iconic species)
//
// Structurally distinct from every prior engine: Zone 1's fill mechanic
// routes each tapped chip to the ONE labelled slot matching its own
// category (Climate/Plant/Animal), rather than the next empty slot in a
// sequence (Circuit Lab) or a chosen drop target (Ecosystem Explorer) --
// correctness depends on content matching a slot's type, not position or
// placement choice.
// Architecture: fully self-contained StatefulWidget.
// ────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, playing, correct, wrong, streak, zoneDone, victory }

enum _Kind { biome, simple }

enum _SlotType { climate, plant, animal }

const _slotLabel = {
  _SlotType.climate: 'Climate',
  _SlotType.plant: 'Plant',
  _SlotType.animal: 'Animal',
};
const _slotEmoji = {
  _SlotType.climate: '🌤️',
  _SlotType.plant: '🌿',
  _SlotType.animal: '🐾',
};

class _Chip {
  final String text;
  final _SlotType type;
  final bool correct;
  const _Chip(this.text, this.type, this.correct);
}

class _BiomeQ {
  final String biomeName;
  final List<_Chip> chips; // 6: correct+decoy per slot type, shuffled
  const _BiomeQ({required this.biomeName, required this.chips});
}

class _SimpleQ {
  final String prompt;
  final List<String> choices; // [0] correct
  const _SimpleQ({required this.prompt, required this.choices});
}

class _Zone {
  final String name;
  final _Kind kind;
  final List<_BiomeQ> biomes;
  final List<_SimpleQ> simple;
  const _Zone.biome(this.name, this.biomes)
      : kind = _Kind.biome,
        simple = const [];
  const _Zone.simple(this.name, this.simple)
      : kind = _Kind.simple,
        biomes = const [];

  int get length => kind == _Kind.biome ? biomes.length : simple.length;
}

class EcosystemsGame extends StatefulWidget {
  final GameConfig config;
  final dynamic user;
  const EcosystemsGame({super.key, required this.config, this.user});

  @override
  State<EcosystemsGame> createState() => _EcoState();
}

class _EcoState extends State<EcosystemsGame> with TickerProviderStateMixin {
  static const _zones = [
    _Zone.biome('Build the Biome', [
      _BiomeQ(biomeName: 'Fynbos', chips: [
        _Chip('Mediterranean (wet winter, dry summer)', _SlotType.climate, true),
        _Chip('Very hot and wet all year', _SlotType.climate, false),
        _Chip('Protea', _SlotType.plant, true),
        _Chip('Baobab tree', _SlotType.plant, false),
        _Chip('Cape sugarbird', _SlotType.animal, true),
        _Chip('Polar bear', _SlotType.animal, false),
      ]),
      _BiomeQ(biomeName: 'Savanna', chips: [
        _Chip('Hot with wet summers', _SlotType.climate, true),
        _Chip('Freezing and snowy', _SlotType.climate, false),
        _Chip('Acacia tree', _SlotType.plant, true),
        _Chip('Kelp', _SlotType.plant, false),
        _Chip('Elephant', _SlotType.animal, true),
        _Chip('Penguin', _SlotType.animal, false),
      ]),
      _BiomeQ(biomeName: 'Grassland', chips: [
        _Chip('Cold dry winters, summer rain', _SlotType.climate, true),
        _Chip('Tropical rainforest climate', _SlotType.climate, false),
        _Chip('Grass', _SlotType.plant, true),
        _Chip('Cactus', _SlotType.plant, false),
        _Chip('Springbok', _SlotType.animal, true),
        _Chip('Crocodile', _SlotType.animal, false),
      ]),
      _BiomeQ(biomeName: 'Forest', chips: [
        _Chip('Warm with high rainfall', _SlotType.climate, true),
        _Chip('Freezing desert climate', _SlotType.climate, false),
        _Chip('Yellowwood tree', _SlotType.plant, true),
        _Chip('Fynbos shrub', _SlotType.plant, false),
        _Chip('Samango monkey', _SlotType.animal, true),
        _Chip('Camel', _SlotType.animal, false),
      ]),
      _BiomeQ(biomeName: 'Karoo (semi-desert)', chips: [
        _Chip('Very dry, hot days and cold nights', _SlotType.climate, true),
        _Chip('Wet and humid all year', _SlotType.climate, false),
        _Chip('Succulent plants', _SlotType.plant, true),
        _Chip('Yellowwood tree', _SlotType.plant, false),
        _Chip('Meerkat', _SlotType.animal, true),
        _Chip('Dolphin', _SlotType.animal, false),
      ]),
    ]),
    _Zone.simple('Biome Basics', [
      _SimpleQ(
          prompt: 'What is a BIOME?',
          choices: [
            'A large natural area with its own climate, plants and animals',
            'A type of city',
            'A single animal species'
          ]),
      _SimpleQ(
          prompt: 'Which biome has hot, wet summers and is home to lions and elephants?',
          choices: ['Savanna', 'Fynbos', 'Forest']),
      _SimpleQ(
          prompt:
              'Which biome is famous for its proteas and fynbos shrubs, found mainly in the Western Cape?',
          choices: ['Fynbos', 'Grassland', 'Desert']),
      _SimpleQ(
          prompt: 'Which biome covers much of the Highveld and is mostly open grass with few trees?',
          choices: ['Grassland', 'Forest', 'Fynbos']),
      _SimpleQ(
          prompt: 'Which biome is the driest, with succulent plants adapted to little water?',
          choices: ['Karoo (semi-desert)', 'Forest', 'Savanna']),
    ]),
    _Zone.simple('Where Biomes Are Found', [
      _SimpleQ(
          prompt: 'The Fynbos biome is found mainly in which part of South Africa?',
          choices: ['The Western Cape', 'Limpopo', 'KwaZulu-Natal']),
      _SimpleQ(
          prompt: 'The Savanna (bushveld) biome covers large parts of which provinces?',
          choices: ['Limpopo and Mpumalanga', 'The Western Cape', 'The Free State']),
      _SimpleQ(
          prompt: 'The Grassland biome mostly covers which region?',
          choices: ['The Highveld (Free State and Gauteng)', 'The coast of KwaZulu-Natal', 'The Kalahari']),
      _SimpleQ(
          prompt: 'Indigenous forests in South Africa are found mostly...?',
          choices: [
            'In small patches along the southern and eastern coast',
            'Across the whole country',
            'Only in the desert'
          ]),
      _SimpleQ(
          prompt: 'The Karoo biome is found mainly in which province?',
          choices: ['The Northern Cape', 'KwaZulu-Natal', 'Gauteng']),
    ]),
    _Zone.simple('Biome Animals & Plants', [
      _SimpleQ(
          prompt: 'Which animal is commonly found roaming the Savanna biome?',
          choices: ['Elephant', 'Penguin', 'Polar bear']),
      _SimpleQ(
          prompt: "The Protea is South Africa's national flower and grows in which biome?",
          choices: ['Fynbos', 'Desert', 'Forest']),
      _SimpleQ(
          prompt: "Springbok, South Africa's national animal, are most at home in which biome?",
          choices: ['Grassland', 'Rainforest', 'Fynbos']),
      _SimpleQ(
          prompt: 'Meerkats are well adapted to survive in which biome?',
          choices: ['Karoo (semi-desert)', 'Forest', 'Fynbos']),
      _SimpleQ(
          prompt: 'Which plant type is specially adapted to store water in the dry Karoo?',
          choices: ['Succulents', 'Ferns', 'Water lilies']),
    ]),
  ];

  static const _wrongReactions = [
    'Not quite -- think about that biome!',
    "Hmm, that doesn't belong there!",
    'Almost -- picture the landscape!',
  ];

  static const _bg1 = Color(0xFF16301C);
  static const _bg2 = Color(0xFF2B4A2E);
  static const _card = Color(0xFF3B6142);
  static const _leaf = Color(0xFFA9D66B);

  late AnimationController _ambientCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _flashCtrl;
  late AnimationController _burstCtrl;
  late AnimationController _shakeCtrl;

  late Animation<double> _ambientAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _flashAnim;
  late Animation<double> _burstAnim;
  late Animation<double> _shakeAnim;

  int _zoneIdx = 0;
  int _qIdx = 0;
  int _correctCount = 0;
  int _streak = 0;
  int _totalXP = 0;

  _Phase _phase = _Phase.intro;
  int? _selectedIndex;

  // Biome-zone state
  final Map<_SlotType, _Chip?> _placed = {};
  final Set<int> _usedChipIdx = {};
  bool? _lastBiomeCorrect;

  String _wrongReaction = '';

  final _rng = math.Random();

  String get _uid => (widget.user?.uid as String?) ?? '';

  int get _totalQuestions => _zones.fold<int>(0, (sum, z) => sum + z.length);

  final List<Timer> _pendingTimers = [];

  void _delayed(int ms, VoidCallback callback) {
    late final Timer timer;
    timer = Timer(Duration(milliseconds: ms), () {
      _pendingTimers.remove(timer);
      if (mounted) callback();
    });
    _pendingTimers.add(timer);
  }

  @override
  void initState() {
    super.initState();
    _initAnims();
    _delayed(700, _startGame);
  }

  void _initAnims() {
    _ambientCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 6))
      ..repeat(reverse: true);
    _ambientAnim = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ambientCtrl, curve: Curves.easeInOut));

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

    _flashCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _flashAnim = CurvedAnimation(parent: _flashCtrl, curve: Curves.easeOut);

    _burstCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));
    _burstAnim = CurvedAnimation(parent: _burstCtrl, curve: Curves.easeOut);

    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _shakeAnim = CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    for (final timer in List<Timer>.from(_pendingTimers)) {
      timer.cancel();
    }
    _pendingTimers.clear();
    _ambientCtrl.dispose();
    _fadeCtrl.dispose();
    _flashCtrl.dispose();
    _burstCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _zoneIdx = 0;
      _qIdx = 0;
      _correctCount = 0;
      _streak = 0;
      _totalXP = 0;
      _phase = _Phase.playing;
      _selectedIndex = null;
    });
    _setupCurrentQuestion();
    _fadeCtrl.forward(from: 0);
  }

  void _setupCurrentQuestion() {
    _placed.clear();
    _usedChipIdx.clear();
    _lastBiomeCorrect = null;
  }

  Object? _cachedQ;
  List<String> _cachedChoices = [];

  List<String> _getShuffledChoices(_SimpleQ q) {
    if (!identical(_cachedQ, q)) {
      _cachedQ = q;
      _cachedChoices = List<String>.from(q.choices)..shuffle(_rng);
    }
    return _cachedChoices;
  }

  void _onSimpleAnswer(int index) {
    if (_phase != _Phase.playing) return;
    final q = _zones[_zoneIdx].simple[_qIdx];
    final choices = _getShuffledChoices(q);
    final isCorrect = choices[index] == q.choices[0];
    setState(() => _selectedIndex = index);
    _applyAnswerResult(isCorrect);
  }

  void _onTapChip(int chipIdx) {
    if (_phase != _Phase.playing) return;
    final q = _zones[_zoneIdx].biomes[_qIdx];
    if (_usedChipIdx.contains(chipIdx)) return;
    final chip = q.chips[chipIdx];
    if (_placed[chip.type] != null) return; // that slot already filled

    setState(() {
      _usedChipIdx.add(chipIdx);
      _placed[chip.type] = chip;
    });

    if (_placed.length == _SlotType.values.length) {
      _delayed(300, _evaluateBiome);
    }
  }

  void _evaluateBiome() {
    if (!mounted) return;
    final allCorrect = _SlotType.values.every((t) => _placed[t]?.correct == true);
    setState(() => _lastBiomeCorrect = allCorrect);
    _applyAnswerResult(allCorrect);
  }

  void _applyAnswerResult(bool isCorrect) {
    setState(() {
      if (isCorrect) {
        _correctCount++;
        _streak++;
        _totalXP += 10;
      } else {
        _streak = 0;
        _totalXP += 2;
        _wrongReaction = _wrongReactions[_rng.nextInt(_wrongReactions.length)];
      }
      _phase = isCorrect ? _Phase.correct : _Phase.wrong;
    });

    if (isCorrect) {
      _flashCtrl.forward(from: 0);
      final isStreak = _streak > 0 && _streak % 3 == 0;
      if (isStreak) {
        _delayed(300, () {
          setState(() => _phase = _Phase.streak);
          _burstCtrl.forward(from: 0);
          _delayed(1600, _advance);
        });
      } else {
        _delayed(1200, _advance);
      }
    } else {
      _shakeCtrl.forward(from: 0);
      _delayed(1800, _advance);
    }
  }

  void _advance() {
    if (!mounted) return;
    final zone = _zones[_zoneIdx];
    final next = _qIdx + 1;

    if (next >= zone.length) {
      if (_zoneIdx + 1 >= _zones.length) {
        _persistSession();
        setState(() => _phase = _Phase.victory);
      } else {
        setState(() => _phase = _Phase.zoneDone);
        _delayed(2000, () {
          setState(() {
            _zoneIdx++;
            _qIdx = 0;
            _selectedIndex = null;
            _phase = _Phase.playing;
          });
          _setupCurrentQuestion();
          _fadeCtrl.forward(from: 0);
        });
      }
    } else {
      setState(() {
        _qIdx = next;
        _selectedIndex = null;
        _phase = _Phase.playing;
      });
      _setupCurrentQuestion();
      _fadeCtrl.forward(from: 0);
    }
  }

  void _persistSession() {
    final total = _totalQuestions;
    final accuracy = total > 0 ? _correctCount / total : 0.0;
    final isPerfect = _correctCount == total;
    final isWin = _correctCount > total / 2;
    var xp = _totalXP;
    if (isPerfect) {
      xp += 100;
    } else if (isWin) {
      xp += 50;
    }
    setState(() => _totalXP = xp);

    final uid = _uid;
    if (uid.isEmpty) return;
    final session = GameSessionModel(
      id: const Uuid().v4(),
      uid: uid,
      grade: widget.config.grade,
      subject: widget.config.subject,
      engineType: widget.config.engineType,
      score: (accuracy * 100).round(),
      xpEarned: xp,
      coinsEarned: xp ~/ 10,
      accuracy: accuracy,
      timeTakenSeconds: 0,
      completedAt: DateTime.now(),
      result: isWin ? 'win' : 'complete',
      metadata: {
        'topicId': widget.config.topicId,
        'subtopicId': widget.config.subtopicId,
        'correctCount': _correctCount,
        'totalQuestions': total,
      },
    );
    persistGameSession(session);
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.intro) {
      return const _IntroScreen();
    }
    if (_phase == _Phase.victory) {
      return _VictoryScreen(
        correctCount: _correctCount,
        total: _totalQuestions,
        totalXP: _totalXP,
        onReplay: _startGame,
        onExit: () => Navigator.of(context).pop(),
      );
    }

    final zone = _zones[_zoneIdx];
    final total = _totalQuestions;
    final completedSteps =
        _zones.take(_zoneIdx).fold<int>(0, (sum, z) => sum + z.length) + _qIdx;
    final revealed = _phase == _Phase.correct || _phase == _Phase.wrong;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_bg1, _bg2],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ambientAnim,
              builder: (context, _) =>
                  CustomPaint(painter: _LeafDriftBgPainter(_ambientAnim.value)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _EcoHeader(
                  zoneName: zone.name,
                  zoneIdx: _zoneIdx,
                  totalZones: _zones.length,
                  completedSteps: completedSteps,
                  totalSteps: total,
                ),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: zone.kind == _Kind.biome
                          ? _buildBiomeQuestion(zone.biomes[_qIdx])
                          : _buildSimpleQuestion(zone.simple[_qIdx], revealed),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_phase == _Phase.correct)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _flashAnim,
                builder: (context, _) => Opacity(
                  opacity: (1 - _flashAnim.value).clamp(0.0, 1.0) * 0.3,
                  child: Container(color: _leaf),
                ),
              ),
            ),
          if (_phase == _Phase.streak)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _burstAnim,
                builder: (context, _) => CustomPaint(
                  painter: _SparkleShowerPainter(_burstAnim.value),
                  size: Size.infinite,
                ),
              ),
            ),
          if (_phase == _Phase.zoneDone)
            _ZoneDoneOverlay(
              completedZoneName: zone.name,
              nextZoneName: _zoneIdx + 1 < _zones.length ? _zones[_zoneIdx + 1].name : null,
            ),
        ],
      ),
    );
  }

  Widget _buildBiomeQuestion(_BiomeQ q) {
    final revealed = _phase == _Phase.correct || _phase == _Phase.wrong;

    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          'Build the ${q.biomeName} biome!',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1F12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            children: [
              for (final type in _SlotType.values)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: _BiomeSlot(type: type, chip: _placed[type]),
                ),
            ],
          ),
        ),
        if (_phase == _Phase.wrong && _lastBiomeCorrect == false)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _wrongReaction,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 18),
        AnimatedBuilder(
          animation: _shakeAnim,
          builder: (context, _) {
            final dx = _phase == _Phase.wrong
                ? math.sin(_shakeAnim.value * math.pi * 6) * 5
                : 0.0;
            return Transform.translate(
              offset: Offset(dx, 0),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < q.chips.length; i++)
                    _EcoChip(
                      chip: q.chips[i],
                      used: _usedChipIdx.contains(i),
                      revealed: revealed,
                      onTap: () => _onTapChip(i),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSimpleQuestion(_SimpleQ q, bool revealed) {
    final choices = _getShuffledChoices(q);
    return Column(
      children: [
        const SizedBox(height: 12),
        Text(
          q.prompt,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 22),
        AnimatedBuilder(
          animation: _shakeAnim,
          builder: (context, _) {
            final dx = _phase == _Phase.wrong
                ? math.sin(_shakeAnim.value * math.pi * 6) * 6
                : 0.0;
            return Transform.translate(
              offset: Offset(dx, 0),
              child: Wrap(
                spacing: 14,
                runSpacing: 14,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < choices.length; i++)
                    _SimpleTile(
                      label: choices[i],
                      selected: _selectedIndex == i,
                      isCorrect: choices[i] == q.choices[0],
                      revealed: revealed,
                      onTap: () => _onSimpleAnswer(i),
                    ),
                ],
              ),
            );
          },
        ),
        if (_phase == _Phase.wrong)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              '$_wrongReaction The answer was ${q.choices[0]}.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ── Biome scene slot ─────────────────────────────────────────────────────────

class _BiomeSlot extends StatelessWidget {
  final _SlotType type;
  final _Chip? chip;
  const _BiomeSlot({required this.type, required this.chip});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 84,
          child: Row(
            children: [
              Text(_slotEmoji[type]!, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  _slotLabel[type]!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: chip != null ? _EcoState._card : Colors.white10,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: chip != null ? _EcoState._leaf : Colors.white24),
            ),
            alignment: Alignment.centerLeft,
            child: Text(
              chip?.text ?? '...',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Eco chip (bank) ──────────────────────────────────────────────────────────

class _EcoChip extends StatelessWidget {
  final _Chip chip;
  final bool used;
  final bool revealed;
  final VoidCallback onTap;
  const _EcoChip({required this.chip, required this.used, required this.revealed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Color border = _EcoState._leaf.withValues(alpha: 0.6);
    if (revealed && used) {
      border = chip.correct ? const Color(0xFF4CAF7D) : const Color(0xFFE05656);
    }
    return GestureDetector(
      onTap: used ? null : onTap,
      child: Opacity(
        opacity: used ? 0.35 : 1.0,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _EcoState._card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_slotEmoji[chip.type]!, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 5),
              Flexible(
                child: Text(chip.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Simple tile (MCQ) ────────────────────────────────────────────────────────

class _SimpleTile extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isCorrect;
  final bool revealed;
  final VoidCallback onTap;
  const _SimpleTile({
    required this.label,
    required this.selected,
    required this.isCorrect,
    required this.revealed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color fill = _EcoState._card;
    if (revealed && isCorrect) fill = const Color(0xFF4CAF7D);
    if (revealed && selected && !isCorrect) fill = const Color(0xFFE05656);

    return GestureDetector(
      onTap: revealed ? null : onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 110, maxWidth: 280),
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _EcoState._leaf.withValues(alpha: 0.7), width: 2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

// ── Painters ─────────────────────────────────────────────────────────────────

class _LeafDriftBgPainter extends CustomPainter {
  final double t;
  const _LeafDriftBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _EcoState._leaf.withValues(alpha: 0.04 + 0.03 * t);
    const spacing = 28.0;
    for (var y = 0.0; y < size.height; y += spacing) {
      for (var x = 0.0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LeafDriftBgPainter oldDelegate) => oldDelegate.t != t;
}

class _SparkleShowerPainter extends CustomPainter {
  final double t;
  const _SparkleShowerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(97);
    for (var i = 0; i < 18; i++) {
      final startX = rng.nextDouble() * size.width;
      final speed = 0.5 + rng.nextDouble() * 0.6;
      final y = (t * speed) * (size.height + 40) - 20;
      final x = startX + math.sin((t * 6) + i) * 12;
      final paint = Paint()
        ..color = _EcoState._leaf.withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkleShowerPainter oldDelegate) => oldDelegate.t != t;
}

// ── Header / progress ────────────────────────────────────────────────────────

class _EcoHeader extends StatelessWidget {
  final String zoneName;
  final int zoneIdx;
  final int totalZones;
  final int completedSteps;
  final int totalSteps;
  const _EcoHeader({
    required this.zoneName,
    required this.zoneIdx,
    required this.totalZones,
    required this.completedSteps,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        children: [
          Row(
            children: [
              const Text('🌍', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    Text('Zone ${zoneIdx + 1}/$totalZones',
                        style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    Text(
                      zoneName,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 30),
            ],
          ),
          const SizedBox(height: 8),
          _EcoTrail(completed: completedSteps, total: totalSteps),
        ],
      ),
    );
  }
}

class _EcoTrail extends StatelessWidget {
  final int completed;
  final int total;
  const _EcoTrail({required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Container(
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: Colors.white24,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < total; i++)
                Text(
                  i < completed ? '🌿' : '·',
                  style: TextStyle(
                    fontSize: i < completed ? 12 : 10,
                    color: i < completed ? null : Colors.white38,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ZoneDoneOverlay extends StatelessWidget {
  final String completedZoneName;
  final String? nextZoneName;
  const _ZoneDoneOverlay({required this.completedZoneName, required this.nextZoneName});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black45,
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.symmetric(horizontal: 40),
          decoration: BoxDecoration(
            color: _EcoState._card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _EcoState._leaf, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🌍', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text('$completedZoneName complete!',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              if (nextZoneName != null) ...[
                const SizedBox(height: 6),
                Text('Next: $nextZoneName', style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroScreen extends StatelessWidget {
  const _IntroScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_EcoState._bg1, _EcoState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🌍🌿', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 16),
                  Text(
                    'Ecosystems',
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Build South Africa's biomes -- fynbos, savanna, grassland "
                    'and more!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: _EcoState._leaf),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VictoryScreen extends StatelessWidget {
  final int correctCount;
  final int total;
  final int totalXP;
  final VoidCallback onReplay;
  final VoidCallback onExit;
  const _VictoryScreen({
    required this.correctCount,
    required this.total,
    required this.totalXP,
    required this.onReplay,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (correctCount / total * 100).round() : 0;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_EcoState._bg1, _EcoState._bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆🌍', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('Biome Master!',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text('$correctCount / $total correct ($pct%)',
                      style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('+$totalXP XP',
                      style: const TextStyle(color: _EcoState._leaf, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: onReplay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _EcoState._card,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    ),
                    child: const Text('Play Again'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: onExit,
                    child: const Text('Exit', style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
