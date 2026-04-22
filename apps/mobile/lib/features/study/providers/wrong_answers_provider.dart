import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../data/models/word_entry_model.dart';
import 'study_provider.dart';

class WrongAnswersState {
  const WrongAnswersState({
    this.loading = true,
    this.entries = const [],
    this.summary,
    this.totalPages = 1,
    this.page = 1,
    this.sort = 'most-wrong',
    this.error,
    this.expandedId,
    this.savedWords = const {},
  });

  static const _unchanged = Object();

  final bool loading;
  final List<WrongEntryModel> entries;
  final WrongAnswersSummary? summary;
  final int totalPages;
  final int page;
  final String sort;
  final String? error;
  final String? expandedId;
  final Set<String> savedWords;

  WrongAnswersState copyWith({
    bool? loading,
    List<WrongEntryModel>? entries,
    Object? summary = _unchanged,
    int? totalPages,
    int? page,
    String? sort,
    Object? error = _unchanged,
    Object? expandedId = _unchanged,
    Set<String>? savedWords,
  }) {
    return WrongAnswersState(
      loading: loading ?? this.loading,
      entries: entries ?? this.entries,
      summary: identical(summary, _unchanged)
          ? this.summary
          : summary as WrongAnswersSummary?,
      totalPages: totalPages ?? this.totalPages,
      page: page ?? this.page,
      sort: sort ?? this.sort,
      error: identical(error, _unchanged) ? this.error : error as String?,
      expandedId: identical(expandedId, _unchanged)
          ? this.expandedId
          : expandedId as String?,
      savedWords: savedWords ?? this.savedWords,
    );
  }
}

class WrongAnswersController extends Notifier<WrongAnswersState> {
  int _requestSerial = 0;

  @override
  WrongAnswersState build() {
    return const WrongAnswersState();
  }

  Future<void> refresh() async {
    final requestId = ++_requestSerial;
    final page = state.page;
    final sort = state.sort;

    state = state.copyWith(
      loading: true,
      error: null,
    );

    try {
      final data = await ref.read(studyRepositoryProvider).fetchWrongAnswers(
            page: page,
            sort: sort,
          );
      if (requestId != _requestSerial) return;
      state = state.copyWith(
        loading: false,
        entries: data.entries,
        summary: data.summary,
        totalPages: data.totalPages,
      );
    } catch (error, stackTrace) {
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      if (requestId != _requestSerial) return;
      state = state.copyWith(
        loading: false,
        error: '데이터를 불러올 수 없습니다',
      );
    }
  }

  Future<void> changeSort(String sort) async {
    if (state.sort == sort) return;
    state = state.copyWith(
      sort: sort,
      page: 1,
      expandedId: null,
    );
    await refresh();
  }

  Future<void> previousPage() async {
    if (state.page <= 1) return;
    state = state.copyWith(
      page: state.page - 1,
      expandedId: null,
    );
    await refresh();
  }

  Future<void> nextPage() async {
    if (state.page >= state.totalPages) return;
    state = state.copyWith(
      page: state.page + 1,
      expandedId: null,
    );
    await refresh();
  }

  void toggleExpanded(String id) {
    state = state.copyWith(
      expandedId: state.expandedId == id ? null : id,
    );
  }

  Future<bool> saveToWordbook(WrongEntryModel entry) async {
    if (state.savedWords.contains(entry.vocabularyId)) return true;

    try {
      await ref.read(studyRepositoryProvider).addWord(
            word: entry.word,
            reading: entry.reading,
            meaningKo: entry.meaningKo,
            source: 'QUIZ',
          );
      state = state.copyWith(
        savedWords: Set.unmodifiable({
          ...state.savedWords,
          entry.vocabularyId,
        }),
      );
      return true;
    } catch (error, stackTrace) {
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      return false;
    }
  }
}

final wrongAnswersProvider =
    NotifierProvider.autoDispose<WrongAnswersController, WrongAnswersState>(
  WrongAnswersController.new,
);
