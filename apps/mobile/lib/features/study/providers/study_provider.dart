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
    FutureProvider.autoDispose<IncompleteSessionModel?>((ref) {
  return ref.watch(studyRepositoryProvider).fetchIncompleteQuiz();
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

/// Refresh all active vocabulary levels after a confirmed daily-goal save.
/// Optimistic preference changes must not request a preview from the old goal.
final vocabularyPreviewRefreshProvider =
    NotifierProvider<VocabularyPreviewRefresh, int>(
        VocabularyPreviewRefresh.new);

class VocabularyPreviewRefresh extends Notifier<int> {
  @override
  int build() => 0;

  void refresh() => state++;
}

final smartPreviewProvider = FutureProvider.autoDispose
    .family<SmartPreviewModel, ({String category, String jlptLevel})>(
        (ref, params) async {
  final repository = ref.watch(studyRepositoryProvider);
  if (params.category != 'VOCABULARY') {
    return repository.fetchSmartPreview(
      category: params.category,
      jlptLevel: params.jlptLevel,
    );
  }
  ref.watch(studyDateProvider);
  ref.watch(vocabularyPreviewRefreshProvider);
  final owner = ref.watch(currentAccountIdProvider);
  if (owner == null || ref.read(currentAccountReaderProvider)() != owner) {
    throw StateError('Vocabulary preview account is no longer current');
  }
  final preview = await repository.fetchSmartPreview(
    category: params.category,
    jlptLevel: params.jlptLevel,
  );
  if (!ref.mounted || ref.read(currentAccountReaderProvider)() != owner) {
    throw StateError('Vocabulary preview account changed while loading');
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
    .family<ReviewSummaryModel, String>((ref, jlptLevel) {
  return ref.watch(studyRepositoryProvider).fetchReviewSummary(jlptLevel);
});

// ── Lesson Providers ──

final chaptersProvider = FutureProvider.autoDispose
    .family<ChapterListModel, String>((ref, jlptLevel) {
  return ref.watch(studyRepositoryProvider).fetchChapters(jlptLevel);
});

final lessonDetailProvider = FutureProvider.autoDispose
    .family<LessonDetailModel, String>((ref, lessonId) {
  return ref.watch(studyRepositoryProvider).fetchLessonDetail(lessonId);
});
