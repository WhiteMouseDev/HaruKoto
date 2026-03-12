class KanaCharacterModel {
  final String id;
  final String kanaType; // 'HIRAGANA' | 'KATAKANA'
  final String character;
  final String romaji;
  final String pronunciation;
  final String row;
  final String column;
  final int strokeCount;
  final String? exampleWord;
  final String? exampleReading;
  final String? exampleMeaning;
  final String category;
  final int order;
  final KanaCharacterProgress? progress;

  const KanaCharacterModel({
    required this.id,
    required this.kanaType,
    required this.character,
    required this.romaji,
    required this.pronunciation,
    required this.row,
    required this.column,
    required this.strokeCount,
    this.exampleWord,
    this.exampleReading,
    this.exampleMeaning,
    required this.category,
    required this.order,
    this.progress,
  });

  factory KanaCharacterModel.fromJson(Map<String, dynamic> json) {
    return KanaCharacterModel(
      id: json['id'] as String,
      kanaType: json['kanaType'] as String,
      character: json['character'] as String,
      romaji: json['romaji'] as String,
      pronunciation: json['pronunciation'] as String,
      row: json['row'] as String,
      column: json['column'] as String,
      strokeCount: json['strokeCount'] as int? ?? 0,
      exampleWord: json['exampleWord'] as String?,
      exampleReading: json['exampleReading'] as String?,
      exampleMeaning: json['exampleMeaning'] as String?,
      category: json['category'] as String? ?? 'basic',
      order: json['order'] as int? ?? 0,
      progress: json['progress'] != null
          ? KanaCharacterProgress.fromJson(
              json['progress'] as Map<String, dynamic>)
          : null,
    );
  }
}

class KanaCharacterProgress {
  final int correctCount;
  final int incorrectCount;
  final int streak;
  final bool mastered;
  final String? lastReviewedAt;

  const KanaCharacterProgress({
    required this.correctCount,
    required this.incorrectCount,
    required this.streak,
    required this.mastered,
    this.lastReviewedAt,
  });

  factory KanaCharacterProgress.fromJson(Map<String, dynamic> json) {
    return KanaCharacterProgress(
      correctCount: json['correctCount'] as int? ?? 0,
      incorrectCount: json['incorrectCount'] as int? ?? 0,
      streak: json['streak'] as int? ?? 0,
      mastered: json['mastered'] as bool? ?? false,
      lastReviewedAt: json['lastReviewedAt'] as String?,
    );
  }
}
