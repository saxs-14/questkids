import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/data/models/activity_model.dart';
import 'package:questkids/data/models/chat_message_model.dart';
import 'package:questkids/data/models/conversation_model.dart';
import 'package:questkids/data/models/game_session_model.dart';
import 'package:questkids/data/models/progress_model.dart';
import 'package:questkids/data/models/reward_model.dart';
import 'package:questkids/data/models/thread_message_model.dart';

void main() {
  group('Data Model Date & Numeric Resiliency Tests', () {
    test('ProgressModel.fromMap parses Timestamp, num, and null without error', () {
      final nowTs = Timestamp.now();

      final fromTs = ProgressModel.fromMap({
        'uid': 'u1',
        'activityId': 'a1',
        'activityTitle': 'Title',
        'subject': 'Maths',
        'score': 90.0,
        'pointsEarned': 100,
        'completedAt': nowTs,
      });
      expect(fromTs.score, equals(90));
      expect(fromTs.completedAt, equals(nowTs.toDate()));

      final fromMillis = ProgressModel.fromMap({
        'uid': 'u1',
        'activityId': 'a1',
        'completedAt': 1700000000000,
      });
      expect(fromMillis.completedAt, equals(DateTime.fromMillisecondsSinceEpoch(1700000000000)));

      final fromNull = ProgressModel.fromMap({'uid': 'u1'});
      expect(fromNull.completedAt, isA<DateTime>());
    });

    test('RewardModel.fromMap parses Timestamp, num, and null for dates and numbers', () {
      final nowTs = Timestamp.now();
      final model = RewardModel.fromMap({
        'uid': 'u1',
        'totalPoints': 150.0,
        'level': 2.0,
        'streakDays': 5.0,
        'lastActiveDate': nowTs,
        'goldBalance': 50.0,
        'badges': [
          {
            'id': 'b1',
            'name': 'Badge',
            'earnedAt': nowTs,
          }
        ],
        'achievements': [
          {
            'id': 'ac1',
            'title': 'Ach',
            'pointsAwarded': 20.0,
            'unlockedAt': 1700000000000,
          }
        ]
      });

      expect(model.totalPoints, equals(150));
      expect(model.level, equals(2));
      expect(model.streakDays, equals(5));
      expect(model.goldBalance, equals(50));
      expect(model.lastActiveDate, equals(nowTs.toDate()));
      expect(model.badges.first.earnedAt, equals(nowTs.toDate()));
      expect(model.achievements.first.pointsAwarded, equals(20));
      expect(model.achievements.first.unlockedAt, equals(DateTime.fromMillisecondsSinceEpoch(1700000000000)));
    });

    test('ChatMessageModel.fromMap handles Timestamp and int millis', () {
      final nowTs = Timestamp.now();
      final modelTs = ChatMessageModel.fromMap({'text': 'hello', 'timestamp': nowTs}, 'm1');
      expect(modelTs.timestamp, equals(nowTs.toDate()));

      final modelMillis = ChatMessageModel.fromMap({'text': 'hello', 'timestamp': 1700000000000}, 'm2');
      expect(modelMillis.timestamp, equals(DateTime.fromMillisecondsSinceEpoch(1700000000000)));
    });

    test('ActivityModel.fromMap handles Timestamp, num, and null', () {
      final nowTs = Timestamp.now();
      final model = ActivityModel.fromMap({
        'title': 'Act 1',
        'rewardPoints': 25.0,
        'createdAt': nowTs,
      }, 'act1');

      expect(model.rewardPoints, equals(25));
      expect(model.createdAt, equals(nowTs.toDate()));
    });

    test('GameSessionModel.fromMap handles Timestamp, num, and null', () {
      final nowTs = Timestamp.now();
      final modelTs = GameSessionModel.fromMap('s1', {
        'uid': 'u1',
        'grade': 'grade4',
        'subject': 'Mathematics',
        'engineType': 'tugOfWar',
        'score': 100.0,
        'xpEarned': 50.0,
        'coinsEarned': 10.0,
        'accuracy': 1,
        'timeTakenSeconds': 60.0,
        'completedAt': nowTs,
        'result': 'win',
      });
      expect(modelTs.completedAt, equals(nowTs.toDate()));

      final model = GameSessionModel.fromMap('s2', {
        'uid': 'u1',
        'grade': 'grade4',
        'subject': 'Mathematics',
        'engineType': 'tugOfWar',
        'score': 100.0,
        'xpEarned': 50.0,
        'coinsEarned': 10.0,
        'accuracy': 1,
        'timeTakenSeconds': 60.0,
        'completedAt': 1700000000000,
        'result': 'win',
      });

      expect(model.score, equals(100));
      expect(model.xpEarned, equals(50));
      expect(model.coinsEarned, equals(10));
      expect(model.accuracy, equals(1.0));
      expect(model.completedAt, equals(DateTime.fromMillisecondsSinceEpoch(1700000000000)));
    });

    test('ConversationModel and ThreadMessageModel handle date formats safely', () {
      final nowTs = Timestamp.now();
      final convo = ConversationModel.fromMap({
        'teacherUid': 't1',
        'parentUid': 'p1',
        'childUid': 'c1',
        'lastMessageAt': nowTs,
        'createdAt': 1700000000000,
      }, 'c_id');

      expect(convo.lastMessageAt, equals(nowTs.toDate()));
      expect(convo.createdAt, equals(DateTime.fromMillisecondsSinceEpoch(1700000000000)));

      final msg = ThreadMessageModel.fromMap({
        'senderUid': 's1',
        'senderRole': 'teacher',
        'text': 'Hi',
        'sentAt': nowTs,
      }, 'm_id');

      expect(msg.sentAt, equals(nowTs.toDate()));
    });
  });
}
