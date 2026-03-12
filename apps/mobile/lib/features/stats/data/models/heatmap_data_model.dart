class HeatmapData {
  final String date;
  final int wordsStudied;

  const HeatmapData({
    required this.date,
    required this.wordsStudied,
  });
}

class DayCell {
  final String date;
  final int count;
  final int weekIndex;
  final int dayIndex;

  const DayCell({
    required this.date,
    required this.count,
    required this.weekIndex,
    required this.dayIndex,
  });
}
