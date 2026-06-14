import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../data/repositories/grade4_repository.dart';

class TugOfWarScreen extends StatefulWidget {
  final String worldId;
  final dynamic user;
  const TugOfWarScreen({required this.worldId, required this.user});

  @override
  State<TugOfWarScreen> createState() => _TugOfWarScreenState();
}

class _TugOfWarScreenState extends State<TugOfWarScreen> {
  final Grade4Repository _repo = Grade4Repository();
  final _rng = Random();
  int _index = 0;
  int _correct = 0;
  final int _total = 10;
  int _timeTaken = 0;
  Timer? _timer;
  List<Map<String, dynamic>> _questions = [];
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _generateQuestions();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _timeTaken++);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _generateQuestions() {
    _questions = List.generate(_total, (_) {
      final a = _rng.nextInt(12) + 1;
      final b = _rng.nextInt(12) + 1;
      return {'a': a, 'b': b, 'answer': a * b};
    });
  }

  void _submitAnswer(int value) {
    final q = _questions[_index];
    final correct = q['answer'] as int;
    if (value == correct) _correct++;
    if (_index + 1 >= _total) {
      _finish();
    } else {
      setState(() => _index++);
    }
  }

  List<int> _optionsForQuestion(Map<String, dynamic> q) {
    final correct = q['answer'] as int;
    final Set<int> opts = {correct};
    while (opts.length < 8) {
      final delta = _rng.nextInt(21) - 10; // -10..10
      final candidate = correct + delta;
      if (candidate > 0) opts.add(candidate);
    }
    final list = opts.toList();
    list.shuffle(_rng);
    return list;
  }

  Future<void> _finish() async {
    _stopTimer();
    setState(() => _finished = true);
    final xpEarned = (_correct * 10) + (_total == _correct ? 50 : 0);
    final coinsEarned = xpEarned ~/ 10;
    final result = _correct == _total ? 'perfect' : (_correct >= (_total / 2) ? 'win' : 'lose');

    final battleData = {
      'uid': widget.user?.uid,
      'playerName': widget.user?.name ?? 'Player',
      'opponentId': 'cpu',
      'opponentName': 'CPU',
      'topic': 'Multiplication',
      'difficulty': 'Mixed',
      'questionsTotal': _total,
      'correctAnswers': _correct,
      'xpEarned': xpEarned,
      'coinsEarned': coinsEarned,
      'result': result,
      'timeTakenSeconds': _timeTaken,
      'grade': widget.user?.grade ?? 'Grade 4',
    };

    try {
      await _repo.saveMathBattle(battleData);
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(result == 'perfect' ? 'Perfect! 🎉' : result == 'win' ? 'You won! 🎉' : 'Try again'),
            content: Text('Score: $_correct/$_total\nXP: $xpEarned\nCoins: $coinsEarned'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
              TextButton(onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst), child: const Text('Home')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving result: $e')));
    }
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) {
      return Scaffold(appBar: AppBar(title: const Text('Tug of War')), body: Center(child: Text('Finished: $_correct/$_total')));
    }
    final q = _questions[_index];
    return Scaffold(
      appBar: AppBar(title: const Text('Tug of War')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text('Question ${_index + 1} / $_total', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Text('${q['a']} × ${q['b']} = ?', style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 24),
          Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: _optionsForQuestion(q).map((option) => ElevatedButton(onPressed: () => _submitAnswer(option), child: Text('$option'))).toList()),
          const Spacer(),
          Text('Time: $_timeTaken s'),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: (_index + 1) / _total),
        ]),
      ),
    );
  }
}
