import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/stats/data/models/heatmap_data_model.dart';

void main() {
  group('HeatmapData', () {
    test('constructor creates instance', () {
      const model = HeatmapData(date: '2024-01-15', wordsStudied: 10);
      expect(model.date, '2024-01-15');
      expect(model.wordsStudied, 10);
    });
  });

  group('DayCell', () {
    test('constructor creates instance', () {
      const model = DayCell(
        date: '2024-01-15',
        count: 5,
        weekIndex: 2,
        dayIndex: 1,
      );
      expect(model.date, '2024-01-15');
      expect(model.count, 5);
      expect(model.weekIndex, 2);
      expect(model.dayIndex, 1);
    });
  });
}
