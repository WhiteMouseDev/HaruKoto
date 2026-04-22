import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../data/models/word_entry_model.dart';
import 'study_provider.dart';

class LearnedWordsState {
  const LearnedWordsState({
    this.loading = true,
    this.entries = const [],
    this.summary,
    this.totalPages = 1,
    this.page = 1,
    this.sort = 'recent',
    this.search = '',
    this.filter = 'ALL',
    this.error,
    this.expandedId,
  });

  static const _unchanged = Object();

  final bool loading;
  final List<LearnedWordModel> entries;
  final LearnedWordsSummary? summary;
  final int totalPages;
  final int page;
  final String sort;
  final String search;
  final String filter;
  final String? error;
  final String? expandedId;

  LearnedWordsState copyWith({
    bool? loading,
    List<LearnedWordModel>? entries,
    Object? summary = _unchanged,
    int? totalPages,
    int? page,
    String? sort,
    String? search,
    String? filter,
    Object? error = _unchanged,
    Object? expandedId = _unchanged,
  }) {
    return LearnedWordsState(
      loading: loading ?? this.loading,
      entries: entries ?? this.entries,
      summary: identical(summary, _unchanged)
          ? this.summary
          : summary as LearnedWordsSummary?,
      totalPages: totalPages ?? this.totalPages,
      page: page ?? this.page,
      sort: sort ?? this.sort,
      search: search ?? this.search,
      filter: filter ?? this.filter,
      error: identical(error, _unchanged) ? this.error : error as String?,
      expandedId: identical(expandedId, _unchanged)
          ? this.expandedId
          : expandedId as String?,
    );
  }
}

class LearnedWordsController extends Notifier<LearnedWordsState> {
  int _requestSerial = 0;

  @override
  LearnedWordsState build() {
    return const LearnedWordsState();
  }

  Future<void> refresh() async {
    final requestId = ++_requestSerial;
    final page = state.page;
    final sort = state.sort;
    final search = state.search;
    final filter = state.filter;

    state = state.copyWith(
      loading: true,
      error: null,
    );

    try {
      final data = await ref.read(studyRepositoryProvider).fetchLearnedWords(
            page: page,
            sort: sort,
            search: search,
            filter: filter,
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
        error: '데이터를 불러올 수 없습니다.',
      );
    }
  }

  Future<void> changeSearch(String search) async {
    if (state.search == search) return;
    state = state.copyWith(
      search: search,
      page: 1,
      expandedId: null,
    );
    await refresh();
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

  Future<void> changeFilter(String filter) async {
    if (state.filter == filter) return;
    state = state.copyWith(
      filter: filter,
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
}

final learnedWordsProvider =
    NotifierProvider.autoDispose<LearnedWordsController, LearnedWordsState>(
  LearnedWordsController.new,
);
