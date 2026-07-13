import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/game_session_model.dart';
import '../models/curriculum_model.dart';
import '../models/progress_model.dart';
import '../../core/constants/app_constants.dart';

/// Consolidated repository for all game engine data.
/// Replaces fragmented per-engine repository logic.
///
/// Firestore layout:
///   game_sessions/{sessionId}
///   player_stats/{uid}
///   game_progress/{uid}/engines/{engineType}
///   leaderboards/{grade}/entries/{uid}
///   daily_missions/{uid}_{date}
///   caps_curriculum/{grade_subject}
class GameRepository {
  final _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // ── Session logging ──────────────────────────────────────────────────────────

  /// Logs a completed game session and fans out to all derived collections.
  /// Returns the session ID.
  Future<String> logGameSession(GameSessionModel session) async {
    final id = session.id.isNotEmpty ? session.id : _uuid.v4();

    final batch = _db.batch();

    // game_sessions/{id} — primary record
    batch.set(
      _db.collection(AppConstants.colGameSessions).doc(id),
      {...session.toMap(), 'id': id},
    );

    // progress/{id} — mirrors to parent/teacher visibility
    batch.set(
      _db.collection(AppConstants.colProgress).doc(id),
      _buildProgressMirror(id, session),
    );

    await batch.commit();

    // Fan-out updates: non-critical, run in parallel
    await Future.wait([
      _updatePlayerStats(session),
      _updateGameProgress(session),
      _updateLeaderboard(session),
    ]);

    return id;
  }

  Map<String, dynamic> _buildProgressMirror(String id, GameSessionModel s) {
    return ProgressModel(
      uid: s.uid,
      activityId: id,
      activityTitle: '${s.subject} – ${_engineLabel(s.engineType)}',
      subject: s.subject,
      score: s.score,
      pointsEarned: s.xpEarned,
      completed: s.result == 'win' || s.result == 'complete',
      verified: false,
      proofUrl: null,
      completedAt: s.completedAt,
      timeTakenSeconds: s.timeTakenSeconds,
    ).toMap();
  }

  // ── Player stats ─────────────────────────────────────────────────────────────

  Future<void> _updatePlayerStats(GameSessionModel session) async {
    final ref = _db.collection(AppConstants.colPlayerStats).doc(session.uid);
    final isWin = session.result == 'win' || session.result == 'complete';

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final e = snap.exists
          ? Map<String, dynamic>.from(snap.data()!)
          : <String, dynamic>{};

      final newXp = (e['xp'] as num? ?? 0) + session.xpEarned;

      tx.set(
        ref,
        {
          'uid': session.uid,
          'xp': newXp,
          'coins': (e['coins'] as num? ?? 0) + session.coinsEarned,
          'level': _calcLevel(newXp),
          'gamesPlayed': (e['gamesPlayed'] as num? ?? 0) + 1,
          'wins': (e['wins'] as num? ?? 0) + (isWin ? 1 : 0),
          'losses': (e['losses'] as num? ?? 0) + (isWin ? 0 : 1),
          'favoriteEngine': session.engineType,
          'lastPlayedAt': Timestamp.fromDate(session.completedAt),
          'achievements': e['achievements'] ?? [],
          'unlockedWorlds': e['unlockedWorlds'] ?? [],
        },
        SetOptions(merge: true),
      );
    });
  }

  Stream<Map<String, dynamic>?> watchPlayerStats(String uid) {
    return _db
        .collection(AppConstants.colPlayerStats)
        .doc(uid)
        .snapshots()
        .map((s) => s.data());
  }

  Future<Map<String, dynamic>?> getPlayerStats(String uid) async {
    final snap =
        await _db.collection(AppConstants.colPlayerStats).doc(uid).get();
    return snap.data();
  }

  // ── Per-engine progress ───────────────────────────────────────────────────────

  Future<void> _updateGameProgress(GameSessionModel session) async {
    final ref = _db
        .collection(AppConstants.colGameProgress)
        .doc(session.uid)
        .collection('engines')
        .doc(session.engineType);

    final isWin = session.result == 'win' || session.result == 'complete';

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final e = snap.exists
          ? Map<String, dynamic>.from(snap.data()!)
          : <String, dynamic>{};

      final prevGames = (e['totalGames'] as num? ?? 0).toInt();
      final prevAvg = (e['averageAccuracy'] as num? ?? 0.0).toDouble();
      final newGames = prevGames + 1;
      final newAvg = ((prevAvg * prevGames) + session.accuracy) / newGames;

      final prevBest = (e['bestScore'] as num? ?? 0).toInt();

      tx.set(
        ref,
        {
          'engineType': session.engineType,
          'subject': session.subject,
          'grade': session.grade,
          'totalGames': newGames,
          'wins': (e['wins'] as num? ?? 0) + (isWin ? 1 : 0),
          'losses': (e['losses'] as num? ?? 0) + (isWin ? 0 : 1),
          'bestScore': session.score > prevBest ? session.score : prevBest,
          'totalXP': (e['totalXP'] as num? ?? 0) + session.xpEarned,
          'averageAccuracy': newAvg,
          'lastPlayedAt': Timestamp.fromDate(session.completedAt),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<Map<String, dynamic>?> getGameProgress(
      String uid, String engineType) async {
    final snap = await _db
        .collection(AppConstants.colGameProgress)
        .doc(uid)
        .collection('engines')
        .doc(engineType)
        .get();
    return snap.data();
  }

  // ── Leaderboard ───────────────────────────────────────────────────────────────

  Future<void> _updateLeaderboard(GameSessionModel session) async {
    final entryRef = _db
        .collection(AppConstants.colLeaderboards)
        .doc(session.grade)
        .collection('entries')
        .doc(session.uid);

    final statsSnap = await _db
        .collection(AppConstants.colPlayerStats)
        .doc(session.uid)
        .get();
    final stats = statsSnap.data() ?? {};

    await entryRef.set(
      {
        'uid': session.uid,
        'xp': stats['xp'] ?? 0,
        'level': stats['level'] ?? 1,
        'coins': stats['coins'] ?? 0,
        'updatedAt': Timestamp.fromDate(session.completedAt),
      },
      SetOptions(merge: true),
    );
  }

  Future<List<Map<String, dynamic>>> getLeaderboard(
    String grade, {
    int limit = 20,
  }) async {
    final snap = await _db
        .collection(AppConstants.colLeaderboards)
        .doc(grade)
        .collection('entries')
        .orderBy('xp', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  // ── Daily missions ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getDailyMissions(String uid) async {
    final snap = await _db
        .collection(AppConstants.colDailyMissions)
        .doc('${uid}_${_todayKey()}')
        .get();
    return snap.data();
  }

  Future<void> updateMissionProgress(
    String uid,
    String missionId,
    int progress,
    int target,
  ) async {
    final ref = _db
        .collection(AppConstants.colDailyMissions)
        .doc('${uid}_${_todayKey()}');

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final missions = List<Map<String, dynamic>>.from(
        (snap.data()!['missions'] as List? ?? [])
            .map((m) => Map<String, dynamic>.from(m as Map)),
      );

      for (final m in missions) {
        if (m['id'] == missionId) {
          m['progress'] = progress;
          if (progress >= target) m['completed'] = true;
          break;
        }
      }

      tx.update(ref, {
        'missions': missions,
        'allCompleted': missions.every((m) => m['completed'] == true),
      });
    });
  }

  // ── Curriculum ────────────────────────────────────────────────────────────────

  Future<CurriculumModel?> getCurriculum(String grade, String subject) async {
    final id = '${grade}_${subject.toLowerCase().replaceAll(' ', '_')}';
    final snap =
        await _db.collection(AppConstants.colCapsCurriculum).doc(id).get();
    if (!snap.exists) return null;
    return CurriculumModel.fromMap(id, snap.data()!);
  }

  Future<List<CurriculumModel>> getCurriculumForGrade(String grade) async {
    final snap = await _db
        .collection(AppConstants.colCapsCurriculum)
        .where('grade', isEqualTo: grade)
        .get();
    return snap.docs
        .map((d) => CurriculumModel.fromMap(d.id, d.data()))
        .toList();
  }

  // ── Seed CAPS curriculum ──────────────────────────────────────────────────────

  /// Seeds the caps_curriculum collection with Grade 4 CAPS data.
  /// Safe to call repeatedly — uses merge: true.
  Future<void> seedCapsCurriculum() async {
    final batch = _db.batch();
    for (final model in _grade4Curriculum()) {
      batch.set(
        _db.collection(AppConstants.colCapsCurriculum).doc(model.id),
        model.toMap(),
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  // Matches RewardsService.getLevelFromPoints / RewardRepository.addPoints
  // / the dashboard's level display -- kept as one formula everywhere so
  // player_stats.level and rewards.level never disagree for the same XP.
  int _calcLevel(num totalXp) => (totalXp ~/ 100) + 1;

  String _todayKey() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  String _engineLabel(String engineType) {
    const labels = {
      AppConstants.engineTugOfWar: 'Tug of War',
      AppConstants.engineAdventureJourney: 'Adventure Journey',
      AppConstants.engineRunnerCollector: 'Runner & Collector',
      AppConstants.engineExplorerMap: 'Explorer Map',
    };
    return labels[engineType] ?? engineType;
  }

  // ── Grade 4 CAPS seed data ────────────────────────────────────────────────────

  List<CurriculumModel> _grade4Curriculum() => [
        const CurriculumModel(
          id: 'grade4_mathematics',
          grade: 'grade4',
          subject: 'Mathematics',
          topics: [
            CurriculumTopic(
              id: 'multiplication',
              name: 'Multiplication Tables',
              subtopics: [
                CurriculumSubtopic(
                  id: 'times_1_5',
                  name: 'Times Tables 1–5',
                  recommendedEngine: AppConstants.engineTugOfWar,
                  difficulty: 'easy',
                  keywords: ['multiply', 'times', 'product'],
                ),
                CurriculumSubtopic(
                  id: 'times_6_10',
                  name: 'Times Tables 6–10',
                  recommendedEngine: AppConstants.engineTugOfWar,
                  difficulty: 'medium',
                  keywords: ['multiply', 'times', 'product'],
                ),
                CurriculumSubtopic(
                  id: 'times_11_12',
                  name: 'Times Tables 11–12',
                  recommendedEngine: AppConstants.engineTugOfWar,
                  difficulty: 'hard',
                  keywords: ['multiply', 'times', 'product'],
                ),
              ],
            ),
            CurriculumTopic(
              id: 'place_value',
              name: 'Place Value & Number Sense',
              subtopics: [
                CurriculumSubtopic(
                  id: 'numbers_to_10000',
                  name: 'Numbers to 10 000',
                  recommendedEngine: AppConstants.engineRunnerCollector,
                  difficulty: 'medium',
                  keywords: ['thousands', 'hundreds', 'tens', 'ones'],
                ),
              ],
            ),
          ],
        ),
        const CurriculumModel(
          id: 'grade4_natural_sciences',
          grade: 'grade4',
          subject: 'Natural Sciences',
          topics: [
            CurriculumTopic(
              id: 'water_cycle',
              name: 'The Water Cycle',
              subtopics: [
                CurriculumSubtopic(
                  id: 'evaporation_condensation',
                  name: 'Evaporation & Condensation',
                  recommendedEngine: AppConstants.engineAdventureJourney,
                  difficulty: 'medium',
                  keywords: ['evaporation', 'condensation', 'precipitation'],
                ),
                CurriculumSubtopic(
                  id: 'water_sources',
                  name: 'Water Sources & Conservation',
                  recommendedEngine: AppConstants.engineAdventureJourney,
                  difficulty: 'easy',
                  keywords: ['river', 'dam', 'groundwater', 'conservation'],
                ),
              ],
            ),
          ],
        ),
        const CurriculumModel(
          id: 'grade4_english',
          grade: 'grade4',
          subject: 'English',
          topics: [
            CurriculumTopic(
              id: 'grammar',
              name: 'Grammar & Language Use',
              subtopics: [
                CurriculumSubtopic(
                  id: 'nouns_verbs_adjectives',
                  name: 'Nouns, Verbs & Adjectives',
                  recommendedEngine: AppConstants.engineRunnerCollector,
                  difficulty: 'easy',
                  keywords: ['noun', 'verb', 'adjective', 'parts of speech'],
                ),
                CurriculumSubtopic(
                  id: 'tenses',
                  name: 'Past, Present & Future Tense',
                  recommendedEngine: AppConstants.engineRunnerCollector,
                  difficulty: 'medium',
                  keywords: ['tense', 'past', 'present', 'future'],
                ),
              ],
            ),
          ],
        ),
        const CurriculumModel(
          id: 'grade4_social_sciences',
          grade: 'grade4',
          subject: 'Social Sciences',
          topics: [
            CurriculumTopic(
              id: 'geography_sa',
              name: 'South African Geography',
              subtopics: [
                CurriculumSubtopic(
                  id: 'provinces',
                  name: 'Nine Provinces of South Africa',
                  recommendedEngine: AppConstants.engineExplorerMap,
                  difficulty: 'medium',
                  keywords: ['province', 'capital', 'Gauteng', 'Western Cape'],
                ),
                CurriculumSubtopic(
                  id: 'landforms',
                  name: 'Landforms & Physical Features',
                  recommendedEngine: AppConstants.engineExplorerMap,
                  difficulty: 'medium',
                  keywords: [
                    'mountain',
                    'plateau',
                    'escarpment',
                    'Drakensberg'
                  ],
                ),
              ],
            ),
          ],
        ),
      ];
}
