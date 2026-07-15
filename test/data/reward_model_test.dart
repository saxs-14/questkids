import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/core/constants/trading_post_catalog.dart';
import 'package:questkids/data/models/reward_model.dart';

void main() {
  group('RewardModel wallet fields', () {
    test('toMap/fromMap round-trips goldBalance, ownedItemIds, equippedItemId', () {
      final model = RewardModel(
        uid: 'u1',
        lastActiveDate: DateTime(2026, 1, 1),
        goldBalance: 120,
        ownedItemIds: const [
          TradingPostCatalog.starterItemId,
          'forest_ranger',
        ],
        equippedItemId: 'forest_ranger',
      );

      final restored = RewardModel.fromMap(model.toMap());

      expect(restored.goldBalance, 120);
      expect(restored.ownedItemIds,
          [TradingPostCatalog.starterItemId, 'forest_ranger']);
      expect(restored.equippedItemId, 'forest_ranger');
    });

    test('fromMap defaults a pre-migration doc missing the new fields', () {
      // Simulates a rewards/{uid} doc written before this wallet feature
      // existed -- goldBalance/ownedItemIds/equippedItemId never wrote.
      final restored = RewardModel.fromMap({
        'uid': 'u1',
        'totalPoints': 50,
        'level': 1,
        'lastActiveDate': DateTime(2026, 1, 1).millisecondsSinceEpoch,
      });

      expect(restored.goldBalance, 0);
      expect(restored.ownedItemIds, [TradingPostCatalog.starterItemId]);
      expect(restored.equippedItemId, TradingPostCatalog.starterItemId);
    });
  });

  group('TradingPostCatalog', () {
    test('byId finds the matching item', () {
      final item = TradingPostCatalog.byId('forest_ranger');
      expect(item.id, 'forest_ranger');
      expect(item.skin?.helmetColor, isNotNull);
    });

    test('byId falls back to the first item for an unknown id', () {
      final item = TradingPostCatalog.byId('does_not_exist');
      expect(item.id, TradingPostCatalog.items.first.id);
    });

    test('the starter item is free and has no skin overrides', () {
      final starter =
          TradingPostCatalog.byId(TradingPostCatalog.starterItemId);
      expect(starter.priceGold, 0);
      expect(starter.skin, isNull);
    });
  });
}
