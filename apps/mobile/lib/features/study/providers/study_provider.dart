import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/dio_provider.dart';
import '../data/study_repository.dart';
import '../data/models/lesson_models.dart';
import '../data/models/quiz_session_model.dart';
import '../data/models/recommendation_model.dart';
import '../data/models/smart_preview_model.dart';
import '../data/models/stage_model.dart';

final studyRepositoryProvider = Provider((ref) {
  return StudyRepository(ref.watch(dioProvider));
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

final smartPreviewProvider = FutureProvider.autoDispose
    .family<SmartPreviewModel, ({String category, String jlptLevel})>(
        (ref, params) {
  return ref.watch(studyRepositoryProvider).fetchSmartPreview(
        category: params.category,
        jlptLevel: params.jlptLevel,
      );
});

final stagesProvider = FutureProvider.autoDispose
    .family<List<StageModel>, ({String category, String jlptLevel})>(
        (ref, params) {
  return ref
      .watch(studyRepositoryProvider)
      .fetchStages(params.category, params.jlptLevel);
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
