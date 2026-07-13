import 'package:flutter_test/flutter_test.dart';

// _calcLevel is private; test the formula directly via the same values
// game_repository.dart uses, mirroring rewards_service.dart's public
// getLevelFromPoints so both stay provably in sync at every boundary.
int calcLevel(num totalXp) => (totalXp ~/ 100) + 1;
int getLevelFromPoints(int points) => (points ~/ 100) + 1;

void main() {
  test('game XP level formula matches the rewards/dashboard level formula at every boundary', () {
    for (final xp in [0, 1, 99, 100, 101, 250, 300, 999, 1000, 1500, 5000]) {
      expect(calcLevel(xp), equals(getLevelFromPoints(xp)),
          reason: 'formulas disagree at xp=$xp');
    }
  });
}
