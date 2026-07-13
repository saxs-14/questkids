import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/games/core/game_session_persistence.dart';

void main() {
  group('shouldQueueGameSessionOffline', () {
    test('queues when device reports offline', () {
      expect(
        shouldQueueGameSessionOffline(isOnline: false, writeSucceeded: false),
        isTrue,
      );
    });

    test('does not queue when the Firestore write already succeeded', () {
      expect(
        shouldQueueGameSessionOffline(isOnline: true, writeSucceeded: true),
        isFalse,
      );
    });

    test('queues when online but the write still failed', () {
      expect(
        shouldQueueGameSessionOffline(isOnline: true, writeSucceeded: false),
        isTrue,
      );
    });
  });
}
