import 'package:flutter/material.dart';
import '../data/models/reward_model.dart';
import '../data/models/progress_model.dart';
import '../data/repositories/reward_repository.dart';
import '../data/repositories/progress_repository.dart';
import '../core/constants/trading_post_catalog.dart';
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
  int? _previousLevel;
  int? _leveledUpTo;

  RewardModel? get rewards => _rewards;
  List<ProgressModel> get progressHistory => _progressHistory;
  List<BadgeModel> get newlyEarnedBadges => _newlyEarnedBadges;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Non-null immediately after a level increase is detected by
  /// [loadRewards]/[watchRewards]; call [clearLevelUp] once it's been
  /// celebrated so it doesn't re-trigger on the next rebuild.
  int? get leveledUpTo => _leveledUpTo;

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

  int get goldBalance => _rewards?.goldBalance ?? 0;
  List<String> get ownedItemIds =>
      _rewards?.ownedItemIds ?? const [TradingPostCatalog.starterItemId];
  String get equippedItemId =>
      _rewards?.equippedItemId ?? TradingPostCatalog.starterItemId;

  String? _walletError;
  String? get walletError => _walletError;

  void clearWalletError() {
    _walletError = null;
    notifyListeners();
  }

  /// Attempts to buy [item] with the learner's current Gold balance.
  /// Returns true on success. On failure, sets [walletError] to a
  /// friendly message (insufficient Gold, already owned, etc.) and
  /// returns false -- the balance is left untouched either way, since
  /// the deduction only happens inside RewardRepository's transaction.
  Future<bool> purchaseItem(String uid, TradingPostItem item) async {
    _walletError = null;
    try {
      await _rewardRepo.purchaseItem(uid, item.id, item.priceGold);
      _rewards = await _rewardRepo.getRewards(uid);
      notifyListeners();
      return true;
    } catch (e) {
      _walletError =
          e is StateError ? e.message : 'Something went wrong. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<void> equipItem(String uid, String itemId) async {
    await _rewardRepo.equipItem(uid, itemId);
    _rewards = await _rewardRepo.getRewards(uid);
    notifyListeners();
  }

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
      _detectLevelUp();
    } catch (e) {
      _errorMessage = 'Failed to load rewards.';
    }
    _isLoading = false;
    notifyListeners();
  }

  void watchRewards(String uid) {
    _rewardRepo.watchRewards(uid).listen((r) {
      _rewards = r;
      _detectLevelUp();
      notifyListeners();
    });
    _progressRepo.watchUserProgress(uid).listen((p) {
      _progressHistory = p;
      notifyListeners();
    });
  }

  /// Compares the newly-loaded [level] against the last known level and
  /// records a level-up, skipping the very first load (there's no
  /// "previous" level to compare against yet).
  void _detectLevelUp() {
    if (_previousLevel != null && level > _previousLevel!) {
      _leveledUpTo = level;
    }
    _previousLevel = level;
  }

  void clearLevelUp() {
    _leveledUpTo = null;
    notifyListeners();
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
