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
  final int pct;

  const KanaTypeProgress({
    required this.learned,
    required this.mastered,
    required this.total,
    required this.pct,
  });

  factory KanaTypeProgress.fromJson(Map<String, dynamic> json) {
    return KanaTypeProgress(
      learned: json['learned'] as int? ?? 0,
      mastered: json['mastered'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
      pct: json['pct'] as int? ?? 0,
    );
  }
}
