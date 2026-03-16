class CharacterListItem {
  final String id;
  final String name;
  final String nameJa;
  final String nameRomaji;
  final String gender;
  final String description;
  final String relationship;
  final String speechStyle;
  final String targetLevel;
  final String tier;
  final String? unlockCondition;
  final bool isDefault;
  final String avatarEmoji;
  final String? avatarUrl;
  final String? gradient;
  final int order;

  const CharacterListItem({
    required this.id,
    required this.name,
    required this.nameJa,
    required this.nameRomaji,
    required this.gender,
    required this.description,
    required this.relationship,
    required this.speechStyle,
    required this.targetLevel,
    required this.tier,
    this.unlockCondition,
    required this.isDefault,
    required this.avatarEmoji,
    this.avatarUrl,
    this.gradient,
    required this.order,
  });

  factory CharacterListItem.fromJson(Map<String, dynamic> json) {
    return CharacterListItem(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      nameJa: json['nameJa'] as String? ?? '',
      nameRomaji: json['nameRomaji'] as String? ?? '',
      gender: json['gender'] as String? ?? '',
      description: json['description'] as String? ?? '',
      relationship: json['relationship'] as String? ?? '',
      speechStyle: json['speechStyle'] as String? ?? '',
      targetLevel: json['targetLevel'] as String? ?? '',
      tier: json['tier'] as String? ?? '',
      unlockCondition: json['unlockCondition'] as String?,
      isDefault: json['isDefault'] as bool? ?? false,
      avatarEmoji: json['avatarEmoji'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      gradient: json['gradient'] as String?,
      order: json['order'] as int? ?? 0,
    );
  }
}

/// Character detail with voice call fields.
class CharacterDetail {
  final String id;
  final String name;
  final String nameJa;
  final String? avatarUrl;
  final String? personality;
  final String? voiceName;
  final String? voiceBackup;
  final int silenceMs;
  final String targetLevel;
  final String speechStyle;
  final String relationship;

  const CharacterDetail({
    required this.id,
    required this.name,
    required this.nameJa,
    this.avatarUrl,
    this.personality,
    this.voiceName,
    this.voiceBackup,
    this.silenceMs = 1200,
    required this.targetLevel,
    required this.speechStyle,
    required this.relationship,
  });

  factory CharacterDetail.fromJson(Map<String, dynamic> json) {
    return CharacterDetail(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      nameJa: json['nameJa'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      personality: json['personality'] as String?,
      voiceName: json['voiceName'] as String?,
      voiceBackup: json['voiceBackup'] as String?,
      silenceMs: json['silenceMs'] as int? ?? 1200,
      targetLevel: json['targetLevel'] as String? ?? '',
      speechStyle: json['speechStyle'] as String? ?? '',
      relationship: json['relationship'] as String? ?? '',
    );
  }
}
