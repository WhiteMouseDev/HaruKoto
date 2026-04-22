import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../data/models/quiz_result_model.dart';
import 'study_provider.dart';

class QuizResultState {
  const QuizResultState({
    this.loadingWrong = true,
    this.wrongAnswers = const [],
    this.savedWords = const {},
    this.error,
  });

  static const _unchanged = Object();

  final bool loadingWrong;
  final List<WrongAnswerModel> wrongAnswers;
  final Set<String> savedWords;
  final String? error;

  QuizResultState copyWith({
    bool? loadingWrong,
    List<WrongAnswerModel>? wrongAnswers,
    Set<String>? savedWords,
    Object? error = _unchanged,
  }) {
    return QuizResultState(
      loadingWrong: loadingWrong ?? this.loadingWrong,
      wrongAnswers: wrongAnswers ?? this.wrongAnswers,
      savedWords: savedWords ?? this.savedWords,
      error: identical(error, _unchanged) ? this.error : error as String?,
    );
  }
}

class QuizResultController extends Notifier<QuizResultState> {
  int _requestSerial = 0;

  @override
  QuizResultState build() {
    return const QuizResultState();
  }

  Future<void> loadWrongAnswers({
    required String sessionId,
    required int wrongCount,
  }) async {
    final requestId = ++_requestSerial;

    if (wrongCount <= 0) {
      state = state.copyWith(
        loadingWrong: false,
        wrongAnswers: const [],
        error: null,
      );
      return;
    }

    state = state.copyWith(
      loadingWrong: true,
      error: null,
    );

    try {
      final answers = await ref
          .read(studyRepositoryProvider)
          .fetchWrongAnswersBySession(sessionId);
      if (requestId != _requestSerial) return;
      state = state.copyWith(
        loadingWrong: false,
        wrongAnswers: answers,
      );
    } catch (error, stackTrace) {
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      if (requestId != _requestSerial) return;
      state = state.copyWith(
        loadingWrong: false,
        error: '오답을 불러올 수 없습니다',
      );
    }
  }

  Future<bool> saveToWordbook(WrongAnswerModel item) async {
    if (state.savedWords.contains(item.questionId)) return true;

    try {
      await ref.read(studyRepositoryProvider).addWord(
            word: item.word,
            reading: item.reading ?? item.word,
            meaningKo: item.meaningKo,
            source: 'QUIZ',
          );
      state = state.copyWith(
        savedWords: Set.unmodifiable({
          ...state.savedWords,
          item.questionId,
        }),
      );
      return true;
    } catch (error, stackTrace) {
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      return false;
    }
  }

  Future<bool> saveAllToWordbook() async {
    final unsaved = state.wrongAnswers
        .where((item) => !state.savedWords.contains(item.questionId))
        .toList();
    var allSaved = true;

    for (final item in unsaved) {
      final saved = await saveToWordbook(item);
      allSaved = allSaved && saved;
    }

    return allSaved;
  }
}

final quizResultProvider =
    NotifierProvider.autoDispose<QuizResultController, QuizResultState>(
  QuizResultController.new,
);
