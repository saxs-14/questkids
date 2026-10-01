import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:uuid/uuid.dart';
import '../models/game_session_model.dart';
import '../models/curriculum_model.dart';
import '../../core/constants/app_constants.dart';

/// Consolidated repository for all game engine data.
/// Replaces fragmented per-engine repository logic.
///
/// Firestore layout:
///   game_sessions/{sessionId}
///   player_stats/{uid}
///   game_progress/{uid}/engines/{engineType}
///   daily_missions/{uid}_{date}
///   caps_curriculum/{grade_subject}
///
/// Leaderboards (leaderboards/{grade}/weekly, leaderboards/{grade}/allTime)
/// are populated server-side only, by the scheduled refreshLeaderboards
/// Cloud Function reading player_stats -- firestore.rules blocks all client
/// writes under leaderboards/{grade} (`allow write: if false`), and there
/// is no rule at all for a leaderboards/{grade}/entries subcollection, so a
/// client write there can never succeed. See LeaderboardRepository for the
/// read side.
class GameRepository {
  final _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // ── Session logging ──────────────────────────────────────────────────────────

  /// Logs a completed game session and fans out to all derived collections.
  /// Returns the session ID.
  /// Records a game session through the protected server-side callable.
  /// The client never writes score, XP, coins, player stats, rewards or
  /// level progression directly. This prevents tampering with game results.
  Future<String> logGameSession(GameSessionModel session) async {
    final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable('recordGameSession');
    final response = await callable.call({
      'id': session.id.isNotEmpty ? session.id : _uuid.v4(),
      ...session.toMap(),
      'metadata': session.metadata,
      'catalogId': session.metadata['catalogId'],
    });
    final data = Map<String, dynamic>.from(response.data as Map);
    return data['sessionId'] as String;
  }

  // ── Player stats ─────────────────────────────────────────────────────────────

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

  String _todayKey() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
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
