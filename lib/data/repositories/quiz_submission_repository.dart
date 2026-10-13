import 'package:cloud_functions/cloud_functions.dart';

class QuizSubmissionRepository {
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<void> submit({
    required String submissionId,
    required String activityId,
    required List<String> answers,
    required int timeTakenSeconds,
  }) async {
    final callable = _functions.httpsCallable('submitQuizResult');
    await callable.call({
      'submissionId': submissionId,
      'activityId': activityId,
      'answers': answers,
      'timeTakenSeconds': timeTakenSeconds,
    });
  }
}
