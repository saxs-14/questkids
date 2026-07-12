import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/data/models/chat_message_model.dart';

void main() {
  test('ChatMessageModel round-trips the intent field', () {
    final msg = ChatMessageModel.bot('Try counting on your fingers!', intent: 'hint');
    final map = msg.toMap();
    expect(map['intent'], 'hint');

    final restored = ChatMessageModel.fromMap(map, msg.id);
    expect(restored.intent, 'hint');
  });

  test('ChatMessageModel.fromMap defaults intent to null for legacy documents', () {
    final legacyMap = {
      'text': 'Hi!',
      'isUser': false,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    final restored = ChatMessageModel.fromMap(legacyMap, 'legacy-id');
    expect(restored.intent, isNull);
  });
}
