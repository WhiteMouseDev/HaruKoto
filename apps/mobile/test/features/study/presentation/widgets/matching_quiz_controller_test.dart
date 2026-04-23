import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_question_model.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/matching_quiz_controller.dart';

void main() {
  group('MatchingQuizPair', () {
    test('uses matching API fields when present', () {
      const question = QuizQuestionModel(
        questionId: 'q-match',
        questionText: 'ignored',
        questionSubText: 'たべる',
        options: [],
        correctOptionId: '',
        matchingWord: '食べる',
        matchingMeaning: '먹다',
      );

      final pair = MatchingQuizPair.fromQuestion(question);

      expect(pair.id, 'q-match');
      expect(pair.left, '食べる');
      expect(pair.reading, 'たべる');
      expect(pair.right, '먹다');
    });

    test('falls back to the correct option for standard questions', () {
      const question = QuizQuestionModel(
        questionId: 'q-standard',
        questionText: '見る',
        questionSubText: 'みる',
        options: [
          QuizOption(id: 'o1', text: '먹다'),
          QuizOption(id: 'o2', text: '보다'),
        ],
        correctOptionId: 'o2',
      );

      final pair = MatchingQuizPair.fromQuestion(question);

      expect(pair.id, 'q-standard');
      expect(pair.left, '見る');
      expect(pair.reading, 'みる');
      expect(pair.right, '보다');
    });
  });

  group('MatchingQuizController', () {
    test('reports score, round labels, and unmatched pairs', () {
      final controller = MatchingQuizController(
        pairs: _pairs,
        pairsPerRound: 2,
        random: Random(1),
      );

      expect(controller.totalCount, 3);
      expect(controller.totalRounds, 2);
      expect(controller.hasMultipleRounds, isTrue);
      expect(controller.scoreLabel, '0/3 맞춤');
      expect(controller.roundLabel, '라운드 1/2');
      expect(controller.unmatchedLeftPairs.map((pair) => pair.id), [
        'q1',
        'q2',
      ]);
      expect(controller.unmatchedRightPairs, hasLength(2));
    });

    test('records correct matches and locks selection until resolved', () {
      final controller = MatchingQuizController(
        pairs: _pairs,
        pairsPerRound: 2,
        random: Random(1),
      );

      expect(controller.selectLeft('q1'), isNull);
      final result = controller.selectRight('q1');

      expect(result, isNotNull);
      expect(result!.leftPair.id, 'q1');
      expect(result.rightPair.id, 'q1');
      expect(result.isCorrect, isTrue);
      expect(controller.totalCorrect, 1);
      expect(controller.scoreLabel, '1/3 맞춤');
      expect(controller.unmatchedLeftPairs.map((pair) => pair.id), ['q2']);
      expect(controller.isResolving, isTrue);

      expect(controller.selectLeft('q2'), isNull);
      expect(controller.finishAttempt(), MatchingQuizRoundOutcome.inProgress);
      expect(controller.isResolving, isFalse);
    });

    test('keeps pairs unmatched after incorrect attempts', () {
      final controller = MatchingQuizController(
        pairs: _pairs,
        pairsPerRound: 2,
        random: Random(1),
      );

      controller.selectLeft('q1');
      final result = controller.selectRight('q2');

      expect(result, isNotNull);
      expect(result!.isCorrect, isFalse);
      expect(controller.totalCorrect, 0);
      expect(controller.unmatchedLeftPairs.map((pair) => pair.id), [
        'q1',
        'q2',
      ]);
      expect(controller.finishAttempt(), MatchingQuizRoundOutcome.inProgress);
    });

    test('advances rounds and reports completion after final match', () {
      final controller = MatchingQuizController(
        pairs: _pairs,
        pairsPerRound: 2,
        random: Random(1),
      );

      controller
        ..selectLeft('q1')
        ..selectRight('q1');
      expect(controller.finishAttempt(), MatchingQuizRoundOutcome.inProgress);

      controller
        ..selectLeft('q2')
        ..selectRight('q2');
      expect(controller.finishAttempt(), MatchingQuizRoundOutcome.advanced);
      expect(controller.roundIndex, 1);
      expect(controller.roundLabel, '라운드 2/2');
      expect(controller.unmatchedLeftPairs.map((pair) => pair.id), ['q3']);

      controller
        ..selectLeft('q3')
        ..selectRight('q3');
      expect(controller.finishAttempt(), MatchingQuizRoundOutcome.completed);
      expect(controller.totalCorrect, 3);
    });
  });
}

const _pairs = [
  MatchingQuizPair(id: 'q1', left: '食べる', reading: 'たべる', right: '먹다'),
  MatchingQuizPair(id: 'q2', left: '見る', reading: 'みる', right: '보다'),
  MatchingQuizPair(id: 'q3', left: '行く', reading: 'いく', right: '가다'),
];
