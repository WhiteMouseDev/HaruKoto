import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_account_provider.dart';
import '../../../core/network/api_exception.dart';
import '../../home/providers/home_provider.dart';
import '../../home/providers/study_activity_refresh_provider.dart';
import '../data/lesson_checkpoint_store.dart';
import '../data/lesson_study_activity_repository.dart';

class LessonActivitySyncState {
  const LessonActivitySyncState(
      {this.pendingCount = 0,
      this.syncing = false,
      this.error,
      this.storageError = false});
  final int pendingCount;
  final bool syncing;
  final String? error;
  final bool storageError;
}

/// Kept at account scope so pending requests survive route disposal and final
/// checkpoint removal. Only a validated server receipt authorizes a refresh.
class LessonActivitySyncController extends Notifier<LessonActivitySyncState> {
  String? _owner;
  int _generation = 0;
  Future<void>? _running;
  bool _requested = false;
  CancelToken? _cancel;

  @override
  LessonActivitySyncState build() {
    _cancel?.cancel('Account changed');
    _owner = ref.watch(currentAccountIdProvider);
    ref.watch(lessonActivityJournalStoreProvider);
    _generation++;
    _running = null;
    _requested = false;
    _cancel = CancelToken();
    ref.onDispose(() {
      _generation++;
      _cancel?.cancel('Activity sync disposed');
    });
    if (_owner != null) unawaited(Future<void>.microtask(sync));
    return const LessonActivitySyncState();
  }

  bool _current(int generation, String owner) =>
      ref.mounted &&
      generation == _generation &&
      _owner == owner &&
      ref.read(currentAccountReaderProvider)() == owner;

  Future<void> sync() {
    final owner = _owner;
    if (owner == null || !_current(_generation, owner)) return Future.value();
    _requested = true;
    if (_running != null) return _running!;
    final generation = _generation;
    final operation = _drain(owner, generation);
    _running = operation;
    return operation.whenComplete(() {
      if (_current(generation, owner)) _running = null;
    });
  }

  Future<void> _drain(String owner, int generation) async {
    final store = ref.read(lessonActivityJournalStoreProvider);
    if (store == null) return;
    final failedIds = <String>{};
    String? firstError;
    try {
      do {
        _requested = false;
        final pending = await store.pendingActivities(owner);
        if (!_current(generation, owner)) return;
        state = LessonActivitySyncState(
            pendingCount: pending.length, syncing: pending.isNotEmpty);
        for (final entry in pending) {
          if (!_current(generation, owner)) return;
          if (failedIds.contains(entry.request.activityId)) continue;
          final repository = ref.read(lessonStudyActivityRepositoryProvider);
          try {
            var receipt = entry.attempted
                ? await repository.lookup(
                    entry.lessonId, entry.request.activityId, owner,
                    cancelToken: _cancel)
                : null;
            if (!_current(generation, owner)) return;
            if (receipt == null) {
              // Persist uncertainty BEFORE the first POST. A process death at
              // any later point recovers with GET, then the same frozen POST.
              await store.markActivityAttempted(
                  owner, entry.lessonId, entry.request.activityId);
              if (!_current(generation, owner)) return;
              receipt = await repository.submit(entry.lessonId, entry.request,
                  cancelToken: _cancel);
            }
            if (!_current(generation, owner)) return;
            if (receipt.activityId != entry.request.activityId) {
              throw const FormatException('Activity receipt mismatch');
            }
            await store.acknowledgeActivity(
                owner, entry.lessonId, receipt.activityId);
            if (!_current(generation, owner)) return;
            ref.read(studyActivityRefreshProvider).refresh();
            ref.invalidate(profileProvider);
          } catch (error) {
            if (!_current(generation, owner)) return;
            failedIds.add(entry.request.activityId);
            firstError ??= _message(error);
            // No loop/timer on failure. User retry, a new answer, or app resume
            // can resolve the same ID without repeated error traffic.
            // A changed/deleted lesson must not block another lesson's queue.
          }
        }
        final remaining = await store.pendingActivities(owner);
        if (!_current(generation, owner)) return;
        state = LessonActivitySyncState(
            pendingCount: remaining.length, error: firstError);
      } while (_requested && _current(generation, owner));
    } catch (_) {
      if (_current(generation, owner)) {
        state = const LessonActivitySyncState(
            storageError: true,
            error: '저장된 학습일 요청을 읽지 못했어요. 기록은 지우지 않고 보관할게요.');
      }
    }
  }
}

String _message(Object error) => switch (error) {
      final ApiException value => value.userMessage,
      final DioException value =>
        ApiException.fromDioException(value).userMessage,
      _ => '학습일 저장을 확인하지 못했어요. 같은 답변으로 다시 확인해 주세요.',
    };

final lessonActivitySyncProvider =
    NotifierProvider<LessonActivitySyncController, LessonActivitySyncState>(
        LessonActivitySyncController.new);
