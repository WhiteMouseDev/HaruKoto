class LevelProgressData {
  final ProgressCategory vocabulary;
  final ProgressCategory grammar;

  const LevelProgressData({required this.vocabulary, required this.grammar});

  factory LevelProgressData.fromJson(Map<String, dynamic> json) {
    return LevelProgressData(
      vocabulary: ProgressCategory.fromJson(
        json['vocabulary'] as Map<String, dynamic>? ?? {},
      ),
      grammar: ProgressCategory.fromJson(
        json['grammar'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

class JlptLevelProgress {
  final String level;
  final ProgressCategory vocabulary;
  final ProgressCategory grammar;

  const JlptLevelProgress({
    required this.level,
    required this.vocabulary,
    required this.grammar,
  });

  factory JlptLevelProgress.fromJson(Map<String, dynamic> json) {
    return JlptLevelProgress(
      level: json['level'] as String? ?? '',
      vocabulary: ProgressCategory.fromJson(
        json['vocabulary'] as Map<String, dynamic>? ?? {},
      ),
      grammar: ProgressCategory.fromJson(
        json['grammar'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

class JlptProgressResponse {
  final List<JlptLevelProgress> levels;

  const JlptProgressResponse({required this.levels});

  factory JlptProgressResponse.fromJson(Map<String, dynamic> json) {
    final list = json['levels'] as List<dynamic>? ?? [];
    return JlptProgressResponse(
      levels: list
          .map((e) => JlptLevelProgress.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ProgressCategory {
  final int total;
  final int mastered;
  final int inProgress;

  const ProgressCategory({
    required this.total,
    required this.mastered,
    required this.inProgress,
  });

  factory ProgressCategory.fromJson(Map<String, dynamic> json) {
    return ProgressCategory(
      total: json['total'] as int? ?? 0,
      mastered: json['mastered'] as int? ?? 0,
      inProgress: json['inProgress'] as int? ?? 0,
    );
  }
}
