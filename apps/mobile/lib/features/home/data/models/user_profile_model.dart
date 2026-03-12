class UserProfileModel {
  final String nickname;
  final int dailyGoal;
  final bool showKana;
  final String jlptLevel;
  final String? avatarUrl;

  const UserProfileModel({
    required this.nickname,
    required this.dailyGoal,
    required this.showKana,
    required this.jlptLevel,
    this.avatarUrl,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    // API returns nested: {profile: {...}, stats: {...}}
    final profile =
        json['profile'] as Map<String, dynamic>? ?? json;
    return UserProfileModel(
      nickname: profile['nickname'] as String? ?? '학습자',
      dailyGoal: profile['dailyGoal'] as int? ?? 10,
      showKana: profile['showKana'] as bool? ?? true,
      jlptLevel: profile['jlptLevel'] as String? ?? 'N5',
      avatarUrl: profile['avatarUrl'] as String?,
    );
  }
}
