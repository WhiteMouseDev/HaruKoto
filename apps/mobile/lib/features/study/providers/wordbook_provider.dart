import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../data/models/wordbook_entry_model.dart';
import 'study_provider.dart';

class WordbookState {
  const WordbookState({
    this.loading = true,
    this.entries = const [],
    this.totalPages = 1,
    this.page = 1,
    this.sort = 'recent',
    this.search = '',
    this.filter = 'ALL',
    this.error,
  });

  static const _unchanged = Object();

  final bool loading;
  final List<WordbookEntryModel> entries;
  final int totalPages;
  final int page;
  final String sort;
  final String search;
  final String filter;
  final String? error;

  WordbookState copyWith({
    bool? loading,
    List<WordbookEntryModel>? entries,
    int? totalPages,
    int? page,
    String? sort,
    String? search,
    String? filter,
    Object? error = _unchanged,
  }) {
    return WordbookState(
      loading: loading ?? this.loading,
      entries: entries ?? this.entries,
      totalPages: totalPages ?? this.totalPages,
      page: page ?? this.page,
      sort: sort ?? this.sort,
      search: search ?? this.search,
      filter: filter ?? this.filter,
      error: identical(error, _unchanged) ? this.error : error as String?,
    );
  }
}

class WordbookController extends Notifier<WordbookState> {
  int _requestSerial = 0;

  @override
  WordbookState build() {
    return const WordbookState();
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
      final data = await ref.read(studyRepositoryProvider).fetchWordbook(
            page: page,
            sort: sort,
            search: search,
            filter: filter,
          );
      if (requestId != _requestSerial) return;
      state = state.copyWith(
        loading: false,
        entries: data.entries,
        totalPages: data.totalPages,
      );
    } catch (error, stackTrace) {
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      if (requestId != _requestSerial) return;
      state = state.copyWith(
        loading: false,
        error: '단어장을 불러올 수 없습니다.',
      );
    }
  }

  Future<void> changeSearch(String search) async {
    if (state.search == search) return;
    state = state.copyWith(
      search: search,
      page: 1,
    );
    await refresh();
  }

  Future<void> changeFilter(String filter) async {
    if (state.filter == filter) return;
    state = state.copyWith(
      filter: filter,
      page: 1,
    );
    await refresh();
  }

  Future<void> previousPage() async {
    if (state.page <= 1) return;
    state = state.copyWith(page: state.page - 1);
    await refresh();
  }

  Future<void> nextPage() async {
    if (state.page >= state.totalPages) return;
    state = state.copyWith(page: state.page + 1);
    await refresh();
  }

  Future<bool> deleteWord(String id) async {
    try {
      await ref.read(studyRepositoryProvider).deleteWord(id);
      unawaited(refresh());
      return true;
    } catch (error, stackTrace) {
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      return false;
    }
  }
}

final wordbookProvider =
    NotifierProvider.autoDispose<WordbookController, WordbookState>(
  WordbookController.new,
);
