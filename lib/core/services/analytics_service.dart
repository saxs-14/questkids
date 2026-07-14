import 'package:firebase_analytics/firebase_analytics.dart';

/// Thin wrapper around FirebaseAnalytics so call sites never touch the
/// FirebaseAnalytics singleton directly -- keeps event names and
/// parameter shapes centralized in one file as the event set grows.
class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Attached to MaterialApp.navigatorObservers for automatic screen-view
  /// tracking -- no per-screen instrumentation needed.
  static FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  static Future<void> logSignUp(String role) =>
      _analytics.logSignUp(signUpMethod: role);

  static Future<void> logLogin(String role) =>
      _analytics.logLogin(loginMethod: role);

  static Future<void> logGameComplete({
    required String engineType,
    required String subject,
    required int score,
  }) =>
      _analytics.logEvent(name: 'game_session_complete', parameters: {
        'engine_type': engineType,
        'subject': subject,
        'score': score,
      });

  static Future<void> logQuestComplete(String catalogId) =>
      _analytics.logEvent(
          name: 'quest_complete', parameters: {'catalog_id': catalogId});
}
