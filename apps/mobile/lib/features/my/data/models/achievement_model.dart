class AchievementDefinition {
  final String type;
  final String title;
  final String emoji;
  final String category;

  const AchievementDefinition({
    required this.type,
    required this.title,
    required this.emoji,
    required this.category,
  });
}

const achievementDefinitions = <AchievementDefinition>[
  AchievementDefinition(
      type: 'first_quiz', title: '첫 퀴즈', emoji: 'target', category: 'quiz'),
  AchievementDefinition(
      type: 'quiz_10', title: '퀴즈 10회', emoji: 'target', category: 'quiz'),
  AchievementDefinition(
      type: 'quiz_50', title: '퀴즈 50회', emoji: 'target', category: 'quiz'),
  AchievementDefinition(
      type: 'quiz_100', title: '퀴즈 100회', emoji: 'trophy', category: 'quiz'),
  AchievementDefinition(
      type: 'perfect_quiz', title: '퍼펙트 퀴즈', emoji: 'star', category: 'quiz'),
  AchievementDefinition(
      type: 'first_chat',
      title: '첫 대화',
      emoji: 'messageCircle',
      category: 'conversation'),
  AchievementDefinition(
      type: 'chat_10',
      title: '대화 10회',
      emoji: 'messageCircle',
      category: 'conversation'),
  AchievementDefinition(
      type: 'chat_50',
      title: '대화 50회',
      emoji: 'messageCircle',
      category: 'conversation'),
  AchievementDefinition(
      type: 'streak_3', title: '3일 연속', emoji: 'flame', category: 'streak'),
  AchievementDefinition(
      type: 'streak_7', title: '7일 연속', emoji: 'flame', category: 'streak'),
  AchievementDefinition(
      type: 'streak_30', title: '30일 연속', emoji: 'flame', category: 'streak'),
  AchievementDefinition(
      type: 'streak_100', title: '100일 연속', emoji: 'flame', category: 'streak'),
  AchievementDefinition(
      type: 'words_10', title: '단어 10개', emoji: 'bookOpen', category: 'words'),
  AchievementDefinition(
      type: 'words_50', title: '단어 50개', emoji: 'bookOpen', category: 'words'),
  AchievementDefinition(
      type: 'words_100',
      title: '단어 100개',
      emoji: 'bookOpen',
      category: 'words'),
  AchievementDefinition(
      type: 'words_500',
      title: '단어 500개',
      emoji: 'bookOpen',
      category: 'words'),
  AchievementDefinition(
      type: 'level_5', title: '레벨 5', emoji: 'zap', category: 'level'),
  AchievementDefinition(
      type: 'level_10', title: '레벨 10', emoji: 'zap', category: 'level'),
  AchievementDefinition(
      type: 'xp_1000', title: 'XP 1000', emoji: 'zap', category: 'xp'),
  AchievementDefinition(
      type: 'xp_5000', title: 'XP 5000', emoji: 'zap', category: 'xp'),
];

/// Achievement data returned from GET /api/v1/achievements
class AchievementItem {
  final String type;
  final String title;
  final String description;
  final String emoji;
  final bool achieved;
  final String? achievedAt;

  const AchievementItem({
    required this.type,
    required this.title,
    required this.description,
    required this.emoji,
    required this.achieved,
    this.achievedAt,
  });

  factory AchievementItem.fromJson(Map<String, dynamic> json) {
    return AchievementItem(
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '',
      achieved: json['achieved'] as bool? ?? false,
      achievedAt: json['achievedAt'] as String?,
    );
  }
}
