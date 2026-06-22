import '../core/game_config.dart';
import '../core/game_engine.dart';

class BudgetBuilderEngine extends GameEngine {
  @override
  final GameConfig config;

  BudgetBuilderEngine(this.config);

  // Each question is a budget scenario with multiple items to categorise.
  static const _scenarios = [
    {
      'budget': 500,
      'scenario': 'Your family gets R500 for the month.',
      'items': [
        {'name': 'Bread and milk', 'cost': 60, 'category': 'need', 'emoji': '🍞', 'reason': 'Food is essential for survival'},
        {'name': 'School uniform', 'cost': 150, 'category': 'need', 'emoji': '👕', 'reason': 'Required for school'},
        {'name': 'Video game', 'cost': 300, 'category': 'skip', 'emoji': '🎮', 'reason': 'Too expensive this month'},
        {'name': 'Movie ticket', 'cost': 80, 'category': 'want', 'emoji': '🎬', 'reason': 'Fun but not essential'},
      ],
    },
    {
      'budget': 300,
      'scenario': 'You earned R300 from helping a neighbour.',
      'items': [
        {'name': 'Save for school fees', 'cost': 120, 'category': 'need', 'emoji': '🏫', 'reason': 'Education is a priority'},
        {'name': 'Sweets and chips', 'cost': 50, 'category': 'want', 'emoji': '🍬', 'reason': 'Nice to have, not necessary'},
        {'name': 'New shoes (R280)', 'cost': 280, 'category': 'skip', 'emoji': '👟', 'reason': 'Costs more than budget'},
        {'name': 'Bus fare for the week', 'cost': 80, 'category': 'need', 'emoji': '🚌', 'reason': 'Transport to school is essential'},
      ],
    },
    {
      'budget': 800,
      'scenario': 'The family budget for this week is R800.',
      'items': [
        {'name': 'Electricity bill', 'cost': 200, 'category': 'need', 'emoji': '💡', 'reason': 'Essential service — no lights without it'},
        {'name': 'Takeaway dinner', 'cost': 120, 'category': 'want', 'emoji': '🍔', 'reason': 'Can cook at home instead'},
        {'name': 'New TV', 'cost': 900, 'category': 'skip', 'emoji': '📺', 'reason': 'Exceeds weekly budget'},
        {'name': 'Groceries', 'cost': 350, 'category': 'need', 'emoji': '🛒', 'reason': 'Food for the family is a need'},
      ],
    },
    {
      'budget': 200,
      'scenario': 'You have R200 pocket money this month.',
      'items': [
        {'name': 'Birthday card for mom', 'cost': 25, 'category': 'need', 'emoji': '💌', 'reason': 'Shows love and care for family'},
        {'name': 'Comic book', 'cost': 40, 'category': 'want', 'emoji': '📚', 'reason': 'Fun reading, not essential'},
        {'name': 'Limited edition sneakers', 'cost': 350, 'category': 'skip', 'emoji': '👟', 'reason': 'Way over budget'},
        {'name': 'Stationery for school', 'cost': 60, 'category': 'need', 'emoji': '✏️', 'reason': 'Needed for learning'},
      ],
    },
    {
      'budget': 1000,
      'scenario': 'Small business income: R1 000 this month.',
      'items': [
        {'name': 'Stock to resell (materials)', 'cost': 400, 'category': 'need', 'emoji': '📦', 'reason': 'Without stock, no income next month'},
        {'name': 'Save 10% in emergency fund', 'cost': 100, 'category': 'need', 'emoji': '🏦', 'reason': 'Good financial habit — savings first'},
        {'name': 'New phone', 'cost': 1200, 'category': 'skip', 'emoji': '📱', 'reason': 'More than total income'},
        {'name': 'Advertising flyers', 'cost': 80, 'category': 'want', 'emoji': '📄', 'reason': 'Helpful but not urgent right now'},
      ],
    },
    {
      'budget': 400,
      'scenario': 'Your class is planning a school trip with R400 per learner.',
      'items': [
        {'name': 'Transport to the museum', 'cost': 80, 'category': 'need', 'emoji': '🚌', 'reason': 'Can\'t get there without it'},
        {'name': 'Museum entry fee', 'cost': 60, 'category': 'need', 'emoji': '🏛️', 'reason': 'The main purpose of the trip'},
        {'name': 'Fancy restaurant lunch', 'cost': 180, 'category': 'want', 'emoji': '🍽️', 'reason': 'Pack a lunch instead'},
        {'name': 'Gift shop toy', 'cost': 220, 'category': 'skip', 'emoji': '🧸', 'reason': 'Overspending on non-essentials'},
      ],
    },
    {
      'budget': 600,
      'scenario': 'Household budget when the main earner is away.',
      'items': [
        {'name': 'Water and rates bill', 'cost': 150, 'category': 'need', 'emoji': '💧', 'reason': 'Clean water is a basic right and need'},
        {'name': 'Pet grooming', 'cost': 200, 'category': 'want', 'emoji': '🐕', 'reason': 'Nice for pet, not critical this month'},
        {'name': 'Medical prescription', 'cost': 90, 'category': 'need', 'emoji': '💊', 'reason': 'Health is a priority'},
        {'name': 'Weekend concert tickets', 'cost': 350, 'category': 'skip', 'emoji': '🎵', 'reason': 'Entertainment during a tight month'},
      ],
    },
  ];

  @override
  List<Map<String, dynamic>> generateQuestions() {
    final pool = [..._scenarios];
    pool.shuffle();
    return pool.take(config.questionCount).toList().cast<Map<String, dynamic>>();
  }

  @override
  GameAnswerResult checkAnswer(Map<String, dynamic> question, dynamic answer, {int elapsedThresholdSeconds = 5}) {
    final items = (question['items'] as List).cast<Map<String, dynamic>>();
    final submitted = (answer as Map<String, String>?) ?? {};
    int correct = 0;
    for (final item in items) {
      if (submitted[item['name']] == item['category']) correct++;
    }
    final allCorrect = correct == items.length;
    return GameAnswerResult(correct: allCorrect, xpDelta: allCorrect ? 20 : correct * 5);
  }

  @override
  GameSessionResult buildResult({required int correct, required int total, required int timeTakenSeconds, bool earlyWin = false}) {
    return defaultResult(correct: correct, total: total, timeTakenSeconds: timeTakenSeconds, earlyWin: earlyWin);
  }
}
