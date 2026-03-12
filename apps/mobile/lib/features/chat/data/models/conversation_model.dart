class ConversationModel {
  final String id;
  final String type; // 'VOICE' | 'TEXT'
  final String createdAt;
  final String? endedAt;
  final int messageCount;
  final int? overallScore;
  final ConversationScenario? scenario;
  final ConversationCharacter? character;

  const ConversationModel({
    required this.id,
    required this.type,
    required this.createdAt,
    this.endedAt,
    required this.messageCount,
    this.overallScore,
    this.scenario,
    this.character,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'TEXT',
      createdAt: json['createdAt'] as String,
      endedAt: json['endedAt'] as String?,
      messageCount: json['messageCount'] as int? ?? 0,
      overallScore: json['overallScore'] as int?,
      scenario: json['scenario'] != null
          ? ConversationScenario.fromJson(
              json['scenario'] as Map<String, dynamic>)
          : null,
      character: json['character'] != null
          ? ConversationCharacter.fromJson(
              json['character'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ConversationScenario {
  final String title;
  final String titleJa;
  final String category;
  final String difficulty;

  const ConversationScenario({
    required this.title,
    required this.titleJa,
    required this.category,
    required this.difficulty,
  });

  factory ConversationScenario.fromJson(Map<String, dynamic> json) {
    return ConversationScenario(
      title: json['title'] as String? ?? '',
      titleJa: json['titleJa'] as String? ?? '',
      category: json['category'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? '',
    );
  }
}

class ConversationCharacter {
  final String id;
  final String name;
  final String nameJa;
  final String avatarEmoji;
  final String? avatarUrl;

  const ConversationCharacter({
    required this.id,
    required this.name,
    required this.nameJa,
    required this.avatarEmoji,
    this.avatarUrl,
  });

  factory ConversationCharacter.fromJson(Map<String, dynamic> json) {
    return ConversationCharacter(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      nameJa: json['nameJa'] as String? ?? '',
      avatarEmoji: json['avatarEmoji'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}
