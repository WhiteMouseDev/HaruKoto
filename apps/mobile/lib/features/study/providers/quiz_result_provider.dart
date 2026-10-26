import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../core/network/api_exception.dart';
import '../data/models/quiz_result_model.dart';
import 'study_provider.dart';

class QuizResultState {
  const QuizResultState({
    this.sessionId,
    this.loadingWrong = true,
    this.wrongAnswers = const [],
    this.savedWords = const {},
    this.error,
  });

  static const _unchanged = Object();

  final String? sessionId;
  final bool loadingWrong;
  final List<WrongAnswerModel> wrongAnswers;
  final Set<String> savedWords;
  final String? error;

  QuizResultState copyWith({
    String? sessionId,
    bool? loadingWrong,
    List<WrongAnswerModel>? wrongAnswers,
    Set<String>? savedWords,
    Object? error = _unchanged,
  }) {
    return QuizResultState(
      sessionId: sessionId ?? this.sessionId,
      loadingWrong: loadingWrong ?? this.loadingWrong,
      wrongAnswers: wrongAnswers ?? this.wrongAnswers,
      savedWords: savedWords ?? this.savedWords,
      error: identical(error, _unchanged) ? this.error : error as String?,
    );
  }
}

class QuizResultController extends Notifier<QuizResultState> {
  QuizResultController(this.sessionId);

  final String sessionId;
  int _requestSerial = 0;

  @override
  QuizResultState build() {
    ref.onDispose(() => _requestSerial++);
    return QuizResultState(sessionId: sessionId);
  }

  Future<void> loadWrongAnswers({
    required int wrongCount,
  }) async {
    final requestId = ++_requestSerial;
    final savedWords = state.savedWords;
    state = QuizResultState(
      sessionId: sessionId,
      loadingWrong: wrongCount > 0,
      savedWords: savedWords,
    );

    if (wrongCount <= 0) {
      return;
    }

    try {
      final answers = await ref
          .read(studyRepositoryProvider)
          .fetchWrongAnswersBySession(sessionId);
      if (!ref.mounted || requestId != _requestSerial) return;
      state = state.copyWith(
        loadingWrong: false,
        wrongAnswers: answers,
      );
    } catch (error, stackTrace) {
      if (!ref.mounted || requestId != _requestSerial) return;
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      final cause = error is DioException ? error.error : error;
      state = state.copyWith(
        loadingWrong: false,
        error: cause is ApiException
            ? cause.userMessage
            : const ApiException(message: '잠시 후 다시 시도해 주세요.').userMessage,
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
      if (!ref.mounted) return true;
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
      if (!ref.mounted) return false;
      final saved = await saveToWordbook(item);
      if (!ref.mounted) return false;
      allSaved = allSaved && saved;
    }

    return allSaved;
  }
}

final quizResultProvider = NotifierProvider.autoDispose
    .family<QuizResultController, QuizResultState, String>(
  QuizResultController.new,
);
