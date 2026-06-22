import '../core/game_config.dart';
import '../core/game_engine.dart';

class CircuitBuilderEngine extends GameEngine {
  @override
  final GameConfig config;

  CircuitBuilderEngine(this.config);

  static const _circuits = [
    {
      'id': 'series_one_bulb',
      'description': 'Complete the series circuit: drag the missing component to the gap.',
      'layout': '🔋 —?— 💡',
      'blanks': [
        {'position': 0, 'correctComponent': 'wire', 'emoji': '〰️', 'hint': 'Connects components'},
      ],
      'bank': ['wire', 'bulb', 'switch', 'resistor'],
      'labels': {'wire': '〰️ Wire', 'bulb': '💡 Bulb', 'switch': '🔘 Switch', 'resistor': '⬛ Resistor'},
    },
    {
      'id': 'series_switch',
      'description': 'Add a switch to control this circuit.',
      'layout': '🔋 — 💡 —?— 💡',
      'blanks': [
        {'position': 0, 'correctComponent': 'switch', 'emoji': '🔘', 'hint': 'Opens and closes the circuit'},
      ],
      'bank': ['wire', 'bulb', 'switch', 'resistor'],
      'labels': {'wire': '〰️ Wire', 'bulb': '💡 Bulb', 'switch': '🔘 Switch', 'resistor': '⬛ Resistor'},
    },
    {
      'id': 'series_battery',
      'description': 'This circuit needs a power source!',
      'layout': '?— 🔘 — 💡',
      'blanks': [
        {'position': 0, 'correctComponent': 'battery', 'emoji': '🔋', 'hint': 'Provides electrical energy'},
      ],
      'bank': ['battery', 'bulb', 'switch', 'resistor'],
      'labels': {'battery': '🔋 Battery', 'bulb': '💡 Bulb', 'switch': '🔘 Switch', 'resistor': '⬛ Resistor'},
    },
    {
      'id': 'series_two_gaps',
      'description': 'Fill in BOTH missing components.',
      'layout': '🔋 —?— 💡 —?— 💡',
      'blanks': [
        {'position': 0, 'correctComponent': 'switch', 'emoji': '🔘', 'hint': 'Controls the flow'},
        {'position': 1, 'correctComponent': 'wire', 'emoji': '〰️', 'hint': 'Connects the last bulb'},
      ],
      'bank': ['wire', 'bulb', 'switch', 'resistor'],
      'labels': {'wire': '〰️ Wire', 'bulb': '💡 Bulb', 'switch': '🔘 Switch', 'resistor': '⬛ Resistor'},
    },
    {
      'id': 'resistor_protection',
      'description': 'Protect the bulb by adding a resistor.',
      'layout': '🔋 — 💡 —?',
      'blanks': [
        {'position': 0, 'correctComponent': 'resistor', 'emoji': '⬛', 'hint': 'Limits current flow'},
      ],
      'bank': ['wire', 'bulb', 'switch', 'resistor'],
      'labels': {'wire': '〰️ Wire', 'bulb': '💡 Bulb', 'switch': '🔘 Switch', 'resistor': '⬛ Resistor'},
    },
    {
      'id': 'open_circuit',
      'description': 'The bulb is off. What closes the circuit?',
      'layout': '🔋 — 💡 — ? — 🔋',
      'blanks': [
        {'position': 0, 'correctComponent': 'switch', 'emoji': '🔘', 'hint': 'Must be closed for current to flow'},
      ],
      'bank': ['wire', 'bulb', 'switch', 'battery'],
      'labels': {'wire': '〰️ Wire', 'bulb': '💡 Bulb', 'switch': '🔘 Switch', 'battery': '🔋 Battery'},
    },
    {
      'id': 'two_batteries',
      'description': 'Add a second battery to increase the brightness.',
      'layout': '🔋 — ? — 💡 — 🔘',
      'blanks': [
        {'position': 0, 'correctComponent': 'battery', 'emoji': '🔋', 'hint': 'More power = brighter bulb'},
      ],
      'bank': ['battery', 'bulb', 'switch', 'wire'],
      'labels': {'battery': '🔋 Battery', 'bulb': '💡 Bulb', 'switch': '🔘 Switch', 'wire': '〰️ Wire'},
    },
    {
      'id': 'buzzer_circuit',
      'description': 'Replace the bulb with a sound maker.',
      'layout': '🔋 — 🔘 — ?',
      'blanks': [
        {'position': 0, 'correctComponent': 'buzzer', 'emoji': '🔔', 'hint': 'Makes a sound when current flows'},
      ],
      'bank': ['buzzer', 'bulb', 'switch', 'wire'],
      'labels': {'buzzer': '🔔 Buzzer', 'bulb': '💡 Bulb', 'switch': '🔘 Switch', 'wire': '〰️ Wire'},
    },
    {
      'id': 'ammeter_place',
      'description': 'Where do you place the ammeter to measure current?',
      'layout': '🔋 — 💡 — ? — 🔘',
      'blanks': [
        {'position': 0, 'correctComponent': 'ammeter', 'emoji': '🅰️', 'hint': 'Measures current in series'},
      ],
      'bank': ['ammeter', 'voltmeter', 'resistor', 'battery'],
      'labels': {'ammeter': '🅰️ Ammeter', 'voltmeter': '🆅 Voltmeter', 'resistor': '⬛ Resistor', 'battery': '🔋 Battery'},
    },
    {
      'id': 'complete_parallel',
      'description': 'Add a bulb to this parallel branch.',
      'layout': '🔋 — [💡 || ?] — 🔘',
      'blanks': [
        {'position': 0, 'correctComponent': 'bulb', 'emoji': '💡', 'hint': 'In parallel, current splits'},
      ],
      'bank': ['bulb', 'switch', 'wire', 'battery'],
      'labels': {'bulb': '💡 Bulb', 'switch': '🔘 Switch', 'wire': '〰️ Wire', 'battery': '🔋 Battery'},
    },
  ];

  @override
  List<Map<String, dynamic>> generateQuestions() {
    final pool = [..._circuits];
    pool.shuffle();
    return pool.take(config.questionCount).toList().cast<Map<String, dynamic>>();
  }

  @override
  GameAnswerResult checkAnswer(Map<String, dynamic> question, dynamic answer, {int elapsedThresholdSeconds = 5}) {
    final blanks = (question['blanks'] as List).cast<Map<String, dynamic>>();
    final submitted = answer as List<String?>? ?? [];

    int correct = 0;
    for (int i = 0; i < blanks.length; i++) {
      if (i < submitted.length && submitted[i] == blanks[i]['correctComponent']) correct++;
    }
    final allCorrect = correct == blanks.length;
    return GameAnswerResult(correct: allCorrect, xpDelta: allCorrect ? 15 : 0);
  }

  @override
  GameSessionResult buildResult({required int correct, required int total, required int timeTakenSeconds, bool earlyWin = false}) {
    return defaultResult(correct: correct, total: total, timeTakenSeconds: timeTakenSeconds, earlyWin: earlyWin);
  }
}
