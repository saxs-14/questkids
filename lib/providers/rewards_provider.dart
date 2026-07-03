import 'package:flutter/material.dart';
import '../data/models/reward_model.dart';
import '../data/models/progress_model.dart';
import '../data/repositories/reward_repository.dart';
import '../data/repositories/progress_repository.dart';
import '../core/services/rewards_service.dart';

class RewardsProvider extends ChangeNotifier {
  final RewardRepository _rewardRepo = RewardRepository();
  final ProgressRepository _progressRepo = ProgressRepository();
  final RewardsService _rewardsService = RewardsService();

  RewardModel? _rewards;
  List<ProgressModel> _progressHistory = [];
  List<BadgeModel> _newlyEarnedBadges = [];
  bool _isLoading = false;
  String? _errorMessage;

  RewardModel? get rewards => _rewards;
  List<ProgressModel> get progressHistory => _progressHistory;
  List<BadgeModel> get newlyEarnedBadges => _newlyEarnedBadges;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get totalPoints => _rewards?.totalPoints ?? 0;
  int get level => _rewards?.level ?? 1;
  int get streakDays => _rewards?.streakDays ?? 0;
  List<BadgeModel> get badges => _rewards?.badges ?? [];
  List<AchievementModel> get achievements => _rewards?.achievements ?? [];

  double get levelProgress => RewardsService.getLevelProgress(totalPoints);
  String get levelTitle => RewardsService.getLevelTitle(level);
  String get levelEmoji => RewardsService.getLevelEmoji(level);

  int get questsCompleted => _progressHistory.where((p) => p.completed).length;
  int get perfectScores => _progressHistory.where((p) => p.score == 100).length;

  Map<String, int> get subjectCounts {
    final counts = <String, int>{};
    for (final p in _progressHistory.where((p) => p.completed)) {
      counts[p.subject] = (counts[p.subject] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> loadRewards(String uid) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _rewards = await _rewardRepo.getRewards(uid);
      _progressHistory = await _progressRepo.getUserProgress(uid);
      await _rewardsService.updateStreak(uid);
      _rewards = await _rewardRepo.getRewards(uid);
    } catch (e) {
      _errorMessage = 'Failed to load rewards.';
    }
    _isLoading = false;
    notifyListeners();
  }

  void watchRewards(String uid) {
    _rewardRepo.watchRewards(uid).listen((r) {
      _rewards = r;
      notifyListeners();
    });
    _progressRepo.watchUserProgress(uid).listen((p) {
      _progressHistory = p;
      notifyListeners();
    });
  }

  Future<void> checkForNewBadges({
    required String uid,
    int lastQuizTimeSeconds = 0,
  }) async {
    _newlyEarnedBadges = await _rewardsService.checkAndAwardBadges(
      uid: uid,
      totalPoints: totalPoints,
      level: level,
      streakDays: streakDays,
      questsCompleted: questsCompleted,
      perfectScores: perfectScores,
      subjectCounts: subjectCounts,
      lastQuizTimeSeconds: lastQuizTimeSeconds,
    );
    if (_newlyEarnedBadges.isNotEmpty) {
      _rewards = await _rewardRepo.getRewards(uid);
      notifyListeners();
    }
  }

  void clearNewBadges() {
    _newlyEarnedBadges = [];
    notifyListeners();
  }
}
