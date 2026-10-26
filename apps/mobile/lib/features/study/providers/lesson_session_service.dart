import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/user_preferences_provider.dart';
import '../../home/providers/home_provider.dart';
import '../data/models/lesson_models.dart';
import 'study_provider.dart';

final lessonSessionServiceProvider = Provider<LessonSessionService>((ref) {
  return LessonSessionService(ref);
});

class LessonSessionService {
  const LessonSessionService(this._ref);

  final Ref _ref;

  Future<LessonProgressModel> startLesson(String lessonId) async {
    final progress =
        await _ref.read(studyRepositoryProvider).startLesson(lessonId);
    if (_ref.mounted) _ref.invalidate(chaptersProvider);
    return progress;
  }

  Future<LessonSubmitResultModel> submitLesson({
    required String lessonId,
    required List<Map<String, dynamic>> answers,
    String? jlptLevel,
  }) async {
    final resolvedJlptLevel =
        jlptLevel ?? _ref.read(userPreferencesProvider).jlptLevel;
    final result = await _ref
        .read(studyRepositoryProvider)
        .submitLesson(lessonId, answers);
    _ref.invalidate(chaptersProvider(resolvedJlptLevel));
    _ref.invalidate(reviewSummaryProvider(resolvedJlptLevel));
    _ref.invalidate(dashboardProvider);
    return result;
  }
}
