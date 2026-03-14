class TimeChartEntry {
  final String date;
  final int minutes;

  const TimeChartEntry({required this.date, required this.minutes});

  factory TimeChartEntry.fromJson(Map<String, dynamic> json) {
    return TimeChartEntry(
      date: json['date'] as String? ?? '',
      minutes: json['minutes'] as int? ?? 0,
    );
  }
}

class TimeChartResponse {
  final List<TimeChartEntry> data;

  const TimeChartResponse({required this.data});

  factory TimeChartResponse.fromJson(Map<String, dynamic> json) {
    final list = json['data'] as List<dynamic>? ?? [];
    return TimeChartResponse(
      data: list
          .map((e) => TimeChartEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
