import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_account_provider.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers/shared_preferences_provider.dart';
import '../domain/katakana_pilot.dart';

final katakanaPilotReviewProvider =
    AsyncNotifierProvider<KatakanaPilotReview, Set<KatakanaPilotLetter>>(
  KatakanaPilotReview.new,
);

class KatakanaPilotReview extends AsyncNotifier<Set<KatakanaPilotLetter>> {
  String? _owner;
  int _generation = 0;
  Future<void> _writes = Future<void>.value();

  static String _key(String owner, KatakanaPilotLetter letter) =>
      'katakana_pilot_review.v1.${Uri.encodeComponent(owner)}.${letter.name}';

  @override
  Future<Set<KatakanaPilotLetter>> build() async {
    final owner = ref.watch(currentAccountIdProvider);
    _owner = owner;
    _generation++;
    if (owner == null) return const {};
    final preferences = ref.watch(sharedPreferencesProvider);
    // A failed legacy SharedPreferences write may have changed its SDK cache.
    // Reload the persisted values before displaying another account or retrying.
    await _writes;
    try {
      await preferences.reload();
    } catch (_) {
      throw const ApiException(message: '기기에 저장된 복습 목록을 불러오지 못했어요.');
    }
    return Set.unmodifiable(KatakanaPilotLetter.values.where(
      (letter) => preferences.get(_key(owner, letter)) == true,
    ));
  }

  void _requireCurrent(String owner, int generation) {
    if (!ref.mounted ||
        _owner != owner ||
        _generation != generation ||
        ref.read(currentAccountReaderProvider)() != owner) {
      throw const ApiException(message: '현재 로그인한 계정을 확인한 뒤 다시 시도해 주세요.');
    }
  }

  Future<void> setMarked(KatakanaPilotLetter letter, bool marked) async {
    final owner = _owner;
    final generation = _generation;
    if (owner == null) {
      throw const ApiException(message: '로그인하면 헷갈린 글자를 기기에 저장할 수 있어요.');
    }
    _requireCurrent(owner, generation);
    if (state.isLoading || state.hasError || !state.hasValue) {
      throw const ApiException(message: '복습 목록을 먼저 불러와 주세요.');
    }
    final preferences = ref.read(sharedPreferencesProvider);
    final write = _writes.then((_) async {
      _requireCurrent(owner, generation);
      try {
        if (!await preferences.setBool(_key(owner, letter), marked)) {
          throw StateError('Unconfirmed local write');
        }
      } catch (_) {
        throw const ApiException(message: '기기에 저장하지 못했어요. 다시 시도해 주세요.');
      }
      _requireCurrent(owner, generation);
      final next = {...state.requireValue};
      if (marked) {
        next.add(letter);
      } else {
        next.remove(letter);
      }
      state = AsyncData(Set.unmodifiable(next));
    });
    _writes = write.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    await write;
  }
}
