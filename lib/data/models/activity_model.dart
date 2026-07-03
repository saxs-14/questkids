class ActivityModel {
  final String id;
  final String title;
  final String description;
  final String subject; // Math, Science, English, Social Sciences
  final String type; // quiz, practical, responsibility
  final String difficulty; // easy, medium, hard
  final int rewardPoints;
  final String grade;
  final List<QuestionModel> questions;
  final bool requiresProof;
  final DateTime createdAt;

  ActivityModel({
    required this.id,
    required this.title,
    required this.description,
    required this.subject,
    required this.type,
    required this.difficulty,
    required this.rewardPoints,
    required this.grade,
    this.questions = const [],
    this.requiresProof = false,
    required this.createdAt,
  });

  factory ActivityModel.fromMap(Map<String, dynamic> map, String id) {
    return ActivityModel(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      subject: map['subject'] ?? '',
      type: map['type'] ?? 'quiz',
      difficulty: map['difficulty'] ?? 'easy',
      rewardPoints: map['rewardPoints'] ?? 10,
      grade: map['grade'] ?? 'Grade 1',
      questions: (map['questions'] as List<dynamic>? ?? [])
          .map((q) => QuestionModel.fromMap(q))
          .toList(),
      requiresProof: map['requiresProof'] ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'subject': subject,
      'type': type,
      'difficulty': difficulty,
      'rewardPoints': rewardPoints,
      'grade': grade,
      'questions': questions.map((q) => q.toMap()).toList(),
      'requiresProof': requiresProof,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}

class QuestionModel {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String? explanation;
  final String? imageUrl;

  QuestionModel({
    required this.question,
    required this.options,
    required this.correctIndex,
    this.explanation,
    this.imageUrl,
  });

  factory QuestionModel.fromMap(Map<String, dynamic> map) {
    return QuestionModel(
      question: map['question'] ?? '',
      options: List<String>.from(map['options'] ?? []),
      correctIndex: map['correctIndex'] ?? 0,
      explanation: map['explanation'],
      imageUrl: map['imageUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'options': options,
      'correctIndex': correctIndex,
      'explanation': explanation,
      'imageUrl': imageUrl,
    };
  }
}
