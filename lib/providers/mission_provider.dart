import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/models/daily_mission_model.dart';
import '../data/repositories/mission_repository.dart';

class MissionProvider extends ChangeNotifier {
  final _repo = MissionRepository();
  StreamSubscription<List<DailyMission>>? _sub;

  List<DailyMission> _missions = [];
  List<DailyMission> get missions => _missions;

  int get completedCount => _missions.where((m) => m.completed).length;
  int get totalCount => _missions.length;
  bool get allComplete => totalCount > 0 && completedCount == totalCount;

  void watchMissions(String uid) {
    _sub?.cancel();
    _sub = _repo.watchTodayMissions(uid).listen((list) {
      _missions = list;
      notifyListeners();
    });
  }

  Future<void> completeMission(
      String uid, String missionId, String gameId) async {
    await _repo.completeMission(uid, missionId, gameId);
    _missions = _missions.map((m) {
      if (m.id == missionId) {
        return DailyMission(
          id: m.id,
          gameId: m.gameId,
          title: m.title,
          subject: m.subject,
          emoji: m.emoji,
          xpBonus: m.xpBonus,
          completed: true,
          completedAt: DateTime.now(),
          source: m.source,
        );
      }
      return m;
    }).toList();
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
