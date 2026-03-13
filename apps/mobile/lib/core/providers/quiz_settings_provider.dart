import 'package:flutter_riverpod/flutter_riverpod.dart';

class QuizSettingsNotifier extends Notifier<QuizSettings> {
  @override
  QuizSettings build() => const QuizSettings();

  void setShowFurigana(bool value) =>
      state = state.copyWith(showFurigana: value);
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
