import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_account_provider.dart';
import '../../../core/network/api_exception.dart';
import '../data/kana_writing_progress_store.dart';
import '../domain/kana_writing_progress.dart';
import '../domain/katakana_pilot.dart';

class KanaWritingProgressState {
  const KanaWritingProgressState({
    this.progress,
    this.loading = true,
    this.busy = false,
    this.error,
    this.blocked = false,
  });

  final KanaWritingProgress? progress;
  final bool loading;
  final bool busy;
  final String? error;
  final bool blocked;
  bool get canAct =>
      !loading && !busy && !blocked && error == null && progress != null;
}

class KanaWritingProgressController extends Notifier<KanaWritingProgressState> {
  KanaWritingProgressController(this.scope);

  final KanaWritingScope scope;
  int _generation = 0;
  bool _running = false;
  String? _raw;
  KanaWritingProgress? _pending;

  @override
  KanaWritingProgressState build() {
    ref.watch(currentAccountIdProvider);
    ref.watch(kanaWritingProgressStoreProvider);
    _generation++;
    _running = false;
    _raw = null;
    _pending = null;
    ref.onDispose(() => _generation++);
    unawaited(Future<void>.microtask(_load));
    return const KanaWritingProgressState();
  }

  bool _current(int generation) =>
      ref.mounted &&
      generation == _generation &&
      ref.read(currentAccountIdProvider) == scope.owner &&
      ref.read(currentAccountReaderProvider)() == scope.owner;

  Future<void> _load() async {
    final generation = _generation;
    if (!_current(generation) || _running) return;
    _running = true;
    state = KanaWritingProgressState(progress: state.progress);
    try {
      final raw = await ref.read(kanaWritingProgressStoreProvider).read(scope);
      if (!_current(generation)) return;
      final progress = raw == null
          ? KanaWritingProgress(scope: scope)
          : KanaWritingProgress.decode(raw, scope);
      _raw = raw;
      state = KanaWritingProgressState(progress: progress, loading: false);
    } catch (error) {
      if (_current(generation)) _fail(error, reading: true);
    } finally {
      if (_current(generation)) _running = false;
    }
  }

  Future<void> saveSession(KanaWritingSession session) async {
    if (!_current(_generation) || _running || !state.canAct) return;
    final previous = state.progress!;
    await _save(KanaWritingProgress(
        scope: scope,
        completedBasicRows: previous.completedBasicRows,
        session: session));
  }

  Future<void> finishSession({KanaPracticeRow? completedRow}) async {
    if (!_current(_generation) || _running || !state.canAct) return;
    final previous = state.progress!;
    final session = previous.session;
    // Completing a basic row requires its last character's correct word choice.
    // Comparison/review sessions can finish, but never award a row completion.
    if (completedRow != null &&
        (completedRow.section != KanaPracticeSection.basic ||
            session?.row != completedRow ||
            session!.index != session.letters.length - 1 ||
            session.step != KanaWritingStep.word ||
            session.selectedIndex == null ||
            session.letter.word.runes.elementAt(session.selectedIndex!) !=
                session.letter.glyph.runes.single)) {
      return;
    }
    await _save(KanaWritingProgress(scope: scope, completedBasicRows: {
      ...previous.completedBasicRows,
      if (completedRow != null) completedRow,
    }));
  }

  Future<void> _save(KanaWritingProgress next) async {
    final generation = _generation;
    _running = true;
    _pending = next;
    state = KanaWritingProgressState(
        progress: state.progress, loading: false, busy: true);
    try {
      await _persist(generation);
    } catch (error) {
      if (_current(generation)) _fail(error);
    } finally {
      if (_current(generation)) _running = false;
    }
  }

  Future<void> _persist(int generation) async {
    final pending = _pending!;
    final value = pending.encode();
    if (value != _raw) {
      await ref.read(kanaWritingProgressStoreProvider).compareAndSet(scope,
          expected: _raw, value: value, isCurrent: () => _current(generation));
    }
    if (!_current(generation)) return;
    _raw = value;
    _pending = null;
    state = KanaWritingProgressState(progress: pending, loading: false);
  }

  Future<void> retry() async {
    final generation = _generation;
    if (!_current(generation) || _running) return;
    if (_pending == null) return _load();
    if (state.blocked) return;
    _running = true;
    state = KanaWritingProgressState(
        progress: state.progress, loading: false, busy: true);
    try {
      final durable =
          await ref.read(kanaWritingProgressStoreProvider).read(scope);
      if (!_current(generation)) return;
      final intended = _pending!.encode();
      if (durable != _raw && durable != intended) {
        throw const FormatException('Concurrent kana writing checkpoint');
      }
      // The native write may have committed before its ACK was lost.
      if (durable == intended) _raw = durable;
      await _persist(generation);
    } catch (error) {
      if (_current(generation)) _fail(error);
    } finally {
      if (_current(generation)) _running = false;
    }
  }

  void _fail(Object error, {bool reading = false}) {
    final corrupt = error is FormatException;
    final message = ApiException(
            message: corrupt
                ? '저장된 쓰기 위치를 확인하지 못했어요. 기록을 지우지 않고 보관할게요.'
                : reading
                    ? '기기에 저장된 쓰기 위치를 불러오지 못했어요. 다시 시도해 주세요.'
                    : '쓰기 위치를 기기에 저장하지 못했어요. 다시 시도해 주세요.')
        .userMessage;
    state = KanaWritingProgressState(
        progress: state.progress,
        loading: false,
        error: message,
        blocked: corrupt);
  }
}

final kanaWritingProgressProvider = NotifierProvider.autoDispose.family<
    KanaWritingProgressController,
    KanaWritingProgressState,
    KanaWritingScope>(KanaWritingProgressController.new);
