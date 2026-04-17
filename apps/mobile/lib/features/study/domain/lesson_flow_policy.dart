import '../data/models/lesson_models.dart';

class LessonPracticePlan {
  const LessonPracticePlan({
    required this.recognitionQuestions,
    required this.reorderQuestions,
  });

  final List<LessonQuestionModel> recognitionQuestions;
  final List<LessonQuestionModel> reorderQuestions;

  bool get hasRecognitionStep => recognitionQuestions.isNotEmpty;

  bool get hasReorderStep => reorderQuestions.isNotEmpty;
}

List<LessonQuestionModel> lessonRecognitionQuestions(
  LessonDetailModel detail,
) {
  return detail.content.questions
      .where((q) => q.type == 'VOCAB_MCQ' || q.type == 'CONTEXT_CLOZE')
      .toList();
}

List<LessonQuestionModel> lessonReorderQuestions(
  LessonDetailModel detail,
) {
  return detail.content.questions
      .where((q) => q.type == 'SENTENCE_REORDER')
      .toList();
}

LessonPracticePlan buildLessonPracticePlan(LessonDetailModel detail) {
  return LessonPracticePlan(
    recognitionQuestions: lessonRecognitionQuestions(detail),
    reorderQuestions: lessonReorderQuestions(detail),
  );
}
