class KanaProgressModel {
  final KanaTypeProgress hiragana;
  final KanaTypeProgress katakana;

  const KanaProgressModel({
    required this.hiragana,
    required this.katakana,
  });

  factory KanaProgressModel.fromJson(Map<String, dynamic> json) {
    return KanaProgressModel(
      hiragana:
          KanaTypeProgress.fromJson(json['hiragana'] as Map<String, dynamic>),
      katakana:
          KanaTypeProgress.fromJson(json['katakana'] as Map<String, dynamic>),
    );
  }
}

class KanaTypeProgress {
  final int learned;
  final int mastered;
  final int total;

  const KanaTypeProgress({
    required this.learned,
    required this.mastered,
    required this.total,
  });

  /// 진행률 (서버 미제공이므로 자체 계산)
  int get pct => total > 0 ? (mastered * 100 ~/ total) : 0;

  bool get completed => total > 0 && mastered >= total;

  factory KanaTypeProgress.fromJson(Map<String, dynamic> json) {
    return KanaTypeProgress(
      learned: json['learned'] as int? ?? 0,
      mastered: json['mastered'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
    );
  }
}
