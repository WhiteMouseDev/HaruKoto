class RecommendationModel {
  final int reviewDueCount;
  final int newWordsCount;
  final int wrongCount;
  final String? lastReviewedAt;

  const RecommendationModel({
    required this.reviewDueCount,
    required this.newWordsCount,
    required this.wrongCount,
    this.lastReviewedAt,
  });

  factory RecommendationModel.fromJson(Map<String, dynamic> json) {
    return RecommendationModel(
      reviewDueCount: json['reviewDueCount'] as int? ?? 0,
      newWordsCount: json['newWordsCount'] as int? ?? 0,
      wrongCount: json['wrongCount'] as int? ?? 0,
      lastReviewedAt: json['lastReviewedAt'] as String?,
    );
  }

  String? get lastReviewText {
    if (lastReviewedAt == null) return null;
    final last = DateTime.parse(lastReviewedAt!);
    final now = DateTime.now();
    final diffDays = now.difference(last).inDays;
    if (diffDays == 0) return '오늘';
    if (diffDays == 1) return '어제';
    return '$diffDays일 전';
  }
}
