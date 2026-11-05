import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/shared_preferences_provider.dart';
import '../domain/kana_writing_progress.dart';

class KanaWritingStorageException implements Exception {
  const KanaWritingStorageException();
}

abstract class KanaWritingProgressStore {
  Future<String?> read(KanaWritingScope scope);
  Future<void> compareAndSet(KanaWritingScope scope,
      {required String? expected,
      required String value,
      required bool Function() isCurrent});
}

/// New namespace only: existing review flags and server activity journals are
/// never migrated, cleared, or interpreted as completed writing rows.
class PreferencesKanaWritingProgressStore implements KanaWritingProgressStore {
  PreferencesKanaWritingProgressStore(this.preferences)
      : _queue = _queues[preferences] ??= _WritingQueue();

  final SharedPreferences preferences;
  final _WritingQueue _queue;
  static final _queues = Expando<_WritingQueue>();

  static String key(KanaWritingScope scope) =>
      'kana_writing_progress.v1.${Uri.encodeComponent(scope.owner)}.${scope.script}';

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _queue.tail.then((_) => operation());
    _queue.tail =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  String? _raw(KanaWritingScope scope) {
    final value = preferences.get(key(scope));
    if (value != null && value is! String) {
      throw const FormatException('Invalid kana writing storage');
    }
    return value as String?;
  }

  @override
  Future<String?> read(KanaWritingScope scope) => _serial(() async {
        await preferences.reload();
        return _raw(scope);
      });

  @override
  Future<void> compareAndSet(KanaWritingScope scope,
          {required String? expected,
          required String value,
          required bool Function() isCurrent}) =>
      _serial(() async {
        KanaWritingProgress.decode(value, scope);
        if (expected != null) KanaWritingProgress.decode(expected, scope);
        await preferences.reload();
        if (!isCurrent() || _raw(scope) != expected) {
          throw const KanaWritingStorageException();
        }
        try {
          if (!await preferences.setString(key(scope), value)) {
            throw const KanaWritingStorageException();
          }
        } catch (_) {
          // The legacy SDK mutates its cache before the native write ACK.
          await preferences.reload();
          throw const KanaWritingStorageException();
        }
      });
}

class _WritingQueue {
  Future<void> tail = Future<void>.value();
}

final kanaWritingProgressStoreProvider = Provider<KanaWritingProgressStore>(
    (ref) => PreferencesKanaWritingProgressStore(
        ref.watch(sharedPreferencesProvider)));
