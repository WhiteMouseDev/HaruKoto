import '../../data/models/lesson_models.dart';

/// Resolve a submitted answer only against its matching question snapshot.
/// Missing or ambiguous option IDs must never become a learner-facing answer.
String? lessonResultAnswerText(
  QuestionResultModel result,
  LessonQuestionModel? question,
) {
  if (question == null || question.order != result.order) return null;
  if (question.type == 'SENTENCE_REORDER') {
    final order = result.correctOrder;
    if (order == null ||
        order.isEmpty ||
        order.any((token) => token.trim().isEmpty)) {
      return null;
    }
    return order.join();
  }
  if (question.type != 'VOCAB_MCQ' && question.type != 'CONTEXT_CLOZE') {
    return null;
  }
  final answer = result.correctAnswer;
  if (answer == null || answer.trim().isEmpty) return null;
  final options = (question.options ?? const <QuizOptionModel>[])
      .where((option) => option.id == answer)
      .toList(growable: false);
  if (options.length != 1 || options.single.text.trim().isEmpty) return null;
  return options.single.text.trim();
}

/// The receipt stores a historical per-answer schedule, not the current SRS due
/// date. Show that snapshot as an absolute Korean-time date, never a countdown.
String? lessonResultReviewDate(String? value) {
  if (value == null) return null;
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?(Z|[+-](\d{2}):?(\d{2}))$',
  ).firstMatch(value);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final hour = int.parse(match.group(4)!);
  final minute = int.parse(match.group(5)!);
  final second = int.parse(match.group(6)!);
  final offsetHour = int.tryParse(match.group(8) ?? '0') ?? 99;
  final offsetMinute = int.tryParse(match.group(9) ?? '0') ?? 99;
  final calendar = DateTime.utc(year, month, day);
  if (year < 1 ||
      offsetHour > 23 ||
      offsetMinute > 59 ||
      calendar.year != year ||
      calendar.month != month ||
      calendar.day != day ||
      hour > 23 ||
      minute > 59 ||
      second > 59) {
    return null;
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc) return null;
  final korea = parsed.toUtc().add(const Duration(hours: 9));
  final hh = korea.hour.toString().padLeft(2, '0');
  final mm = korea.minute.toString().padLeft(2, '0');
  return '${korea.year}년 ${korea.month}월 ${korea.day}일 $hh:$mm (한국 시간)';
}
