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

/// Synced with server ACHIEVEMENTS list in gamification.py
const achievementDefinitions = <AchievementDefinition>[
  // Quiz
  AchievementDefinition(
      type: 'first_quiz', title: '첫 퀴즈', emoji: 'target', category: 'quiz'),
  AchievementDefinition(
      type: 'quiz_10', title: '퀴즈 10회', emoji: 'target', category: 'quiz'),
  AchievementDefinition(
      type: 'quiz_50', title: '퀴즈 50회', emoji: 'target', category: 'quiz'),
  AchievementDefinition(
      type: 'quiz_100', title: '퀴즈 100회', emoji: 'trophy', category: 'quiz'),
  AchievementDefinition(
      type: 'perfect_quiz',
      title: '퍼펙트!',
      emoji: 'check-check',
      category: 'special'),
  // Conversation
  AchievementDefinition(
      type: 'first_conversation',
      title: '첫 대화',
      emoji: 'messageCircle',
      category: 'conversation'),
  AchievementDefinition(
      type: 'conversation_10',
      title: '대화 10회',
      emoji: 'messageCircle',
      category: 'conversation'),
  AchievementDefinition(
      type: 'conversation_50',
      title: '대화 50회',
      emoji: 'messageCircle',
      category: 'conversation'),
  // Streak
  AchievementDefinition(
      type: 'streak_3', title: '3일 연속', emoji: 'flame', category: 'streak'),
  AchievementDefinition(
      type: 'streak_7', title: '7일 연속', emoji: 'flame', category: 'streak'),
  AchievementDefinition(
      type: 'streak_30', title: '30일 연속', emoji: 'flame', category: 'streak'),
  AchievementDefinition(
      type: 'streak_100', title: '100일 연속', emoji: 'flame', category: 'streak'),
  // Words
  AchievementDefinition(
      type: 'words_50', title: '단어 50개', emoji: 'bookOpen', category: 'words'),
  AchievementDefinition(
      type: 'words_100',
      title: '단어 100개',
      emoji: 'bookOpen',
      category: 'words'),
  // Level
  AchievementDefinition(
      type: 'level_5', title: '레벨 5', emoji: 'star', category: 'level'),
  AchievementDefinition(
      type: 'level_10', title: '레벨 10', emoji: 'zap', category: 'level'),
  AchievementDefinition(
      type: 'level_20', title: '레벨 20', emoji: 'zap', category: 'level'),
  // XP
  AchievementDefinition(
      type: 'xp_1000', title: 'XP 1000', emoji: 'zap', category: 'xp'),
  AchievementDefinition(
      type: 'xp_5000', title: 'XP 5000', emoji: 'zap', category: 'xp'),
  AchievementDefinition(
      type: 'xp_10000', title: 'XP 10000', emoji: 'zap', category: 'xp'),
  // Kana
  AchievementDefinition(
      type: 'kana_first_char',
      title: '첫 글자!',
      emoji: 'sprout',
      category: 'kana'),
  AchievementDefinition(
      type: 'kana_hiragana_complete',
      title: '히라가나 완성',
      emoji: 'sparkles',
      category: 'kana'),
  AchievementDefinition(
      type: 'kana_katakana_complete',
      title: '카타카나 완성',
      emoji: 'sparkles',
      category: 'kana'),
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
