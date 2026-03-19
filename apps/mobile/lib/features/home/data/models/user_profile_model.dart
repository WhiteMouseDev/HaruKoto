class UserProfileModel {
  final String nickname;
  final int dailyGoal;
  final bool showKana;
  final String jlptLevel;
  final String? avatarUrl;
  final bool showFurigana;
  final bool onboardingCompleted;

  const UserProfileModel({
    required this.nickname,
    required this.dailyGoal,
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
      showKana: profile['showKana'] as bool? ?? true,
      jlptLevel: profile['jlptLevel'] as String? ?? 'N5',
      avatarUrl: profile['avatarUrl'] as String?,
      showFurigana: appSettings['showFurigana'] as bool? ?? true,
      onboardingCompleted: profile['onboardingCompleted'] as bool? ?? false,
    );
  }
}
