import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/data/models/notification_model.dart';

void main() {
  test('fromMap handles a Firestore Timestamp for createdAt without throwing', () {
    final ts = Timestamp.fromMillisecondsSinceEpoch(1700000000000);
    final map = {
      'title': 'Badge earned',
      'body': 'You earned Math Wizard!',
      'type': 'achievement',
      'recipientUid': 'uid123',
      'isRead': false,
      'createdAt': ts,
    };
    final model = NotificationModel.fromMap(map, 'notif1');
    expect(model.createdAt, ts.toDate());
    expect(model.recipientUid, 'uid123');
  });

  test('fromMap still handles a legacy int millisecondsSinceEpoch', () {
    final map = {
      'title': 'Welcome',
      'body': 'Hi!',
      'type': 'welcome',
      'recipientUid': 'uid123',
      'createdAt': 1700000000000,
    };
    final model = NotificationModel.fromMap(map, 'notif2');
    expect(model.createdAt, DateTime.fromMillisecondsSinceEpoch(1700000000000));
  });
}
