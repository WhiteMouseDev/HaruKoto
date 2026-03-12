import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/models/feedback_model.dart';

void main() {
  group('GrammarCorrection', () {
    test('fromJson parses complete data', () {
      final json = {
        'original': '食べるます',
        'corrected': '食べます',
        'explanation': 'Verb conjugation error',
      };
      final model = GrammarCorrection.fromJson(json);
      expect(model.original, '食べるます');
      expect(model.corrected, '食べます');
      expect(model.explanation, 'Verb conjugation error');
    });

    test('fromJson handles missing fields with defaults', () {
      final model = GrammarCorrection.fromJson({});
      expect(model.original, '');
      expect(model.corrected, '');
      expect(model.explanation, '');
    });
  });

  group('RecommendedExpression', () {
    test('fromJson parses complete data', () {
      final json = {'ja': 'お願いします', 'ko': '부탁합니다'};
      final model = RecommendedExpression.fromJson(json);
      expect(model.ja, 'お願いします');
      expect(model.ko, '부탁합니다');
    });

    test('fromJson handles missing fields with defaults', () {
      final model = RecommendedExpression.fromJson({});
      expect(model.ja, '');
      expect(model.ko, '');
    });
  });

  group('TranslatedMessage', () {
    test('fromJson parses complete data', () {
      final json = {
        'role': 'user',
        'ja': 'こんにちは',
        'ko': '안녕하세요',
      };
      final model = TranslatedMessage.fromJson(json);
      expect(model.role, 'user');
      expect(model.ja, 'こんにちは');
      expect(model.ko, '안녕하세요');
    });

    test('fromJson handles missing fields with defaults', () {
      final model = TranslatedMessage.fromJson({});
      expect(model.role, 'assistant');
      expect(model.ja, '');
      expect(model.ko, '');
    });
  });

  group('FeedbackSummary', () {
    test('fromJson parses complete data', () {
      final json = {
        'overallScore': 85,
        'fluency': 80,
        'accuracy': 90,
        'vocabularyDiversity': 75,
        'naturalness': 70,
        'strengths': ['Good grammar', 'Natural flow'],
        'improvements': ['Use more keigo'],
        'recommendedExpressions': [
          {'ja': 'お願いします', 'ko': '부탁합니다'},
        ],
        'corrections': [
          {
            'original': '食べるます',
            'corrected': '食べます',
            'explanation': 'Conjugation error',
          },
        ],
        'translatedTranscript': [
          {'role': 'user', 'ja': 'こんにちは', 'ko': '안녕하세요'},
        ],
      };
      final model = FeedbackSummary.fromJson(json);
      expect(model.overallScore, 85);
      expect(model.fluency, 80);
      expect(model.accuracy, 90);
      expect(model.vocabularyDiversity, 75);
      expect(model.naturalness, 70);
      expect(model.strengths, ['Good grammar', 'Natural flow']);
      expect(model.improvements, ['Use more keigo']);
      expect(model.recommendedExpressions.length, 1);
      expect(model.recommendedExpressions[0].ja, 'お願いします');
      expect(model.corrections.length, 1);
      expect(model.corrections[0].original, '食べるます');
      expect(model.translatedTranscript.length, 1);
      expect(model.translatedTranscript[0].role, 'user');
    });

    test('fromJson handles missing fields with defaults', () {
      final model = FeedbackSummary.fromJson({});
      expect(model.overallScore, 0);
      expect(model.fluency, 0);
      expect(model.accuracy, 0);
      expect(model.vocabularyDiversity, 0);
      expect(model.naturalness, 0);
      expect(model.strengths, isEmpty);
      expect(model.improvements, isEmpty);
      expect(model.recommendedExpressions, isEmpty);
      expect(model.corrections, isEmpty);
      expect(model.translatedTranscript, isEmpty);
    });

    test('fromJson handles string recommendedExpressions', () {
      final json = {
        'recommendedExpressions': ['お願いします', 'すみません'],
      };
      final model = FeedbackSummary.fromJson(json);
      expect(model.recommendedExpressions.length, 2);
      expect(model.recommendedExpressions[0].ja, 'お願いします');
      expect(model.recommendedExpressions[0].ko, '');
      expect(model.recommendedExpressions[1].ja, 'すみません');
    });
  });
}
