class CurriculumSubtopic {
  final String id;
  final String name;
  final String recommendedEngine; // matches AppConstants.engine* constant
  final String difficulty;        // 'easy' | 'medium' | 'hard'
  final List<String> keywords;

  const CurriculumSubtopic({
    required this.id,
    required this.name,
    required this.recommendedEngine,
    required this.difficulty,
    this.keywords = const [],
  });

  factory CurriculumSubtopic.fromMap(Map<String, dynamic> map) {
    return CurriculumSubtopic(
      id: map['id'] as String,
      name: map['name'] as String,
      recommendedEngine: map['recommendedEngine'] as String,
      difficulty: map['difficulty'] as String? ?? 'medium',
      keywords: List<String>.from(map['keywords'] as List? ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'recommendedEngine': recommendedEngine,
        'difficulty': difficulty,
        'keywords': keywords,
      };
}

class CurriculumTopic {
  final String id;
  final String name;
  final List<CurriculumSubtopic> subtopics;

  const CurriculumTopic({
    required this.id,
    required this.name,
    required this.subtopics,
  });

  factory CurriculumTopic.fromMap(Map<String, dynamic> map) {
    final rawSubtopics = map['subtopics'] as List? ?? [];
    return CurriculumTopic(
      id: map['id'] as String,
      name: map['name'] as String,
      subtopics: rawSubtopics
          .map((s) =>
              CurriculumSubtopic.fromMap(Map<String, dynamic>.from(s as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'subtopics': subtopics.map((s) => s.toMap()).toList(),
      };
}

class CurriculumModel {
  final String id;      // e.g. 'grade4_mathematics'
  final String grade;   // e.g. 'grade4'
  final String subject; // e.g. 'Mathematics'
  final List<CurriculumTopic> topics;

  const CurriculumModel({
    required this.id,
    required this.grade,
    required this.subject,
    required this.topics,
  });

  factory CurriculumModel.fromMap(String id, Map<String, dynamic> map) {
    final rawTopics = map['topics'] as List? ?? [];
    return CurriculumModel(
      id: id,
      grade: map['grade'] as String,
      subject: map['subject'] as String,
      topics: rawTopics
          .map((t) =>
              CurriculumTopic.fromMap(Map<String, dynamic>.from(t as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'grade': grade,
        'subject': subject,
        'topics': topics.map((t) => t.toMap()).toList(),
      };
}
