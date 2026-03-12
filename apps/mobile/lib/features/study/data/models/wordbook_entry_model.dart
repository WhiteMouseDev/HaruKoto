class WordbookEntryModel {
  final String id;
  final String word;
  final String reading;
  final String meaningKo;
  final String source;
  final String? note;
  final String createdAt;

  const WordbookEntryModel({
    required this.id,
    required this.word,
    required this.reading,
    required this.meaningKo,
    required this.source,
    this.note,
    required this.createdAt,
  });

  factory WordbookEntryModel.fromJson(Map<String, dynamic> json) {
    return WordbookEntryModel(
      id: json['id'] as String,
      word: json['word'] as String,
      reading: json['reading'] as String,
      meaningKo: json['meaningKo'] as String,
      source: json['source'] as String? ?? 'MANUAL',
      note: json['note'] as String?,
      createdAt: json['createdAt'] as String,
    );
  }
}
