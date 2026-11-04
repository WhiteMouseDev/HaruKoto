import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_account_provider.dart';
import '../../../core/network/api_exception.dart';
import '../../home/providers/study_activity_refresh_provider.dart';
import '../data/kana_card_progress_store.dart';
import '../domain/kana_card_progress.dart';
import 'kana_provider.dart';

final kanaCardActivityIdProvider =
    Provider<String Function()>((ref) => newKanaCardActivityId);

class KanaCardProgressState {
  const KanaCardProgressState(
      {this.journal,
      this.loading = true,
      this.busy = false,
      this.error,
      this.blocked = false,
      this.restored = false});
  final KanaCardJournal? journal;
  final bool loading;
  final bool busy;
  final String? error;
  final bool blocked;
  final bool restored;
  bool get canAct =>
      !loading &&
      !busy &&
      !blocked &&
      error == null &&
      journal != null &&
      journal?.pending == null;
}

class KanaCardProgressController extends Notifier<KanaCardProgressState> {
  KanaCardProgressController(this.content);
  final KanaCardContent content;
  int _generation = 0;
  String? _raw;
  KanaCardJournal? _journal;
  CancelToken? _cancel;
  bool _running = false;

  @override
  KanaCardProgressState build() {
    ref.watch(currentAccountIdProvider);
    ref.watch(kanaCardProgressStoreProvider);
    _generation++;
    _cancel?.cancel();
    _cancel = CancelToken();
    _raw = null;
    _journal = null;
    _running = false;
    ref.onDispose(() {
      _generation++;
      _cancel?.cancel();
    });
    unawaited(Future<void>.microtask(_load));
    return const KanaCardProgressState();
  }

  bool _current(int generation) =>
      ref.mounted &&
      generation == _generation &&
      ref.read(currentAccountIdProvider) == content.owner &&
      ref.read(currentAccountReaderProvider)() == content.owner;

  Future<void> _load() async {
    final generation = _generation;
    if (!_current(generation) || _running) return;
    _running = true;
    state = KanaCardProgressState(
        journal: state.journal, loading: true, restored: state.restored);
    try {
      final raw = await ref.read(kanaCardProgressStoreProvider).read(content);
      if (!_current(generation)) return;
      final journal = raw == null
          ? KanaCardJournal(
              content: content,
              cursor: const KanaCardCursor(KanaCardPhase.intro, 0))
          : KanaCardJournal.decode(raw);
      _validateContent(journal);
      _raw = raw;
      _journal = journal;
      state = KanaCardProgressState(
          journal: journal,
          loading: false,
          restored: raw != null,
          error: journal.pending != null && journal.receipt == null
              ? const ApiException(
                      message: '저장 중이던 문자 학습이 있어요. 같은 기록으로 저장을 확인해 주세요.')
                  .userMessage
              : null);
      // A durable ACK authorizes only local cursor recovery, never another POST.
      if (journal.receipt != null) {
        state = KanaCardProgressState(
            journal: journal, loading: false, busy: true, restored: true);
        await _drive(generation);
      }
    } catch (error) {
      if (_current(generation)) _fail(error, blocked: error is FormatException);
    } finally {
      if (_current(generation)) _running = false;
    }
  }

  void _validateContent(KanaCardJournal journal) {
    if (journal.content != content) {
      throw const FormatException(
          'Kana content changed; preserve saved activity');
    }
  }

  Future<void> saveAndAdvance({KanaCardCursor? expectedCursor}) async {
    final generation = _generation;
    if (!_current(generation) ||
        _running ||
        !state.canAct ||
        (expectedCursor != null && expectedCursor != _journal?.cursor) ||
        _journal?.cursor.phase == KanaCardPhase.quiz) {
      return;
    }
    _running = true;
    try {
      _journal = _journal!.prepare(ref.read(kanaCardActivityIdProvider)());
      state = KanaCardProgressState(
          journal: state.journal,
          loading: false,
          busy: true,
          restored: state.restored);
      await _drive(generation);
    } catch (error) {
      if (_current(generation)) _fail(error);
    } finally {
      if (_current(generation)) _running = false;
    }
  }

  Future<void> skipPractice({KanaCardCursor? expectedCursor}) async {
    final generation = _generation;
    if (!_current(generation) ||
        _running ||
        !state.canAct ||
        (expectedCursor != null && expectedCursor != _journal?.cursor) ||
        _journal?.cursor.phase != KanaCardPhase.practice) {
      return;
    }
    _running = true;
    try {
      _journal = _journal!.advance();
      state = KanaCardProgressState(
          journal: state.journal,
          loading: false,
          busy: true,
          restored: state.restored);
      await _drive(generation);
    } catch (error) {
      if (_current(generation)) _fail(error);
    } finally {
      if (_current(generation)) _running = false;
    }
  }

  Future<void> retry() async {
    if (!_current(_generation) || _running || state.blocked) return;
    if (_journal == null) return _load();
    final generation = _generation;
    _running = true;
    state = KanaCardProgressState(
        journal: state.journal,
        loading: false,
        busy: true,
        restored: state.restored);
    try {
      // A native write can commit before its result is lost. Re-read durable
      // state before repeating a CAS, retaining an unpersisted action in memory.
      final raw = await ref.read(kanaCardProgressStoreProvider).read(content);
      if (!_current(generation)) return;
      if (raw != _raw) {
        if (raw == null) {
          throw const FormatException('Kana journal disappeared');
        }
        final saved = KanaCardJournal.decode(raw);
        _validateContent(saved);
        final id = _journal?.pending?.activityId;
        if (id != null &&
            saved.pending?.activityId != id &&
            saved.lastReceipt?.activityId != id) {
          throw const FormatException('Concurrent kana activity conflict');
        }
        _raw = raw;
        _journal = saved;
      }
      await _drive(generation);
    } catch (error) {
      if (_current(generation)) _fail(error, blocked: error is FormatException);
    } finally {
      if (_current(generation)) _running = false;
    }
  }

  Future<void> _persist(int generation) async {
    final value = _journal!.encode();
    if (value == _raw) return;
    await ref
        .read(kanaCardProgressStoreProvider)
        .compareAndSet(content, expected: _raw, value: value);
    if (!_current(generation)) return;
    _raw = value;
  }

  Future<void> _drive(int generation) async {
    await _persist(generation);
    if (!_current(generation)) return;
    final pending = _journal!.pending;
    if (pending != null && _journal!.receipt == null) {
      final receipt = await ref
          .read(kanaRepositoryProvider)
          .submitCardProgress(pending, cancelToken: _cancel);
      if (!_current(generation)) return;
      _journal = _journal!.acknowledge(receipt);
      await _persist(generation);
      if (!_current(generation)) return;
    }
    if (_journal!.receipt != null) {
      ref.read(studyActivityRefreshProvider).refresh();
      ref.invalidate(kanaProgressProvider);
      _journal = _journal!.advance();
      await _persist(generation);
      if (!_current(generation)) return;
    }
    state = KanaCardProgressState(
        journal: _journal, loading: false, restored: state.restored);
  }

  Future<void> restartCards() async {
    final generation = _generation;
    if (!_current(generation) ||
        _running ||
        !state.canAct ||
        _journal?.cursor.phase != KanaCardPhase.quiz) {
      return;
    }
    _running = true;
    state = KanaCardProgressState(
        journal: state.journal,
        loading: false,
        busy: true,
        restored: state.restored);
    try {
      _journal = KanaCardJournal(
          content: content,
          cursor: const KanaCardCursor(KanaCardPhase.intro, 0));
      await _persist(generation);
      if (_current(generation)) {
        state = KanaCardProgressState(journal: _journal, loading: false);
      }
    } catch (error) {
      if (_current(generation)) _fail(error);
    } finally {
      if (_current(generation)) _running = false;
    }
  }

  void _fail(Object error, {bool blocked = false}) {
    final message = error is ApiException
        ? error.userMessage
        : error is DioException
            ? ApiException.fromDioException(error).userMessage
            : const ApiException(
                    message: '기기에 저장된 학습 위치를 확인하지 못했어요. 기록은 지우지 않고 보관할게요.')
                .userMessage;
    state = KanaCardProgressState(
        journal: state.journal,
        loading: false,
        error: message,
        blocked: blocked,
        restored: state.restored);
  }
}

final kanaCardProgressProvider = NotifierProvider.autoDispose
    .family<KanaCardProgressController, KanaCardProgressState, KanaCardContent>(
  (content) => KanaCardProgressController(content),
);
