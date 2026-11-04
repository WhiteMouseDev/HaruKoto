import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/shared_preferences_provider.dart';
import '../domain/kana_card_progress.dart';

class KanaCardStorageException implements Exception {
  const KanaCardStorageException();
}

abstract class KanaCardProgressStore {
  Future<String?> read(KanaCardContent content);
  Future<void> compareAndSet(KanaCardContent content,
      {required String? expected, required String value});
}

/// One queue includes reads and writes across accounts/stages. The next cursor
/// replaces the ACKed action atomically; this namespace never deletes auth,
/// learning history, or the only pending action ID.
class PreferencesKanaCardProgressStore implements KanaCardProgressStore {
  PreferencesKanaCardProgressStore(this.preferences)
      : _serial = _queues[preferences] ??= _KanaCardWriteQueue();
  final SharedPreferences preferences;
  final _KanaCardWriteQueue _serial;
  static final _queues = Expando<_KanaCardWriteQueue>();

  static String key(String owner, String stageId) =>
      'kana_card_progress.v1.${Uri.encodeComponent(owner)}.${Uri.encodeComponent(stageId)}';

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = _serial.tail.then((_) => operation());
    _serial.tail =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  @override
  Future<String?> read(KanaCardContent content) => _serialized(() async {
        await preferences.reload();
        return preferences.getString(key(content.owner, content.stageId));
      });

  @override
  Future<void> compareAndSet(KanaCardContent content,
          {required String? expected, required String value}) =>
      _serialized(() async {
        final journal = KanaCardJournal.decode(value);
        final previous =
            expected == null ? null : KanaCardJournal.decode(expected);
        if (value.length > 64 * 1024 ||
            journal.content != content ||
            (previous != null && previous.content != content)) {
          throw const KanaCardStorageException();
        }
        await preferences.reload();
        final name = key(content.owner, content.stageId);
        if (preferences.getString(name) != expected) {
          throw const KanaCardStorageException();
        }
        try {
          if (!await preferences.setString(name, value)) {
            throw const KanaCardStorageException();
          }
        } catch (_) {
          // SharedPreferences updates its in-memory cache before native storage
          // acknowledges the write. Never recover from an unconfirmed cache value.
          await preferences.reload();
          throw const KanaCardStorageException();
        }
      });
}

final kanaCardProgressStoreProvider = Provider<KanaCardProgressStore>((ref) =>
    PreferencesKanaCardProgressStore(ref.watch(sharedPreferencesProvider)));

class _KanaCardWriteQueue {
  Future<void> tail = Future<void>.value();
}
