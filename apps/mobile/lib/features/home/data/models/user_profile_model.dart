class UserProfileModel {
  final String nickname;
  final int dailyGoal;
  final bool dailyGoalConfirmed;
  final String? userId;
  final bool showKana;
  final String jlptLevel;
  final String? avatarUrl;
  final bool showFurigana;
  final bool onboardingCompleted;

  const UserProfileModel({
    required this.nickname,
    required this.dailyGoal,
    this.dailyGoalConfirmed = true,
    this.userId,
    required this.showKana,
    required this.jlptLevel,
    this.avatarUrl,
    this.showFurigana = true,
    this.onboardingCompleted = false,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    // API returns nested: {profile: {...}, stats: {...}}
    final profile = json['profile'] as Map<String, dynamic>? ?? json;
    final appSettings = profile['appSettings'] as Map<String, dynamic>? ?? {};
    return UserProfileModel(
      nickname: profile['nickname'] as String? ?? '학습자',
      dailyGoal: profile['dailyGoal'] as int? ?? 10,
      dailyGoalConfirmed: profile['dailyGoal'] is int &&
          (profile['dailyGoal'] as int) >= 5 &&
          (profile['dailyGoal'] as int) <= 50,
      userId: profile['id'] as String?,
      showKana: profile['showKana'] as bool? ?? true,
      jlptLevel: profile['jlptLevel'] as String? ?? 'N5',
      avatarUrl: profile['avatarUrl'] as String?,
      showFurigana: appSettings['showFurigana'] as bool? ?? true,
      onboardingCompleted: profile['onboardingCompleted'] as bool? ?? false,
    );
  }
}
