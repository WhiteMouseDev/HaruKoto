class ReviewSummaryModel {
  final int wordDue;
  final int grammarDue;
  final int totalDue;
  final int wordNew;
  final int grammarNew;

  const ReviewSummaryModel({
    required this.wordDue,
    required this.grammarDue,
    required this.totalDue,
    required this.wordNew,
    required this.grammarNew,
  });

  factory ReviewSummaryModel.fromJson(Map<String, dynamic> json) {
    return ReviewSummaryModel(
      wordDue: json['wordDue'] as int? ?? 0,
      grammarDue: json['grammarDue'] as int? ?? 0,
      totalDue: json['totalDue'] as int? ?? 0,
      wordNew: json['wordNew'] as int? ?? 0,
      grammarNew: json['grammarNew'] as int? ?? 0,
    );
  }
}
