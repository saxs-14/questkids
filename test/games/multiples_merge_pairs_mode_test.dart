import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/multiples_merge/multiples_merge_config.dart';
import 'package:questkids/features/games/multiples_merge/multiples_merge_engine.dart';

void main() {
  group('MultiplesMergeConfig.fromPack pairs mode', () {
    test('a pairs-mode pack is no longer discarded into the numeric demo', () {
      const config = GameConfig(
        engineType: 'multiplesMerge',
        subject: 'English',
        grade: 'grade4',
      );
      final pack = {
        'mode': 'pairs',
        'gridSize': 4,
        'chainLength': 2,
        'tokenGroups': [
          ['break the ice', 'do something to relax people'],
          ['piece of cake', 'something very easy'],
        ],
      };
      final merged = MultiplesMergeConfig.fromPack(pack, config);
      expect(merged.mode, 'pairs');
      expect(merged.gridSize, 4);
      expect(merged.tokenGroups, hasLength(2));
      expect(merged.tokenGroups.first,
          ['break the ice', 'do something to relax people']);
    });

    test('a numeric-mode pack still builds as before', () {
      const config = GameConfig(
        engineType: 'multiplesMerge',
        subject: 'Mathematics',
        grade: 'grade4',
      );
      final pack = {
        'mode': 'numeric',
        'gridSize': 5,
        'chainLength': 5,
        'tables': [3, 4, 6, 8],
      };
      final merged = MultiplesMergeConfig.fromPack(pack, config);
      expect(merged.mode, 'numeric');
      expect(merged.tables, [3, 4, 6, 8]);
      expect(merged.tokenGroups, isEmpty);
    });
  });

  group('MultiplesMergeEngine pairs-mode rounds', () {
    test('buildRound in pairs mode places exactly one term/definition pair adjacently', () {
      const mergeConfig = MultiplesMergeConfig(
        mode: 'pairs',
        gridSize: 4,
        chainLength: 2,
        hintLevel: 1,
        tokenGroups: [
          ['break the ice', 'do something to relax people'],
          ['piece of cake', 'something very easy'],
          ['hit the books', 'study hard'],
          ['under the weather', 'feeling unwell'],
        ],
      );
      final engine = MultiplesMergeEngine(
        mergeConfig: mergeConfig,
        config: const GameConfig(
            engineType: 'multiplesMerge', subject: 'English', grade: 'grade4'),
      );

      final round = engine.buildRound();

      expect(round.mode, 'pairs');
      expect(round.values, hasLength(16)); // 4×4
      expect(round.values.every((v) => v is String), isTrue);
      expect(round.pairPartner, isNotNull);
      // Every entry in pairPartner must be a mutual, valid mapping.
      round.pairPartner!.forEach((cell, partner) {
        expect(round.pairPartner![partner], cell);
        expect(
          MultiplesMergeEngine.areAdjacent8(round.gridSize, cell, partner),
          isTrue,
        );
      });
      // Exactly one pair (2 cells) should be mapped as the round's target.
      expect(round.pairPartner!.length, 2);
      // The two mapped cells' values must be the one matching term/definition pair.
      final cells = round.pairPartner!.keys.toList();
      final texts = cells.map((c) => round.values[c] as String).toSet();
      final matchesAGroup = mergeConfig.tokenGroups.any(
        (g) => texts.containsAll(g) && g.toSet().containsAll(texts),
      );
      expect(matchesAGroup, isTrue);
    });

    test('distractor cells never form a second complete pair', () {
      const mergeConfig = MultiplesMergeConfig(
        mode: 'pairs',
        gridSize: 4,
        chainLength: 2,
        hintLevel: 1,
        tokenGroups: [
          ['break the ice', 'do something to relax people'],
          ['piece of cake', 'something very easy'],
          ['hit the books', 'study hard'],
          ['under the weather', 'feeling unwell'],
          ['spill the beans', 'reveal a secret'],
        ],
      );
      final engine = MultiplesMergeEngine(
        mergeConfig: mergeConfig,
        config: const GameConfig(
            engineType: 'multiplesMerge', subject: 'English', grade: 'grade4'),
      );

      for (int i = 0; i < 30; i++) {
        final round = engine.buildRound();
        final targetCells = round.pairPartner!.keys.toSet();
        final otherTexts = [
          for (int c = 0; c < round.values.length; c++)
            if (!targetCells.contains(c)) round.values[c] as String
        ];
        for (final group in mergeConfig.tokenGroups) {
          final bothPresent =
              otherTexts.contains(group[0]) && otherTexts.contains(group[1]);
          expect(bothPresent, isFalse,
              reason: 'distractors must never contain both halves of a pair');
        }
      }
    });
  });
}
