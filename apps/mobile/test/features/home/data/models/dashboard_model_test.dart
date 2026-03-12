import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/home/data/models/dashboard_model.dart';

void main() {
  group('TodayStats', () {
    test('fromJson parses complete data', () {
      final json = {
        'wordsStudied': 5,
        'quizzesCompleted': 3,
        'correctAnswers': 8,
        'totalAnswers': 10,
        'xpEarned': 120,
        'goalProgress': 0.5,
      };
      final model = TodayStats.fromJson(json);
      expect(model.wordsStudied, 5);
      expect(model.quizzesCompleted, 3);
      expect(model.correctAnswers, 8);
      expect(model.totalAnswers, 10);
      expect(model.xpEarned, 120);
      expect(model.goalProgress, 0.5);
    });

    test('fromJson handles missing fields with defaults', () {
      final model = TodayStats.fromJson({});
      expect(model.wordsStudied, 0);
      expect(model.quizzesCompleted, 0);
      expect(model.correctAnswers, 0);
      expect(model.totalAnswers, 0);
      expect(model.xpEarned, 0);
      expect(model.goalProgress, 0.0);
    });
  });

  group('WeeklyStatEntry', () {
    test('fromJson parses complete data', () {
      final json = {
        'date': '2026-03-10',
        'wordsStudied': 5,
        'xpEarned': 50,
      };
      final model = WeeklyStatEntry.fromJson(json);
      expect(model.date, '2026-03-10');
      expect(model.wordsStudied, 5);
      expect(model.xpEarned, 50);
    });

    test('fromJson handles missing fields with defaults', () {
      final model = WeeklyStatEntry.fromJson({});
      expect(model.date, '');
      expect(model.wordsStudied, 0);
      expect(model.xpEarned, 0);
    });
  });

  group('KanaProgressData', () {
    test('fromJson parses complete data', () {
      final json = {
        'hiragana': {'learned': 30, 'total': 46, 'pct': 65.2},
        'katakana': {'learned': 10, 'total': 46, 'pct': 21.7},
      };
      final model = KanaProgressData.fromJson(json);
      expect(model.hiragana.learned, 30);
      expect(model.hiragana.total, 46);
      expect(model.katakana.learned, 10);
    });

    test('fromJson handles missing fields with defaults', () {
      final model = KanaProgressData.fromJson({});
      expect(model.hiragana.learned, 0);
      expect(model.hiragana.total, 0);
      expect(model.katakana.learned, 0);
    });

    test('completed returns true when all kana learned', () {
      final model = KanaProgressData(
        hiragana: const KanaStat(learned: 46, total: 46, pct: 100.0),
        katakana: const KanaStat(learned: 46, total: 46, pct: 100.0),
      );
      expect(model.completed, true);
    });

    test('completed returns false when not all learned', () {
      final model = KanaProgressData(
        hiragana: const KanaStat(learned: 30, total: 46, pct: 65.2),
        katakana: const KanaStat(learned: 46, total: 46, pct: 100.0),
      );
      expect(model.completed, false);
    });

    test('pct is parsed from json', () {
      const stat = KanaStat(learned: 23, total: 46, pct: 50.0);
      expect(stat.pct, 50.0);
    });

    test('pct defaults to 0 when not provided', () {
      const stat = KanaStat(learned: 0, total: 0, pct: 0.0);
      expect(stat.pct, 0.0);
    });
  });

  group('LevelProgressData', () {
    test('fromJson parses complete data', () {
      final json = {
        'vocabulary': {'total': 100, 'mastered': 50, 'inProgress': 20},
        'grammar': {'total': 50, 'mastered': 25, 'inProgress': 10},
      };
      final model = LevelProgressData.fromJson(json);
      expect(model.vocabulary.total, 100);
      expect(model.vocabulary.mastered, 50);
      expect(model.vocabulary.inProgress, 20);
      expect(model.grammar.total, 50);
      expect(model.grammar.mastered, 25);
    });

    test('fromJson handles missing fields with defaults', () {
      final model = LevelProgressData.fromJson({});
      expect(model.vocabulary.total, 0);
      expect(model.vocabulary.mastered, 0);
      expect(model.grammar.total, 0);
    });
  });

  group('DashboardModel', () {
    test('fromJson parses complete data with nested models', () {
      final json = {
        'showKana': true,
        'today': {
          'wordsStudied': 5,
          'quizzesCompleted': 3,
          'correctAnswers': 8,
          'totalAnswers': 10,
          'xpEarned': 120,
          'goalProgress': 0.5,
        },
        'streak': {'current': 3, 'longest': 7},
        'weeklyStats': [
          {'date': '2026-03-10', 'wordsStudied': 5, 'xpEarned': 50},
          {'date': '2026-03-11', 'wordsStudied': 10, 'xpEarned': 100},
        ],
        'kanaProgress': {
          'hiragana': {'learned': 20, 'total': 46, 'pct': 43.5},
          'katakana': {'learned': 10, 'total': 46, 'pct': 21.7},
        },
        'levelProgress': {
          'vocabulary': {'total': 100, 'mastered': 50, 'inProgress': 20},
          'grammar': {'total': 50, 'mastered': 25, 'inProgress': 10},
        },
      };
      final model = DashboardModel.fromJson(json);
      expect(model.showKana, true);
      expect(model.today.wordsStudied, 5);
      expect(model.streak.current, 3);
      expect(model.streak.longest, 7);
      expect(model.weeklyStats.length, 2);
      expect(model.weeklyStats[0].wordsStudied, 5);
      expect(model.kanaProgress!.hiragana.learned, 20);
      expect(model.levelProgress!.vocabulary.total, 100);
    });

    test('fromJson handles null optional nested models', () {
      final json = <String, dynamic>{
        'today': <String, dynamic>{},
        'streak': <String, dynamic>{},
      };
      final model = DashboardModel.fromJson(json);
      expect(model.kanaProgress, isNull);
      expect(model.levelProgress, isNull);
      expect(model.weeklyStats, isEmpty);
      expect(model.today.wordsStudied, 0);
      expect(model.streak.current, 0);
    });
  });
}
