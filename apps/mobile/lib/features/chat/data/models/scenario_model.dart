class ScenarioModel {
  final String id;
  final String title;
  final String titleJa;
  final String description;
  final String category;
  final String difficulty;
  final int estimatedMinutes;
  final List<String> keyExpressions;
  final String situation;
  final String yourRole;
  final String aiRole;

  const ScenarioModel({
    required this.id,
    required this.title,
    required this.titleJa,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.estimatedMinutes,
    required this.keyExpressions,
    required this.situation,
    required this.yourRole,
    required this.aiRole,
  });

  factory ScenarioModel.fromJson(Map<String, dynamic> json) {
    return ScenarioModel(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      titleJa: json['titleJa'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? '',
      estimatedMinutes: json['estimatedMinutes'] as int? ?? 5,
      keyExpressions: (json['keyExpressions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      situation: json['situation'] as String? ?? '',
      yourRole: json['yourRole'] as String? ?? '',
      aiRole: json['aiRole'] as String? ?? '',
    );
  }
}
