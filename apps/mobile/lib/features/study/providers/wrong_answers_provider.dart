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
    this.total = 0,
    this.totalPages = 1,
    this.page = 1,
    this.sort = 'most-wrong',
    this.search = '',
    this.status = WrongAnswerStatus.all,
    this.supportsSearchAndStatus = false,
    this.error,
    this.expandedId,
    this.savedWords = const {},
  });

  static const _unchanged = Object();

  final bool loading;
  final List<WrongEntryModel> entries;
  final WrongAnswersSummary? summary;
  final int total;
  final int totalPages;
  final int page;
  final String sort;
  final String search;
  final WrongAnswerStatus status;
  final bool supportsSearchAndStatus;
  final String? error;
  final String? expandedId;
  final Set<String> savedWords;

  bool get hasActiveFilters =>
      search.trim().isNotEmpty || status != WrongAnswerStatus.all;

  WrongAnswersState copyWith({
    bool? loading,
    List<WrongEntryModel>? entries,
    Object? summary = _unchanged,
    int? total,
    int? totalPages,
    int? page,
    String? sort,
    String? search,
    WrongAnswerStatus? status,
    bool? supportsSearchAndStatus,
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
      total: total ?? this.total,
      totalPages: totalPages ?? this.totalPages,
      page: page ?? this.page,
      sort: sort ?? this.sort,
      search: search ?? this.search,
      status: status ?? this.status,
      supportsSearchAndStatus:
          supportsSearchAndStatus ?? this.supportsSearchAndStatus,
      error: identical(error, _unchanged) ? this.error : error as String?,
      expandedId: identical(expandedId, _unchanged)
          ? this.expandedId
          : expandedId as String?,
      savedWords: savedWords ?? this.savedWords,
    );
  }
}

class WrongAnswersController extends Notifier<WrongAnswersState> {
  static const _searchDebounce = Duration(milliseconds: 300);

  int _requestSerial = 0;
  Timer? _searchTimer;

  @override
  WrongAnswersState build() {
    ref.onDispose(() {
      _searchTimer?.cancel();
      _requestSerial++;
    });
    return const WrongAnswersState();
  }

  Future<void> refresh() => _load(state);

  Future<void> _load(WrongAnswersState next) async {
    _searchTimer?.cancel();
    _searchTimer = null;
    final requestId = ++_requestSerial;
    state = next.copyWith(loading: true, error: null);

    try {
      final data = await ref.read(studyRepositoryProvider).fetchWrongAnswers(
            page: next.page,
            sort: next.sort,
            search: next.search,
            status: next.status,
          );
      if (!_isCurrent(requestId)) return;
      state = state.copyWith(
        loading: false,
        entries: data.entries,
        summary: data.summary,
        total: data.total,
        totalPages: data.totalPages,
        supportsSearchAndStatus: data.supportsSearchAndStatus,
        search: data.supportsSearchAndStatus ? null : '',
        status: data.supportsSearchAndStatus ? null : WrongAnswerStatus.all,
      );
    } catch (error, stackTrace) {
      if (!_isCurrent(requestId)) return;
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      state = state.copyWith(
        loading: false,
        error: '데이터를 불러올 수 없습니다',
      );
    }
  }

  bool _isCurrent(int requestId) => ref.mounted && requestId == _requestSerial;

  void changeSearch(String search) {
    if (!state.supportsSearchAndStatus || state.search == search) return;
    if (state.search.trim() == search.trim()) {
      state = state.copyWith(search: search);
      return;
    }
    _searchTimer?.cancel();
    _requestSerial++;
    _searchTimer = Timer(_searchDebounce, () => unawaited(refresh()));
    state = state.copyWith(
      search: search,
      page: 1,
      expandedId: null,
      loading: true,
      error: null,
    );
  }

  Future<void> changeStatus(WrongAnswerStatus status) async {
    if (!state.supportsSearchAndStatus || state.status == status) return;
    await _load(state.copyWith(status: status, page: 1, expandedId: null));
  }

  Future<void> clearFilters() async {
    if (state.search.isEmpty && state.status == WrongAnswerStatus.all) return;
    await _load(state.copyWith(
      search: '',
      status: WrongAnswerStatus.all,
      page: 1,
      expandedId: null,
    ));
  }

  Future<void> changeSort(String sort) async {
    if (state.sort == sort) return;
    await _load(state.copyWith(
      sort: sort,
      page: 1,
      expandedId: null,
    ));
  }

  Future<void> previousPage() async {
    if (state.loading || state.page <= 1) return;
    await _load(state.copyWith(
      page: state.page - 1,
      expandedId: null,
    ));
  }

  Future<void> nextPage() async {
    if (state.loading || state.page >= state.totalPages) return;
    await _load(state.copyWith(
      page: state.page + 1,
      expandedId: null,
    ));
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
