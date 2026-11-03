import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_account_provider.dart';
import '../../../core/network/api_exception.dart';
import '../data/models/saved_quiz_model.dart';
import 'study_provider.dart';

ApiException savedQuizLoadError(Object? cause) => cause is DioException
    ? ApiException.fromDioException(cause)
    : cause is ApiException
        ? cause
        : const ApiException(message: '저장된 퀴즈를 불러오지 못했어요.');

class SavedQuizListState {
  const SavedQuizListState({
    required this.accountId,
    required this.sessions,
    this.nextCursor,
    this.legacyFallback = false,
    this.loadingMore = false,
    this.refreshing = false,
    this.error,
    this.errorOnRefresh = false,
  });

  final String? accountId;
  final List<SavedQuizModel> sessions;
  final String? nextCursor;
  final bool legacyFallback;
  final bool loadingMore;
  final bool refreshing;
  final ApiException? error;
  final bool errorOnRefresh;

  SavedQuizListState pending({bool refresh = false}) => SavedQuizListState(
        accountId: accountId,
        sessions: sessions,
        nextCursor: nextCursor,
        legacyFallback: legacyFallback,
        loadingMore: !refresh,
        refreshing: refresh,
      );

  SavedQuizListState failed(Object cause, {required bool refresh}) =>
      SavedQuizListState(
        accountId: accountId,
        sessions: sessions,
        nextCursor: nextCursor,
        legacyFallback: legacyFallback,
        errorOnRefresh: refresh,
        error: savedQuizLoadError(cause),
      );
}

final savedQuizListProvider =
    AsyncNotifierProvider.autoDispose<SavedQuizList, SavedQuizListState>(
        SavedQuizList.new);

class SavedQuizList extends AsyncNotifier<SavedQuizListState> {
  int _revision = 0;

  @override
  Future<SavedQuizListState> build() async {
    final revision = ++_revision;
    final owner = ref.watch(currentAccountIdProvider);
    final repository = ref.watch(studyRepositoryProvider);
    if (owner == null) {
      return const SavedQuizListState(accountId: null, sessions: []);
    }
    if (!_current(owner, revision)) throw const _AccountChanged();
    final page = await repository.fetchIncompleteQuizzes();
    if (!_current(owner, revision)) throw const _AccountChanged();
    return SavedQuizListState(
      accountId: owner,
      sessions: page.sessions,
      nextCursor: page.nextCursor,
      legacyFallback: page.legacyFallback,
    );
  }

  bool _current(String owner, int revision) =>
      ref.mounted &&
      revision == _revision &&
      ref.read(currentAccountIdProvider) == owner &&
      ref.read(currentAccountReaderProvider)() == owner;

  Future<void> refresh() async {
    final previous = state.asData?.value;
    if (previous == null) {
      ref.invalidateSelf();
      return;
    }
    if (previous.refreshing) return;
    await _load(previous, refresh: true);
  }

  Future<void> loadMore() async {
    final previous = state.asData?.value;
    if (previous == null ||
        previous.nextCursor == null ||
        previous.loadingMore ||
        previous.refreshing) {
      return;
    }
    await _load(previous, refresh: false);
  }

  Future<void> _load(SavedQuizListState previous,
      {required bool refresh}) async {
    final owner = previous.accountId;
    if (owner == null || !_current(owner, _revision)) return;
    final revision = ++_revision;
    state = AsyncData(previous.pending(refresh: refresh));
    try {
      final page =
          await ref.read(studyRepositoryProvider).fetchIncompleteQuizzes(
                cursor: refresh ? null : previous.nextCursor,
              );
      if (!_current(owner, revision)) return;
      // Never stop solely because a page is empty. The cursor is authoritative.
      if (!refresh && page.nextCursor == previous.nextCursor) {
        throw const FormatException('Pagination cursor did not advance');
      }
      final seen = <String>{};
      final sessions = [
        if (!refresh) ...previous.sessions,
        ...page.sessions,
      ].where((session) => seen.add(session.id)).toList(growable: false);
      state = AsyncData(SavedQuizListState(
        accountId: owner,
        sessions: sessions,
        nextCursor: page.nextCursor,
        legacyFallback: page.legacyFallback,
      ));
    } catch (error) {
      if (!_current(owner, revision)) return;
      state = AsyncData(previous.failed(error, refresh: refresh));
    }
  }
}

class _AccountChanged implements Exception {
  const _AccountChanged();
}
