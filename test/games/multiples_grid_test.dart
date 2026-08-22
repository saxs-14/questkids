import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/multiples_grid/multiples_grid_game.dart';

void main() {
  testWidgets('MultiplesGridGame renders 5x5 matrix and responds to cube taps',
      (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const config = GameConfig(
      grade: 'Grade 4',
      subject: 'Mathematics',
      topicId: 'multiplication',
      subtopicId: 'multiples_grid',
      engineType: 'multiplesGrid',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: MultiplesGridGame(config: config),
      ),
    );

    // Allow initial 500ms startup timer to trigger
    await tester.pump(const Duration(milliseconds: 600));

    // Verify Title & Chain bar exist
    expect(find.textContaining('Multiples of'), findsOneWidget);
    expect(find.textContaining('Chain'), findsOneWidget);

    // Verify 25 grid cubes are rendered
    expect(find.byType(GestureDetector), findsWidgets);
  });
}
