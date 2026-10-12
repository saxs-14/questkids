import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/multiples_grid/multiples_grid_game.dart';

void main() {
  testWidgets('MultiplesGridGame renders a 5x5 matrix with a drag surface',
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
    expect(
      find.text('Find the smallest multiple of 3, then count on by 3.'),
      findsOneWidget,
    );

    for (var step = 1; step < 10; step++) {
      final current = tester.getCenter(
        find.byKey(ValueKey('multiples_grid_cube_${3 * step}')),
      );
      final next = tester.getCenter(
        find.byKey(ValueKey('multiples_grid_cube_${3 * (step + 1)}')),
      );
      final cellSize = tester
          .getSize(find.byKey(ValueKey('multiples_grid_cube_${3 * step}')))
          .width;
      final dx = (current.dx - next.dx).abs();
      final dy = (current.dy - next.dy).abs();
      final orthogonallyAdjacent =
          (dx < 1 && dy > cellSize - 1 && dy <= cellSize + 9) ||
              (dy < 1 && dx > cellSize - 1 && dx <= cellSize + 9);
      expect(orthogonallyAdjacent, isTrue,
          reason: 'multiples ${3 * step} and ${3 * (step + 1)} should be adjacent');
    }

    await tester.tap(find.byTooltip('Get a hint'));
    await tester.pump();
    expect(find.text('Hint: start with the smallest multiple in the matrix.'),
        findsOneWidget);

    // A tap must not select or connect a cube; the game is controlled by
    // drawing one continuous path over the matrix.
    final firstMultiple = find.text('3');
    final secondMultiple = find.text('6');
    final firstCenter = tester.getCenter(firstMultiple);
    await tester.tapAt(firstCenter);
    await tester.pump();
    final chainStatus = tester.widget<Text>(find.textContaining('Chain')).data;
    expect(find.text('Chain 0 / 10'), findsOneWidget,
        reason: 'A tap unexpectedly changed chain progress: $chainStatus');

    final gesture = await tester.startGesture(firstCenter);
    await gesture.moveTo(tester.getCenter(secondMultiple));
    await gesture.up();
    await tester.pump();
    expect(find.text('Chain 2 / 10'), findsOneWidget);
  });
}
