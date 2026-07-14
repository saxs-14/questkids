import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/core/game_router.dart';
import 'package:questkids/features/games/number_counting_duel/number_counting_duel_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  testWidgets('GameRouter passes config through to NumberCountingDuelGame',
      (tester) async {
    const config = GameConfig(
      engineType: 'numberCountingDuel',
      subject: 'Mathematics',
      grade: 'grade1',
      topicId: 'numbers',
      subtopicId: 'counting',
      catalogId: 'math_g1_counting',
    );
    await tester.pumpWidget(const MaterialApp(
      home: GameRouter(config: config, user: null),
    ));
    expect(find.byType(NumberCountingDuelGame), findsOneWidget);
    final widget = tester
        .widget<NumberCountingDuelGame>(find.byType(NumberCountingDuelGame));
    expect(widget.config.catalogId, 'math_g1_counting');
  });
}
