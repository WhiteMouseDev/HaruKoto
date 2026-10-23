import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_account_provider.dart';
import '../data/lesson_checkpoint_store.dart';
import '../domain/saved_lesson_entry.dart';
import 'study_provider.dart';

typedef SavedLessonKey = ({String accountId, String lessonId});

class SavedLessonLookup {
  const SavedLessonLookup({this.hint, this.failed = false});
  final SavedLessonHint? hint;
  final bool failed;
}

/// Only known lesson IDs are read. No preference-key enumeration or detail GETs.
/// Per-lesson caching also avoids rereading every draft after one card changes.
final savedLessonLookupProvider = FutureProvider.autoDispose
    .family<SavedLessonLookup, SavedLessonKey>((ref, key) async {
  final account = ref.watch(currentAccountIdProvider);
  if (account != key.accountId ||
      ref.read(currentAccountReaderProvider)() != key.accountId) {
    return const SavedLessonLookup();
  }
  try {
    final raw = await ref
        .read(lessonCheckpointStoreProvider)
        .read(key.accountId, key.lessonId);
    if (!ref.mounted ||
        ref.read(currentAccountReaderProvider)() != key.accountId) {
      return const SavedLessonLookup();
    }
    return SavedLessonLookup(
        hint: raw == null ? null : SavedLessonHint.inspect(raw, key.lessonId));
  } catch (_) {
    return const SavedLessonLookup(failed: true);
  }
});

final savedLessonEntriesProvider = FutureProvider.autoDispose
    .family<SavedLessonEntries, String>((ref, jlptLevel) async {
  final owner = ref.watch(currentAccountIdProvider);
  if (owner == null || ref.read(currentAccountReaderProvider)() != owner) {
    return const SavedLessonEntries();
  }
  final chapters = await ref.watch(chaptersProvider(jlptLevel).future);
  if (!ref.mounted || ref.read(currentAccountReaderProvider)() != owner) {
    return const SavedLessonEntries();
  }
  final seen = <String>{};
  final targets = [
    for (final chapter in chapters.chapters)
      if (chapter.jlptLevel == jlptLevel)
        for (final lesson in chapter.lessons)
          if (lesson.id.isNotEmpty && seen.add(lesson.id))
            (chapter: chapter, lesson: lesson),
  ];
  final lookups = await Future.wait([
    for (final target in targets)
      ref.watch(savedLessonLookupProvider(
          (accountId: owner, lessonId: target.lesson.id)).future),
  ]);
  if (!ref.mounted || ref.read(currentAccountReaderProvider)() != owner) {
    return const SavedLessonEntries();
  }
  return SavedLessonEntries(
    accountId: owner,
    jlptLevel: jlptLevel,
    entries: [
      for (var i = 0; i < targets.length; i++)
        if (lookups[i].hint != null)
          SavedLessonEntry(
              accountId: owner,
              jlptLevel: jlptLevel,
              chapter: targets[i].chapter,
              lesson: targets[i].lesson,
              hint: lookups[i].hint!),
    ],
    failedLessonIds: [
      for (var i = 0; i < targets.length; i++)
        if (lookups[i].failed) targets[i].lesson.id,
    ],
  );
});
