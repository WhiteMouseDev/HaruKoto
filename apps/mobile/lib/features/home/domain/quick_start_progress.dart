import '../../study/data/models/quiz_session_model.dart';
import '../data/models/dashboard_model.dart';

/// Keep the saved quiz's progress separate from long-term level mastery.
class QuickStartProgress {
  const QuickStartProgress({
    required this.label,
    this.fraction,
    this.session,
    this.savedAnswerLabel,
  });

  final String? label;
  final double? fraction;
  final IncompleteSessionModel? session;
  final String? savedAnswerLabel;

  String? get percentage =>
      fraction == null ? null : '${(fraction! * 100).toStringAsFixed(0)}%';
}

QuickStartProgress resolveQuickStartProgress({
  required String category,
  required String jlptLevel,
  required bool sessionLoading,
  bool sessionError = false,
  IncompleteSessionModel? incomplete,
  ProgressStat? mastery,
}) {
  if (category != 'VOCABULARY' &&
      category != 'GRAMMAR' &&
      category != 'SENTENCE_ARRANGE') {
    return const QuickStartProgress(label: null);
  }
  if (sessionLoading) {
    return const QuickStartProgress(label: '진행 확인 중');
  }
  if (sessionError) {
    return const QuickStartProgress(label: '진행 확인 필요');
  }

  if (incomplete != null &&
      incomplete.quizType == category &&
      incomplete.jlptLevel == jlptLevel) {
    final total = incomplete.totalQuestions;
    if (total <= 0) {
      return QuickStartProgress(
        label: '이번 퀴즈',
        session: incomplete,
        savedAnswerLabel: '저장한 답안 확인 필요',
      );
    }
    final answered = incomplete.answeredCount.clamp(0, total);
    return QuickStartProgress(
      label: '이번 퀴즈',
      fraction: answered / total,
      session: incomplete,
      savedAnswerLabel: '$answered/$total문제 저장됨',
    );
  }

  if (category == 'SENTENCE_ARRANGE') {
    return const QuickStartProgress(label: null);
  }
  return QuickStartProgress(
    label: '$jlptLevel 숙련도',
    fraction: mastery != null && mastery.total > 0
        ? mastery.mastered.clamp(0, mastery.total) / mastery.total
        : null,
  );
}
