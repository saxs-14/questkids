import 'dart:math';

/// Local, quota-free scripted lines Questy uses to react to gameplay/
/// progress events (badges, level-ups, streaks) so celebration doesn't
/// compete with the shared 50/day Gemini quota used by chat/hints.
class QuestyDialogue {
  static final _random = Random();

  static const _badgeLines = [
    'You earned the {badge} badge! I knew you had it in you! 🌟',
    'Whoa, {badge}! That is such a big achievement — amazing work! 🎉',
    '{badge} unlocked! You should be so proud of yourself! ✨',
  ];

  static const _levelUpLines = [
    'Level {level}! You are growing into a real QuestKids champion! 🚀',
    'Ding! Level {level} reached — your hard work is really paying off! 💫',
    'Look at you go — Level {level} already! Keep it up! 🔥',
  ];

  static const _encourageLines = [
    'Not quite — but every mistake helps your brain grow! Try again! 💪',
    'So close! Take another look and give it one more shot! 🌈',
    'That is okay — even champions get tricky questions wrong sometimes! 🙂',
    'Keep going! You are learning something new with every try! ✨',
  ];

  static const _cheerLines = [
    'Yes! Perfect! You are on fire today! 🔥',
    'Correct! Fantastic thinking! 🌟',
    'Nailed it! Keep that streak going! 🎯',
    'Great job! You really know your stuff! 🎉',
  ];

  static String celebrateBadge(String badgeName) =>
      _badgeLines[_random.nextInt(_badgeLines.length)]
          .replaceAll('{badge}', badgeName);

  static String celebrateLevelUp(int newLevel) =>
      _levelUpLines[_random.nextInt(_levelUpLines.length)]
          .replaceAll('{level}', '$newLevel');

  static String encourageAfterMiss() =>
      _encourageLines[_random.nextInt(_encourageLines.length)];

  static String cheerCorrect() =>
      _cheerLines[_random.nextInt(_cheerLines.length)];
}
