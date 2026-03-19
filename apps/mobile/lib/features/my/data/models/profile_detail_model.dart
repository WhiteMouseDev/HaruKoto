class ProfileDetailModel {
  final ProfileInfo profile;
  final ProfileSummary summary;
  final List<UserAchievement> achievements;

  const ProfileDetailModel({
    required this.profile,
    required this.summary,
    required this.achievements,
  });

  factory ProfileDetailModel.fromJson(Map<String, dynamic> json) {
    return ProfileDetailModel(
      profile: ProfileInfo.fromJson(
        json['profile'] as Map<String, dynamic>? ?? {},
      ),
      summary: ProfileSummary.fromJson(
        json['summary'] as Map<String, dynamic>? ?? {},
      ),
      achievements: (json['achievements'] as List<dynamic>? ?? [])
          .map((e) => UserAchievement.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ProfileInfo {
  final String id;
  final String nickname;
  final String? avatarUrl;
  final String jlptLevel;
  final int dailyGoal;
  final int experiencePoints;
  final int level;
  final LevelProgress levelProgress;
  final int streakCount;
  final int longestStreak;
  final bool showKana;
  final CallSettings callSettings;
  final Map<String, dynamic> appSettings;
  final String createdAt;

  const ProfileInfo({
    required this.id,
    required this.nickname,
    this.avatarUrl,
    required this.jlptLevel,
    required this.dailyGoal,
    required this.experiencePoints,
    required this.level,
    required this.levelProgress,
    required this.streakCount,
    required this.longestStreak,
    required this.showKana,
    this.callSettings = const CallSettings(),
    this.appSettings = const {},
    required this.createdAt,
  });

  bool get showFurigana => appSettings['showFurigana'] as bool? ?? true;

  factory ProfileInfo.fromJson(Map<String, dynamic> json) {
    return ProfileInfo(
      id: json['id'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      jlptLevel: json['jlptLevel'] as String? ?? 'N5',
      dailyGoal: json['dailyGoal'] as int? ?? 10,
      experiencePoints: json['experiencePoints'] as int? ?? 0,
      level: json['level'] as int? ?? 1,
      levelProgress: LevelProgress.fromJson(
        json['levelProgress'] as Map<String, dynamic>? ?? {},
      ),
      streakCount: json['streakCount'] as int? ?? 0,
      longestStreak: json['longestStreak'] as int? ?? 0,
      showKana: json['showKana'] as bool? ?? false,
      callSettings: CallSettings.fromJson(
        json['callSettings'] as Map<String, dynamic>? ?? {},
      ),
      appSettings: json['appSettings'] as Map<String, dynamic>? ?? {},
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class CallSettings {
  final int silenceDurationMs;
  final double aiResponseSpeed;
  final bool subtitleEnabled;
  final bool autoAnalysis;

  const CallSettings({
    this.silenceDurationMs = 1200,
    this.aiResponseSpeed = 1.0,
    this.subtitleEnabled = true,
    this.autoAnalysis = true,
  });

  CallSettings copyWith({
    int? silenceDurationMs,
    double? aiResponseSpeed,
    bool? subtitleEnabled,
    bool? autoAnalysis,
  }) {
    return CallSettings(
      silenceDurationMs: silenceDurationMs ?? this.silenceDurationMs,
      aiResponseSpeed: aiResponseSpeed ?? this.aiResponseSpeed,
      subtitleEnabled: subtitleEnabled ?? this.subtitleEnabled,
      autoAnalysis: autoAnalysis ?? this.autoAnalysis,
    );
  }

  factory CallSettings.fromJson(Map<String, dynamic> json) {
    return CallSettings(
      silenceDurationMs: json['silenceDurationMs'] as int? ?? 3000,
      aiResponseSpeed: (json['aiResponseSpeed'] as num?)?.toDouble() ?? 1.0,
      subtitleEnabled: json['subtitleEnabled'] as bool? ?? true,
      autoAnalysis: json['autoAnalysis'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'silenceDurationMs': silenceDurationMs,
        'aiResponseSpeed': aiResponseSpeed,
        'subtitleEnabled': subtitleEnabled,
        'autoAnalysis': autoAnalysis,
      };
}

class LevelProgress {
  final int currentXp;
  final int xpForNext;

  const LevelProgress({required this.currentXp, required this.xpForNext});

  factory LevelProgress.fromJson(Map<String, dynamic> json) {
    return LevelProgress(
      currentXp: json['currentXp'] as int? ?? 0,
      xpForNext: json['xpForNext'] as int? ?? 1000,
    );
  }
}

class ProfileSummary {
  final int totalWordsStudied;
  final int totalQuizzesCompleted;
  final int totalStudyDays;
  final int totalXpEarned;

  const ProfileSummary({
    required this.totalWordsStudied,
    required this.totalQuizzesCompleted,
    required this.totalStudyDays,
    required this.totalXpEarned,
  });

  factory ProfileSummary.fromJson(Map<String, dynamic> json) {
    return ProfileSummary(
      totalWordsStudied: json['totalWordsStudied'] as int? ?? 0,
      totalQuizzesCompleted: json['totalQuizzesCompleted'] as int? ?? 0,
      totalStudyDays: json['totalStudyDays'] as int? ?? 0,
      totalXpEarned: json['totalXpEarned'] as int? ?? 0,
    );
  }
}

class UserAchievement {
  final String achievementType;
  final String achievedAt;

  const UserAchievement({
    required this.achievementType,
    required this.achievedAt,
  });

  factory UserAchievement.fromJson(Map<String, dynamic> json) {
    return UserAchievement(
      achievementType: json['achievementType'] as String? ?? '',
      achievedAt: json['achievedAt'] as String? ?? '',
    );
  }
}
