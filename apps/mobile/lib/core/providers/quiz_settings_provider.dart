import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuizSettingsNotifier extends Notifier<QuizSettings> {
  static const _keyShowFurigana = 'quiz_show_furigana';

  @override
  QuizSettings build() {
    _loadFromPrefs();
    return const QuizSettings();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    state = QuizSettings(
      showFurigana: prefs.getBool(_keyShowFurigana) ?? true,
    );
  }

  Future<void> setShowFurigana(bool value) async {
    state = state.copyWith(showFurigana: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowFurigana, value);
  }
}

class QuizSettings {
  final bool showFurigana;

  const QuizSettings({this.showFurigana = true});

  QuizSettings copyWith({bool? showFurigana}) =>
      QuizSettings(showFurigana: showFurigana ?? this.showFurigana);
}

final quizSettingsProvider =
    NotifierProvider<QuizSettingsNotifier, QuizSettings>(
  QuizSettingsNotifier.new,
);
