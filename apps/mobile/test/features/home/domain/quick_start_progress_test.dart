import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/home/data/models/dashboard_model.dart';
import 'package:harukoto_mobile/features/home/domain/quick_start_progress.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_session_model.dart';

void main() {
  test('one saved answer means 10% of this quiz even with zero mastery', () {
    final result = _progress(incomplete: _session());
    expect(result.label, '이번 퀴즈');
    expect(result.savedAnswerLabel, '1/10문제 저장됨');
    expect(result.fraction, 0.1);
    expect(result.percentage, '10%');
    expect(result.session?.id, 'saved-session');
  });

  test('another category or level never supplies this card progress or resume',
      () {
    for (final session in [
      _session(category: 'GRAMMAR'),
      _session(level: 'N4'),
    ]) {
      final result = _progress(incomplete: session);
      expect(result.session, isNull);
      expect(result.savedAnswerLabel, isNull);
      expect(result.label, 'N5 숙련도');
      expect(result.percentage, '0%');
    }
  });

  test('no saved quiz displays explicitly labelled level mastery', () {
    final result = _progress(
      mastery: const ProgressStat(total: 200, mastered: 50, inProgress: 25),
    );
    expect(result.label, 'N5 숙련도');
    expect(result.percentage, '25%');
    expect(result.session, isNull);
  });

  test('loading, missing totals and unsupported modes do not invent zero', () {
    final loading = _progress(incomplete: _session(), loading: true);
    expect(loading.label, '진행 확인 중');
    expect(loading.percentage, isNull);
    expect(loading.session, isNull);

    final failed = resolveQuickStartProgress(
      category: 'VOCABULARY',
      jlptLevel: 'N5',
      sessionLoading: false,
      sessionError: true,
      incomplete: _session(),
    );
    expect(failed.label, '진행 확인 필요');
    expect(failed.percentage, isNull);
    expect(failed.session, isNull);

    final invalidQuiz = _progress(incomplete: _session(total: 0));
    expect(invalidQuiz.label, '이번 퀴즈');
    expect(invalidQuiz.percentage, isNull);
    expect(invalidQuiz.savedAnswerLabel, '저장한 답안 확인 필요');
    expect(invalidQuiz.session, isNotNull);

    expect(_progress(mastery: null).percentage, isNull);
    expect(
      _progress(
        mastery: const ProgressStat(total: 0, mastered: 0, inProgress: 0),
      ).percentage,
      isNull,
    );
    final sentence = resolveQuickStartProgress(
      category: 'SENTENCE_ARRANGE',
      jlptLevel: 'N5',
      sessionLoading: false,
      incomplete: _session(category: 'SENTENCE_ARRANGE'),
    );
    expect(sentence.label, '이번 퀴즈');
    expect(sentence.session, isNotNull);
    expect(sentence.savedAnswerLabel, '1/10문제 저장됨');
  });

  test('inconsistent counts stay within zero and all saved answers', () {
    final negative = _progress(incomplete: _session(answered: -2));
    expect(negative.savedAnswerLabel, '0/10문제 저장됨');
    expect(negative.percentage, '0%');
    final excessive = _progress(incomplete: _session(answered: 12));
    expect(excessive.savedAnswerLabel, '10/10문제 저장됨');
    expect(excessive.percentage, '100%');
    expect(
      _progress(
        mastery: const ProgressStat(total: 10, mastered: 12, inProgress: 0),
      ).percentage,
      '100%',
    );
  });
}

QuickStartProgress _progress({
  IncompleteSessionModel? incomplete,
  bool loading = false,
  ProgressStat? mastery =
      const ProgressStat(total: 200, mastered: 0, inProgress: 1),
}) =>
    resolveQuickStartProgress(
      category: 'VOCABULARY',
      jlptLevel: 'N5',
      sessionLoading: loading,
      incomplete: incomplete,
      mastery: mastery,
    );

IncompleteSessionModel _session({
  String category = 'VOCABULARY',
  String level = 'N5',
  int answered = 1,
  int total = 10,
}) =>
    IncompleteSessionModel(
      id: 'saved-session',
      quizType: category,
      jlptLevel: level,
      totalQuestions: total,
      answeredCount: answered,
      correctCount: 1,
      startedAt: '2026-10-19T01:00:00Z',
    );
