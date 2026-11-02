import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_account_provider.dart';
import '../data/lesson_checkpoint_store.dart';
import '../domain/saved_lesson_entry.dart';
import '../data/models/lesson_models.dart';
import 'study_provider.dart';

typedef SavedLessonKey = ({String accountId, String lessonId});

class SavedLessonLookup {
  const SavedLessonLookup(
      {this.hint, this.failed = false, this.recoveryTitle, this.recoveryLevel});
  final SavedLessonHint? hint;
  final bool failed;
  final String? recoveryTitle;
  final String? recoveryLevel;
}

/// Account-scoped keys are also inspected for receipts whose content was removed.
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
    final hint =
        raw == null ? null : SavedLessonHint.inspect(raw, key.lessonId);
    Map<String, dynamic>? metadata;
    if (hint?.submissionReceipt == true && raw!.length <= 512 * 1024) {
      try {
        metadata = jsonDecode(raw) as Map<String, dynamic>;
      } on FormatException {/* The hint remains fail-closed. */}
    }
    return SavedLessonLookup(
        hint: hint,
        recoveryTitle:
            metadata?['title'] is String ? metadata!['title'] as String : null,
        recoveryLevel: metadata?['jlptLevel'] is String
            ? metadata!['jlptLevel'] as String
            : null);
  } catch (_) {
    return const SavedLessonLookup(failed: true);
  }
});

final savedSubmissionIdsProvider =
    FutureProvider.autoDispose.family<List<String>, String>((ref, owner) async {
  if (ref.watch(currentAccountIdProvider) != owner ||
      ref.read(currentAccountReaderProvider)() != owner) {
    return const [];
  }
  final ids =
      await ref.read(lessonCheckpointStoreProvider).listLessonIds(owner);
  if (!ref.mounted || ref.read(currentAccountReaderProvider)() != owner) {
    return const [];
  }
  return ids;
});

final savedLessonEntriesProvider = FutureProvider.autoDispose
    .family<SavedLessonEntries, String>((ref, jlptLevel) async {
  final owner = ref.watch(currentAccountIdProvider);
  if (owner == null || ref.read(currentAccountReaderProvider)() != owner) {
    return const SavedLessonEntries();
  }
  ChapterListModel chapters;
  Object? chapterError;
  StackTrace? chapterStack;
  try {
    chapters = await ref.watch(chaptersProvider(jlptLevel).future);
  } catch (error, stack) {
    chapterError = error;
    chapterStack = stack;
    chapters = const ChapterListModel(chapters: []);
  }
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
  var scanFailed = false;
  List<String> savedIds;
  try {
    savedIds = await ref.watch(savedSubmissionIdsProvider(owner).future);
  } catch (_) {
    savedIds = const [];
    scanFailed = true;
  }
  final unlistedIds = savedIds.where((id) => !seen.contains(id)).toList();
  final orphanLookups = await Future.wait([
    for (final id in unlistedIds)
      ref.watch(
          savedLessonLookupProvider((accountId: owner, lessonId: id)).future),
  ]);
  final lookups = await Future.wait([
    for (final target in targets)
      ref.watch(savedLessonLookupProvider(
          (accountId: owner, lessonId: target.lesson.id)).future),
  ]);
  if (!ref.mounted || ref.read(currentAccountReaderProvider)() != owner) {
    return const SavedLessonEntries();
  }
  final entries = [
    for (var i = 0; i < targets.length; i++)
      if (lookups[i].hint != null)
        SavedLessonEntry(
            accountId: owner,
            jlptLevel: jlptLevel,
            chapter: targets[i].chapter,
            lesson: targets[i].lesson,
            hint: lookups[i].hint!),
  ];
  for (var i = 0; i < unlistedIds.length; i++) {
    final lookup = orphanLookups[i];
    if (lookup.hint?.submissionReceipt != true ||
        (lookup.recoveryLevel != null && lookup.recoveryLevel != jlptLevel)) {
      continue;
    }
    final id = unlistedIds[i];
    final lesson = LessonSummaryModel(
        id: id,
        lessonNo: 0,
        chapterLessonNo: 0,
        title: lookup.recoveryTitle ?? '저장된 레슨 결과',
        topic: '',
        estimatedMinutes: 0,
        status: 'IN_PROGRESS',
        scoreCorrect: 0,
        scoreTotal: 0);
    entries.add(SavedLessonEntry(
        accountId: owner,
        jlptLevel: jlptLevel,
        chapter: ChapterModel(
            id: '',
            jlptLevel: jlptLevel,
            partNo: 0,
            chapterNo: 0,
            title: '제출 결과 확인',
            lessons: [lesson],
            completedLessons: 0,
            totalLessons: 1),
        lesson: lesson,
        hint: lookup.hint!,
        recoveryOnly: true));
  }
  // List.sort is not stable. Preserve curriculum order explicitly for ties
  // and for legacy drafts whose historical study time is unknown.
  final curriculumOrder = {
    for (var i = 0; i < targets.length; i++) targets[i].lesson.id: i,
  };
  entries.sort((a, b) {
    final aTime = a.hint.lastStudiedAt;
    final bTime = b.hint.lastStudiedAt;
    if (aTime == null && bTime != null) return 1;
    if (aTime != null && bTime == null) return -1;
    final recent = aTime == null ? 0 : bTime!.compareTo(aTime);
    return recent != 0
        ? recent
        : (curriculumOrder[a.lesson.id] ?? targets.length)
            .compareTo(curriculumOrder[b.lesson.id] ?? targets.length);
  });
  if (entries.isEmpty && chapterError != null) {
    Error.throwWithStackTrace(chapterError, chapterStack!);
  }
  return SavedLessonEntries(
    accountId: owner,
    jlptLevel: jlptLevel,
    entries: entries,
    failedLessonIds: [
      if (chapterError != null) 'curriculum-unavailable',
      if (scanFailed) 'saved-submission-scan',
      for (var i = 0; i < unlistedIds.length; i++)
        if (orphanLookups[i].failed) unlistedIds[i],
      for (var i = 0; i < targets.length; i++)
        if (lookups[i].failed) targets[i].lesson.id,
    ],
  );
});
