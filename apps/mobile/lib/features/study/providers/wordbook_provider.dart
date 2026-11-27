import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../core/auth/current_account_provider.dart';
import '../data/models/wordbook_entry_model.dart';
import 'study_provider.dart';

class WordbookState {
  const WordbookState({
    this.loading = true,
    this.entries = const [],
    this.total = 0,
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
  final int total;
  final int totalPages;
  final int page;
  final String sort;
  final String search;
  final String filter;
  final String? error;

  WordbookState copyWith({
    bool? loading,
    List<WordbookEntryModel>? entries,
    int? total,
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
      total: total ?? this.total,
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
    ref.onDispose(() => _requestSerial++);
    return const WordbookState();
  }

  Future<void> refresh() async {
    final requestId = ++_requestSerial;
    final owner = ref.read(currentAccountReaderProvider)();
    var page = state.page;
    final sort = state.sort;
    final search = state.search;
    final filter = state.filter;

    state = state.copyWith(
      loading: true,
      error: null,
    );

    try {
      final repository = ref.read(studyRepositoryProvider);
      while (true) {
        final data = await repository.fetchWordbook(
          page: page,
          sort: sort,
          search: search,
          filter: filter,
        );
        if (!_isCurrent(requestId, owner)) return;
        final lastPage = math.max(1, data.totalPages);
        if (data.total > 0 &&
            page > 1 &&
            (page > lastPage || data.entries.isEmpty)) {
          // The count and page rows may reflect different versions of the
          // list. Retry a lower page with the same query before publishing it.
          page = math.min(page - 1, lastPage);
          continue;
        }
        state = state.copyWith(
          loading: false,
          page: data.total == 0 ? 1 : page,
          entries: data.entries,
          total: data.total,
          totalPages: data.totalPages,
        );
        return;
      }
    } catch (error, stackTrace) {
      if (!_isCurrent(requestId, owner)) return;
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      state = state.copyWith(
        loading: false,
        error: '단어장을 불러올 수 없습니다.',
      );
    }
  }

  bool _isCurrent(int requestId, String? owner) =>
      requestId == _requestSerial && _isCurrentOwner(owner);

  bool _isCurrentOwner(String? owner) =>
      ref.mounted && ref.read(currentAccountReaderProvider)() == owner;

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

  Future<void> changeSort(String sort, {String? search}) async {
    if (state.sort == sort) return;
    state = state.copyWith(sort: sort, search: search, page: 1);
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
    final owner = ref.read(currentAccountReaderProvider)();
    if (owner == null) return false;
    try {
      await ref.read(studyRepositoryProvider).deleteWord(id);
      if (!_isCurrentOwner(owner)) return false;
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
