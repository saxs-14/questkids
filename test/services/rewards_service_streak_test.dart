import 'package:flutter_test/flutter_test.dart';

// Mirrors RewardsService.updateStreak's day-diff calculation so the
// calendar-date-boundary fix is provable without a Firestore emulator.
int calendarDayDiff(DateTime now, DateTime last) {
  final nowDate = DateTime(now.year, now.month, now.day);
  final lastDate = DateTime(last.year, last.month, last.day);
  return nowDate.difference(lastDate).inDays;
}

void main() {
  test('crossing midnight by a few minutes counts as a new calendar day', () {
    final last = DateTime(2026, 7, 12, 23, 59);
    final now = DateTime(2026, 7, 13, 0, 5);
    expect(calendarDayDiff(now, last), equals(1),
        reason: 'raw Duration.inDays would give 0 here, incorrectly treating this as the same day');
  });

  test('same calendar day at any time of day is diff 0', () {
    final last = DateTime(2026, 7, 13, 8, 0);
    final now = DateTime(2026, 7, 13, 23, 0);
    expect(calendarDayDiff(now, last), equals(0));
  });

  test('exactly one calendar day apart is diff 1 regardless of time-of-day drift', () {
    final last = DateTime(2026, 7, 12, 8, 0);
    final now = DateTime(2026, 7, 13, 7, 0); // 23 raw hours later
    expect(calendarDayDiff(now, last), equals(1),
        reason: 'raw Duration.inDays would give 0 here (23h < 24h), incorrectly missing a new day');
  });
}
