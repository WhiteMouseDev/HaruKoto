import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/shared_preferences_provider.dart';
import '../data/models/conversation_journey_episode.dart';

final conversationJourneyProgressStoreProvider =
    Provider<ConversationJourneyProgressStore>((ref) =>
        ConversationJourneyProgressStore(ref.watch(sharedPreferencesProvider)));

final conversationJourneyProgressProvider = FutureProvider.autoDispose
    .family<Set<String>, String>((ref, accountId) =>
        ref.watch(conversationJourneyProgressStoreProvider).load(accountId));

/// Device-local progress. A mark means an audio practice was saved.
class ConversationJourneyProgressStore {
  ConversationJourneyProgressStore(this._preferences);

  final SharedPreferences _preferences;
  Future<void> _pending = Future<void>.value();

  static String _key(String accountId) =>
      'conversation_journey.tokyo_first_day.v1.${Uri.encodeComponent(accountId)}';

  Future<Set<String>> load(String accountId) => _serialize(() async {
        await _preferences.reload();
        return _read(accountId);
      });

  Future<bool> markPracticed(
    String accountId,
    String scenarioId, {
    required bool Function() isCurrentAccount,
  }) =>
      _serialize(() async {
        if (!isTokyoFirstDayScenario(scenarioId) || !isCurrentAccount()) {
          return false;
        }
        await _preferences.reload();
        if (!isCurrentAccount()) return false;
        final practiced = _read(accountId);
        if (practiced.contains(scenarioId)) return false;
        if (!await _preferences
            .setStringList(_key(accountId), [...practiced, scenarioId])) {
          throw StateError('Unconfirmed journey progress write');
        }
        return true;
      });

  Set<String> _read(String accountId) {
    final raw = _preferences.get(_key(accountId));
    if (raw is! List<String>) return const {};
    return Set.unmodifiable(raw.where(isTokyoFirstDayScenario));
  }

  Future<T> _serialize<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }
}
