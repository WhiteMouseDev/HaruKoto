import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/shared_preferences_provider.dart';

abstract class LessonCheckpointStore {
  Future<String?> read(String accountId, String lessonId);
  Future<void> write(String accountId, String lessonId, String value);
  Future<void> remove(String accountId, String lessonId);
}

/// One queue includes reads and deletion, so an older write cannot resurrect a
/// completed lesson. This namespace never touches auth or preference keys.
class PreferencesLessonCheckpointStore implements LessonCheckpointStore {
  PreferencesLessonCheckpointStore(this._preferences);

  final SharedPreferences _preferences;
  Future<void> _queue = Future<void>.value();

  static String key(String accountId, String lessonId) =>
      'lesson_checkpoint.v1.${Uri.encodeComponent(accountId)}.'
      '${Uri.encodeComponent(lessonId)}';

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  @override
  Future<String?> read(String accountId, String lessonId) =>
      _serialized(() async => _preferences.getString(key(accountId, lessonId)));

  @override
  Future<void> write(String accountId, String lessonId, String value) =>
      _serialized(() async {
        if (!await _preferences.setString(key(accountId, lessonId), value)) {
          throw const LessonCheckpointStorageException();
        }
      });

  @override
  Future<void> remove(String accountId, String lessonId) =>
      _serialized(() async {
        if (!await _preferences.remove(key(accountId, lessonId))) {
          throw const LessonCheckpointStorageException();
        }
      });
}

class LessonCheckpointStorageException implements Exception {
  const LessonCheckpointStorageException();
}

final lessonCheckpointStoreProvider = Provider<LessonCheckpointStore>((ref) {
  return PreferencesLessonCheckpointStore(ref.watch(sharedPreferencesProvider));
});
