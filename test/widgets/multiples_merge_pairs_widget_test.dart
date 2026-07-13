import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:questkids/features/games/core/game_config.dart';
import 'package:questkids/features/games/multiples_merge/multiples_merge_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  testWidgets('a pairs-mode round renders string tokens, not numbers',
      (tester) async {
    const config = GameConfig(
      engineType: 'multiplesMerge',
      subject: 'English',
      grade: 'grade4',
      catalogId: 'eng_g4_idioms',
    );
    final session = MultiplesMergeSession(config, 'test-uid', pack: {
      'mode': 'pairs',
      'gridSize': 4,
      'chainLength': 2,
      'tokenGroups': [
        ['break the ice', 'do something to relax people'],
        ['piece of cake', 'something very easy'],
        ['hit the books', 'study hard'],
        ['under the weather', 'feeling unwell'],
      ],
    })
      ..startSession();

    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider.value(
        value: session,
        child: Consumer<MultiplesMergeSession>(
          builder: (_, s, __) => Text(s.round!.values.join(', ')),
        ),
      ),
    ));

    // The rendered text must contain at least one of the authored token
    // strings, proving the widget layer can hold and display non-numeric
    // round values without a type error.
    final text = tester.widget<Text>(find.byType(Text)).data!;
    final anyToken = [
      'break the ice',
      'do something to relax people',
      'piece of cake',
      'something very easy',
      'hit the books',
      'study hard',
      'under the weather',
      'feeling unwell',
    ].any(text.contains);
    expect(anyToken, isTrue);

    session.dispose();
  });
}
