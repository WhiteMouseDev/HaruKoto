import 'package:harukoto_mobile/features/study/data/models/lesson_models.dart';
import 'package:harukoto_mobile/features/study/domain/lesson_checkpoint.dart';
import 'package:harukoto_mobile/features/study/domain/lesson_practice_layout.dart';
import 'package:harukoto_mobile/features/study/domain/lesson_session_state.dart';

import 'lesson_resume_fixture.dart';

LessonDetailModel detailFor(String id) {
  final detail = resumeDetail(progress: null);
  return LessonDetailModel(
      id: id,
      lessonNo: 1,
      chapterLessonNo: 1,
      title: '저장 레슨 $id',
      topic: detail.topic,
      estimatedMinutes: 10,
      content: detail.content,
      vocabItems: detail.vocabItems,
      grammarItems: detail.grammarItems);
}

String rawCheckpoint(String id,
    {LessonStep step = LessonStep.vocabLearning,
    bool pending = false,
    bool acknowledged = false}) {
  final detail = detailFor(id);
  return LessonCheckpoint(
    progressStamp: lessonProgressStamp(detail.progress),
    acknowledged: acknowledged,
    state: LessonSessionState(
        step: step,
        vocabIndex: 1,
        practiceStarted: pending || step.index >= LessonStep.recognition.index,
        submissionPending: pending,
        seed: 7,
        layout: LessonPracticeLayout.create(detail, 7)),
  ).encode(detail);
}
