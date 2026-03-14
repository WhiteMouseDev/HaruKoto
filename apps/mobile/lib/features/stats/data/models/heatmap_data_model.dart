class HeatmapData {
  final String date;
  final int wordsStudied;
  final int studyMinutes;
  final int level;

  const HeatmapData({
    required this.date,
    required this.wordsStudied,
    this.studyMinutes = 0,
    this.level = 0,
  });

  factory HeatmapData.fromJson(Map<String, dynamic> json) {
    return HeatmapData(
      date: json['date'] as String? ?? '',
      wordsStudied: json['wordsStudied'] as int? ?? 0,
      studyMinutes: json['studyMinutes'] as int? ?? 0,
      level: json['level'] as int? ?? 0,
    );
  }
}

class HeatmapResponse {
  final List<HeatmapData> data;

  const HeatmapResponse({required this.data});

  factory HeatmapResponse.fromJson(Map<String, dynamic> json) {
    final list = json['data'] as List<dynamic>? ?? [];
    return HeatmapResponse(
      data: list
          .map((e) => HeatmapData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
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
