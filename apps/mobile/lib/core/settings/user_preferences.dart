import '../../features/my/data/models/profile_detail_model.dart';

class UserPreferences {
  const UserPreferences({
    this.showFurigana = true,
    this.showKana = false,
    this.dailyGoal = 10,
    this.jlptLevel = 'N5',
    this.callSettings = const CallSettings(),
  });

  final bool showFurigana;
  final bool showKana;
  final int dailyGoal;
  final String jlptLevel;
  final CallSettings callSettings;

  UserPreferences copyWith({
    bool? showFurigana,
    bool? showKana,
    int? dailyGoal,
    String? jlptLevel,
    CallSettings? callSettings,
  }) {
    return UserPreferences(
      showFurigana: showFurigana ?? this.showFurigana,
      showKana: showKana ?? this.showKana,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      jlptLevel: jlptLevel ?? this.jlptLevel,
      callSettings: callSettings ?? this.callSettings,
    );
  }
}
