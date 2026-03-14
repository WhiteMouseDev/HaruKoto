class CategoryStats {
  final int total;
  final List<int> daily;

  const CategoryStats({required this.total, required this.daily});

  factory CategoryStats.fromJson(Map<String, dynamic> json) {
    final dailyList = json['daily'] as List<dynamic>? ?? [];
    return CategoryStats(
      total: json['total'] as int? ?? 0,
      daily: dailyList.map((e) => (e as num).toInt()).toList(),
    );
  }
}

class ByCategoryResponse {
  final CategoryStats vocabulary;
  final CategoryStats grammar;
  final CategoryStats sentences;

  const ByCategoryResponse({
    required this.vocabulary,
    required this.grammar,
    required this.sentences,
  });

  factory ByCategoryResponse.fromJson(Map<String, dynamic> json) {
    return ByCategoryResponse(
      vocabulary: CategoryStats.fromJson(
        json['vocabulary'] as Map<String, dynamic>? ?? {},
      ),
      grammar: CategoryStats.fromJson(
        json['grammar'] as Map<String, dynamic>? ?? {},
      ),
      sentences: CategoryStats.fromJson(
        json['sentences'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}
