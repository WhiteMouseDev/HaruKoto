class VolumeChartEntry {
  final String date;
  final int wordsStudied;
  final int grammarStudied;
  final int sentencesStudied;

  const VolumeChartEntry({
    required this.date,
    required this.wordsStudied,
    required this.grammarStudied,
    required this.sentencesStudied,
  });

  factory VolumeChartEntry.fromJson(Map<String, dynamic> json) {
    return VolumeChartEntry(
      date: json['date'] as String? ?? '',
      wordsStudied: json['wordsStudied'] as int? ?? 0,
      grammarStudied: json['grammarStudied'] as int? ?? 0,
      sentencesStudied: json['sentencesStudied'] as int? ?? 0,
    );
  }
}

class VolumeChartResponse {
  final List<VolumeChartEntry> data;

  const VolumeChartResponse({required this.data});

  factory VolumeChartResponse.fromJson(Map<String, dynamic> json) {
    final list = json['data'] as List<dynamic>? ?? [];
    return VolumeChartResponse(
      data: list
          .map((e) => VolumeChartEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
