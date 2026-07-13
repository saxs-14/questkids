import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/multiples_merge/multiples_merge_config.dart';

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
}
