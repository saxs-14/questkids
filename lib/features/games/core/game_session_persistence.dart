import '../../../core/services/analytics_service.dart';
import '../../../core/services/offline_service.dart';
import '../../../core/services/rewards_service.dart';
import '../../../data/models/game_session_model.dart';
import '../../../data/repositories/game_repository.dart';

/// A session should be queued to the local pending-sync table whenever
/// the Firestore write did not succeed, regardless of why (device is
/// offline, or the write threw for some other transient reason).
///
/// [isOnline] is accepted for readability at call sites even though the
/// logic collapses to `!writeSucceeded` -- a failed write must always be
/// queued whether or not the device *currently* reports online, since a
/// reported-online write can still fail (a Firestore permission hiccup,
/// or a captive-portal wifi false positive from connectivity_plus).
bool shouldQueueGameSessionOffline({
  required bool isOnline,
  required bool writeSucceeded,
}) =>
    !writeSucceeded;

/// Logs a completed [session] to Firestore, records analytics, grants
/// rewards, and falls back to the offline queue on failure. Shared by
/// [GameSessionState.finishSession] and any self-contained game widget
/// that doesn't go through the GameEngine/GameSessionState architecture
/// (currently only NumberCountingDuelGame) -- both need identical
/// online/offline/rewards handling, so this is the one place it lives.
Future<void> persistGameSession(GameSessionModel session) async {
  final offlineService = OfflineService();
  final online = await offlineService.isOnline();
  var writeSucceeded = false;
  if (online) {
    try {
      await GameRepository().logGameSession(session);
      writeSucceeded = true;
      try {
        await AnalyticsService.logGameComplete(
          engineType: session.engineType,
          subject: session.subject,
          score: session.score,
        );
      } catch (_) {
        // Non-fatal: analytics failures must never affect gameplay.
      }
      try {
        await RewardsService().grantGameSessionRewards(session);
      } catch (_) {
        // Non-fatal: the session itself is already saved; a failure
        // here just means this session's XP won't show on the
        // Rewards screen/dashboard until the next successful grant.
      }
    } catch (_) {
      writeSucceeded = false;
    }
  }
  if (shouldQueueGameSessionOffline(
      isOnline: online, writeSucceeded: writeSucceeded)) {
    await offlineService.saveGameSessionOffline(session);
  }
}
