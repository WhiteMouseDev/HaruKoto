import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/shared_preferences_provider.dart';
import '../domain/lesson_study_activity.dart';

abstract class LessonCheckpointStore {
  Future<String?> read(String accountId, String lessonId);
  Future<void> write(String accountId, String lessonId, String value);
  Future<void> remove(String accountId, String lessonId);
  Future<List<String>> listLessonIds(String accountId);
}

/// One queue includes reads and deletion, so an older write cannot resurrect a
/// completed lesson. This namespace never touches auth or preference keys.
class PreferencesLessonCheckpointStore
    implements LessonCheckpointStore, LessonActivityJournalStore {
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
      _serialized(() async {
        final raw = _preferences.getString(key(accountId, lessonId));
        return _journal(raw, accountId, lessonId)?.checkpoint ??
            (_isJournal(raw) ? null : raw);
      });

  @override
  Future<void> write(String accountId, String lessonId, String value) =>
      _serialized(() async {
        final journal = _journal(
            _preferences.getString(key(accountId, lessonId)),
            accountId,
            lessonId);
        await _set(
            accountId,
            lessonId,
            journal == null
                ? value
                : journal.copyWithCheckpoint(value).encode());
      });

  @override
  Future<void> remove(String accountId, String lessonId) =>
      _serialized(() async {
        final journal = _journal(
            _preferences.getString(key(accountId, lessonId)),
            accountId,
            lessonId);
        if (journal != null && journal.activities.isNotEmpty) {
          // Pending receipt requests outlive final submission/checkpoint cleanup.
          await _set(
              accountId,
              lessonId,
              _ActivityJournal(
                      checkpoint: null,
                      activities: journal.activities,
                      owner: accountId,
                      lessonId: lessonId)
                  .encode());
        } else {
          await _remove(accountId, lessonId);
        }
      });

  @override
  Future<List<String>> listLessonIds(String accountId) => _serialized(() async {
        final prefix =
            'lesson_checkpoint.v1.${Uri.encodeComponent(accountId)}.';
        final ids = <String>[];
        for (final candidate in _preferences.getKeys()) {
          if (!candidate.startsWith(prefix)) continue;
          try {
            final id = Uri.decodeComponent(candidate.substring(prefix.length));
            if (id.isNotEmpty) {
              final raw = _preferences.getString(candidate);
              final journal = _journal(raw, accountId, id);
              if (journal == null || journal.checkpoint != null) ids.add(id);
            }
          } on FormatException {
            // A malformed key cannot be attached to another account/lesson.
          }
        }
        return ids;
      });

  Future<void> _set(String owner, String lessonId, String value) async {
    if (value.length > 4 * 1024 * 1024 ||
        !await _preferences.setString(key(owner, lessonId), value)) {
      throw const LessonCheckpointStorageException();
    }
  }

  Future<void> _remove(String owner, String lessonId) async {
    if (!await _preferences.remove(key(owner, lessonId))) {
      throw const LessonCheckpointStorageException();
    }
  }

  @override
  Future<String?> readActivityAttemptId(String owner, String lessonId) =>
      _serialized(() async => _journal(
              _preferences.getString(key(owner, lessonId)), owner, lessonId)
          ?.attemptId);

  @override
  Future<void> writeCheckpointAndActivities(
          String owner,
          String lessonId,
          String checkpoint,
          String attemptId,
          List<LessonStudyActivityDraft> requests) =>
      _serialized(() async {
        final existing = _journal(
            _preferences.getString(key(owner, lessonId)), owner, lessonId);
        final entries = <String, PendingLessonStudyActivity>{
          for (final entry
              in existing?.activities ?? <PendingLessonStudyActivity>[])
            entry.request.activityId: entry,
        };
        for (final request in requests) {
          if (request.owner != owner || request.attemptId != attemptId) {
            throw const LessonCheckpointStorageException();
          }
          final old = entries[request.activityId];
          if (old != null &&
              jsonEncode(old.request.toJson()) !=
                  jsonEncode(request.toJson())) {
            throw const LessonCheckpointStorageException();
          }
          entries.putIfAbsent(
              request.activityId,
              () => PendingLessonStudyActivity(
                  lessonId: lessonId, request: request));
        }
        await _set(
            owner,
            lessonId,
            _ActivityJournal(
              checkpoint: checkpoint,
              attemptId: attemptId,
              owner: owner,
              lessonId: lessonId,
              activities: entries.values.toList(),
            ).encode());
      });

  @override
  Future<List<PendingLessonStudyActivity>> pendingActivities(String owner) =>
      _serialized(() async {
        final prefix = 'lesson_checkpoint.v1.${Uri.encodeComponent(owner)}.';
        final result = <PendingLessonStudyActivity>[];
        for (final candidate in _preferences.getKeys()) {
          if (!candidate.startsWith(prefix)) continue;
          final lessonId =
              Uri.decodeComponent(candidate.substring(prefix.length));
          final journal =
              _journal(_preferences.getString(candidate), owner, lessonId);
          if (journal != null) result.addAll(journal.activities);
        }
        return result;
      });

  @override
  Future<void> markActivityAttempted(
          String owner, String lessonId, String activityId) =>
      _serialized(() async {
        final journal = _journal(
            _preferences.getString(key(owner, lessonId)), owner, lessonId);
        if (journal == null) return;
        await _set(
            owner,
            lessonId,
            journal.copyWithActivities([
              for (final entry in journal.activities)
                if (entry.request.activityId == activityId)
                  PendingLessonStudyActivity(
                      lessonId: lessonId,
                      request: entry.request,
                      attempted: true)
                else
                  entry,
            ]).encode());
      });

  @override
  Future<void> acknowledgeActivity(
          String owner, String lessonId, String activityId) =>
      _serialized(() async {
        final journal = _journal(
            _preferences.getString(key(owner, lessonId)), owner, lessonId);
        if (journal == null) return;
        final remaining = journal.activities
            .where((entry) => entry.request.activityId != activityId)
            .toList();
        if (remaining.length == journal.activities.length) return;
        if (remaining.isEmpty && journal.checkpoint == null) {
          await _remove(owner, lessonId);
        } else {
          await _set(
              owner, lessonId, journal.copyWithActivities(remaining).encode());
        }
      });
}

// v1/v2 inner records remain byte-for-byte compatible. Version 3 is a storage
// wrapper, not a new graded submission protocol. A single preferences write is
// the durable boundary for an answer checkpoint and its immutable activity ID.
class _ActivityJournal {
  const _ActivityJournal(
      {required this.owner,
      required this.lessonId,
      required this.checkpoint,
      required this.activities,
      this.attemptId});
  final String owner;
  final String lessonId;
  final String? checkpoint;
  final String? attemptId;
  final List<PendingLessonStudyActivity> activities;

  _ActivityJournal copyWithCheckpoint(String value) => _ActivityJournal(
      owner: owner,
      lessonId: lessonId,
      checkpoint: value,
      attemptId: attemptId,
      activities: activities);
  _ActivityJournal copyWithActivities(List<PendingLessonStudyActivity> value) =>
      _ActivityJournal(
          owner: owner,
          lessonId: lessonId,
          checkpoint: checkpoint,
          attemptId: attemptId,
          activities: value);

  String encode() => jsonEncode({
        'version': 3,
        'protocolVersion': 1,
        'owner': owner,
        'lessonId': lessonId,
        'submissionPending': true,
        'acknowledged': false,
        'checkpoint': checkpoint,
        'activityAttemptId': attemptId,
        'activities': [for (final entry in activities) entry.toJson()],
      });
}

bool _isJournal(String? raw) {
  if (raw == null) return false;
  try {
    final value = jsonDecode(raw);
    return value is Map<String, dynamic> && value['version'] == 3;
  } on FormatException {
    return false;
  }
}

_ActivityJournal? _journal(String? raw, String owner, String lessonId) {
  if (!_isJournal(raw)) return null;
  try {
    if (raw!.length > 4 * 1024 * 1024) throw const FormatException();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    if (json['owner'] != owner ||
        json['lessonId'] != lessonId ||
        json['protocolVersion'] != 1 ||
        (json['checkpoint'] != null && json['checkpoint'] is! String) ||
        (json['activityAttemptId'] != null &&
            json['activityAttemptId'] is! String) ||
        json['activities'] is! List) {
      throw const FormatException();
    }
    final ids = <String>{};
    final activities = <PendingLessonStudyActivity>[];
    for (final value in json['activities'] as List) {
      if (value is! Map<String, dynamic> ||
          value['attempted'] is! bool ||
          value['request'] is! Map<String, dynamic>) {
        throw const FormatException();
      }
      final request = LessonStudyActivityDraft.fromJson(
          value['request'] as Map<String, dynamic>);
      if (request.owner != owner || !ids.add(request.activityId)) {
        throw const FormatException();
      }
      activities.add(PendingLessonStudyActivity(
          lessonId: lessonId,
          request: request,
          attempted: value['attempted'] as bool));
    }
    return _ActivityJournal(
        owner: owner,
        lessonId: lessonId,
        checkpoint: json['checkpoint'] as String?,
        attemptId: json['activityAttemptId'] as String?,
        activities: activities);
  } on FormatException {
    throw const LessonCheckpointStorageException();
  }
}

class LessonCheckpointStorageException implements Exception {
  const LessonCheckpointStorageException();
}

final lessonCheckpointStoreProvider = Provider<LessonCheckpointStore>((ref) {
  return PreferencesLessonCheckpointStore(ref.watch(sharedPreferencesProvider));
});

final lessonActivityJournalStoreProvider =
    Provider<LessonActivityJournalStore?>((ref) {
  final store = ref.watch(lessonCheckpointStoreProvider);
  return store is LessonActivityJournalStore
      ? store as LessonActivityJournalStore
      : null;
});
