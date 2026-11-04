import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_account_provider.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers/shared_preferences_provider.dart';
import '../../../core/providers/study_clock_provider.dart';
import '../domain/katakana_pilot.dart';

final katakanaPilotLocalDayProvider =
    NotifierProvider.autoDispose<KatakanaPilotLocalDay, DateTime>(
  KatakanaPilotLocalDay.new,
);

class KatakanaPilotLocalDay extends Notifier<DateTime> {
  Timer? _midnightTimer;

  @override
  DateTime build() {
    ref.onDispose(() => _midnightTimer?.cancel());
    return _readDay(ref.watch(studyClockProvider)());
  }

  /// Refresh on resume, when the device may have suspended timers.
  void refresh() {
    final day = _readDay(ref.read(studyClockProvider)());
    if (day != state) state = day;
  }

  DateTime _readDay(DateTime instant) {
    final local = instant.toLocal();
    final tomorrow = DateTime(local.year, local.month, local.day + 1);
    _midnightTimer?.cancel();
    _midnightTimer = Timer(tomorrow.difference(local), refresh);
    return DateTime(local.year, local.month, local.day);
  }
}

int _dayKey(DateTime day) => day.year * 10000 + day.month * 100 + day.day;

class KatakanaPilotReviewState {
  const KatakanaPilotReviewState._(this.marked, this._deferredThrough);

  final Set<KatakanaPilotLetter> marked;
  final Map<KatakanaPilotLetter, int> _deferredThrough;

  Set<KatakanaPilotLetter> dueOn(DateTime day) {
    final key = _dayKey(day);
    return Set.unmodifiable(marked.where(
      // Legacy marks have no day metadata and are eligible immediately.
      (letter) => (_deferredThrough[letter] ?? 0) < key,
    ));
  }
}

final katakanaPilotReviewProvider =
    AsyncNotifierProvider<KatakanaPilotReview, KatakanaPilotReviewState>(
  KatakanaPilotReview.new,
);

class KatakanaPilotReview extends AsyncNotifier<KatakanaPilotReviewState> {
  String? _owner;
  int _generation = 0;
  Future<void> _writes = Future<void>.value();

  static String _key(String owner, KatakanaPilotLetter letter) =>
      'katakana_pilot_review.v1.${Uri.encodeComponent(owner)}.${letter.name}';

  static String _dayStorageKey(String owner, KatakanaPilotLetter letter) =>
      'katakana_pilot_review.day.v1.${Uri.encodeComponent(owner)}.${letter.name}';

  @override
  Future<KatakanaPilotReviewState> build() async {
    final owner = ref.watch(currentAccountIdProvider);
    _owner = owner;
    _generation++;
    if (owner == null) return const KatakanaPilotReviewState._({}, {});
    final preferences = ref.watch(sharedPreferencesProvider);
    // A failed legacy SharedPreferences write may have changed its SDK cache.
    // Reload the persisted values before displaying another account or retrying.
    await _writes;
    try {
      await preferences.reload();
    } catch (_) {
      throw const ApiException(message: '기기에 저장된 복습 목록을 불러오지 못했어요.');
    }
    final marked = <KatakanaPilotLetter>{};
    final deferredThrough = <KatakanaPilotLetter, int>{};
    for (final letter in KatakanaPilotLetter.values) {
      if (preferences.get(_key(owner, letter)) != true) continue;
      marked.add(letter);
      final day = preferences.get(_dayStorageKey(owner, letter));
      if (day is int) deferredThrough[letter] = day;
    }
    return KatakanaPilotReviewState._(
      Set.unmodifiable(marked),
      Map.unmodifiable(deferredThrough),
    );
  }

  void _requireCurrent(String owner, int generation) {
    if (!ref.mounted ||
        _owner != owner ||
        _generation != generation ||
        ref.read(currentAccountReaderProvider)() != owner) {
      throw const ApiException(message: '현재 로그인한 계정을 확인한 뒤 다시 시도해 주세요.');
    }
  }

  Future<void> setMarked(KatakanaPilotLetter letter, bool marked) {
    final preferences = ref.read(sharedPreferencesProvider);
    final day = _dayKey(ref.read(studyClockProvider)().toLocal());
    return _update((owner, previous) async {
      if (previous.marked.contains(letter) == marked) return previous;
      // Write the day first. A failed flag write leaves an unmarked glyph,
      // which ignores any day metadata until a new mark saves it again.
      if (marked &&
          !await preferences.setInt(_dayStorageKey(owner, letter), day)) {
        throw StateError('Unconfirmed local write');
      }
      if (!await preferences.setBool(_key(owner, letter), marked)) {
        throw StateError('Unconfirmed local write');
      }
      final nextMarked = {...previous.marked};
      final deferredThrough = {...previous._deferredThrough};
      if (marked) {
        nextMarked.add(letter);
        deferredThrough[letter] = day;
      } else {
        nextMarked.remove(letter);
        deferredThrough.remove(letter);
      }
      return KatakanaPilotReviewState._(
        Set.unmodifiable(nextMarked),
        Map.unmodifiable(deferredThrough),
      );
    });
  }

  Future<void> completeDailyReview(KatakanaPilotLetter letter, DateTime day) {
    final preferences = ref.read(sharedPreferencesProvider);
    return _update((owner, previous) async {
      if (!previous.dueOn(day).contains(letter)) return previous;
      final key = _dayKey(day);
      if (!await preferences.setInt(_dayStorageKey(owner, letter), key)) {
        throw StateError('Unconfirmed local write');
      }
      return KatakanaPilotReviewState._(
        previous.marked,
        Map.unmodifiable({...previous._deferredThrough, letter: key}),
      );
    });
  }

  Future<void> _update(
    Future<KatakanaPilotReviewState> Function(
      String owner,
      KatakanaPilotReviewState previous,
    ) update,
  ) async {
    final owner = _owner;
    final generation = _generation;
    if (owner == null) {
      throw const ApiException(message: '로그인하면 헷갈린 글자를 기기에 저장할 수 있어요.');
    }
    _requireCurrent(owner, generation);
    if (state.isLoading || state.hasError || !state.hasValue) {
      throw const ApiException(message: '복습 목록을 먼저 불러와 주세요.');
    }
    final write = _writes.then((_) async {
      _requireCurrent(owner, generation);
      final KatakanaPilotReviewState next;
      try {
        next = await update(owner, state.requireValue);
      } catch (_) {
        throw const ApiException(message: '기기에 저장하지 못했어요. 다시 시도해 주세요.');
      }
      _requireCurrent(owner, generation);
      state = AsyncData(next);
    });
    _writes = write.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    await write;
  }
}
