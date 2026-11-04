import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/current_account_provider.dart';
import '../../../core/providers/dio_provider.dart';
import '../../../core/providers/study_clock_provider.dart';
import '../domain/study_repository.dart';
import '../data/study_repository.dart';
import '../data/models/lesson_models.dart';
import '../data/models/quiz_session_model.dart';
import '../data/models/recommendation_model.dart';
import '../data/models/review_summary_model.dart';
import '../data/models/smart_preview_model.dart';
import '../data/models/stage_model.dart';

final studyRepositoryProvider = Provider<StudyRepository>((ref) {
  return ApiStudyRepository(ref.watch(dioProvider));
});

final incompleteQuizProvider =
    FutureProvider.autoDispose<IncompleteSessionModel?>((ref) async {
  final owner = ref.watch(currentAccountIdProvider);
  if (owner == null || ref.read(currentAccountReaderProvider)() != owner) {
    return null;
  }
  final result = await ref.watch(studyRepositoryProvider).fetchIncompleteQuiz();
  if (!ref.mounted || ref.read(currentAccountReaderProvider)() != owner) {
    throw StateError('Quiz account changed while loading');
  }
  return result;
});

final quizStatsProvider = FutureProvider.autoDispose
    .family<StudyStatsModel, ({String level, String type})>((ref, params) {
  return ref
      .watch(studyRepositoryProvider)
      .fetchQuizStats(params.level, params.type);
});

final recommendationsProvider =
    FutureProvider.autoDispose<RecommendationModel>((ref) {
  return ref.watch(studyRepositoryProvider).fetchRecommendations();
});

/// Refresh only the changed category across its active levels after a save.
final vocabularyPreviewRefreshProvider =
    NotifierProvider<GoalPreviewRefresh, int>(GoalPreviewRefresh.new);
final grammarPreviewRefreshProvider =
    NotifierProvider<GoalPreviewRefresh, int>(GoalPreviewRefresh.new);

class GoalPreviewRefresh extends Notifier<int> {
  @override
  int build() => 0;

  void refresh() => state++;
}

final smartPreviewProvider = FutureProvider.autoDispose
    .family<SmartPreviewModel, ({String category, String jlptLevel})>(
        (ref, params) async {
  final repository = ref.watch(studyRepositoryProvider);
  ref.watch(studyDateProvider);
  if (params.category == 'VOCABULARY') {
    ref.watch(vocabularyPreviewRefreshProvider);
  } else if (params.category == 'GRAMMAR') {
    ref.watch(grammarPreviewRefreshProvider);
  }
  final owner = ref.watch(currentAccountIdProvider);
  if (owner == null || ref.read(currentAccountReaderProvider)() != owner) {
    throw StateError('Study preview account is no longer current');
  }
  final preview = await repository.fetchSmartPreview(
    category: params.category,
    jlptLevel: params.jlptLevel,
  );
  if (!ref.mounted || ref.read(currentAccountReaderProvider)() != owner) {
    throw StateError('Study preview account changed while loading');
  }
  return preview;
});

final stagesProvider = FutureProvider.autoDispose
    .family<List<StageModel>, ({String category, String jlptLevel})>(
        (ref, params) {
  return ref
      .watch(studyRepositoryProvider)
      .fetchStages(params.category, params.jlptLevel);
});

// ── Review Summary ──

final reviewSummaryProvider = FutureProvider.autoDispose
    .family<ReviewSummaryModel, String>((ref, jlptLevel) async {
  final owner = ref.watch(currentAccountIdProvider);
  if (owner == null || ref.read(currentAccountReaderProvider)() != owner) {
    throw StateError('Review summary account is no longer current');
  }
  final summary =
      await ref.watch(studyRepositoryProvider).fetchReviewSummary(jlptLevel);
  if (!ref.mounted || ref.read(currentAccountReaderProvider)() != owner) {
    throw StateError('Review summary account changed while loading');
  }
  return summary;
});

// ── Lesson Providers ──

final chaptersProvider = FutureProvider.autoDispose
    .family<ChapterListModel, String>((ref, jlptLevel) async {
  final owner = ref.watch(currentAccountIdProvider);
  if (owner == null || ref.read(currentAccountReaderProvider)() != owner) {
    throw StateError('Lesson account is no longer current');
  }
  final chapters =
      await ref.watch(studyRepositoryProvider).fetchChapters(jlptLevel);
  if (!ref.mounted || ref.read(currentAccountReaderProvider)() != owner) {
    throw StateError('Lesson account changed while loading');
  }
  return chapters;
}, retry: (_, __) => null);

final lessonDetailProvider = FutureProvider.autoDispose
    .family<LessonDetailModel, String>((ref, lessonId) {
  return ref.watch(studyRepositoryProvider).fetchLessonDetail(lessonId);
});
