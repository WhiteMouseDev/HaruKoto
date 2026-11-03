import 'call_settings.dart';

class UserPreferences {
  const UserPreferences({
    this.showFurigana = true,
    this.showKana = false,
    this.dailyGoal = 10,
    this.dailyGoalConfirmed = false,
    this.jlptLevel = 'N5',
    this.callSettings = const CallSettings(),
  });

  final bool showFurigana;
  final bool showKana;
  final int dailyGoal;
  final bool dailyGoalConfirmed;
  final String jlptLevel;
  final CallSettings callSettings;

  UserPreferences copyWith({
    bool? showFurigana,
    bool? showKana,
    int? dailyGoal,
    bool? dailyGoalConfirmed,
    String? jlptLevel,
    CallSettings? callSettings,
  }) {
    return UserPreferences(
      showFurigana: showFurigana ?? this.showFurigana,
      showKana: showKana ?? this.showKana,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      dailyGoalConfirmed: dailyGoalConfirmed ?? this.dailyGoalConfirmed,
      jlptLevel: jlptLevel ?? this.jlptLevel,
      callSettings: callSettings ?? this.callSettings,
    );
  }
}
