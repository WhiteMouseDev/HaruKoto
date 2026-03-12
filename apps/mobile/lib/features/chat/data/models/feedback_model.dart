class FeedbackSummary {
  final int overallScore;
  final int fluency;
  final int accuracy;
  final int vocabularyDiversity;
  final int naturalness;
  final List<String> strengths;
  final List<String> improvements;
  final List<RecommendedExpression> recommendedExpressions;
  final List<GrammarCorrection> corrections;
  final List<TranslatedMessage> translatedTranscript;

  const FeedbackSummary({
    required this.overallScore,
    required this.fluency,
    required this.accuracy,
    required this.vocabularyDiversity,
    required this.naturalness,
    required this.strengths,
    required this.improvements,
    required this.recommendedExpressions,
    required this.corrections,
    required this.translatedTranscript,
  });

  factory FeedbackSummary.fromJson(Map<String, dynamic> json) {
    final rawExpressions =
        json['recommendedExpressions'] as List<dynamic>? ?? [];
    final expressions = rawExpressions.map((e) {
      if (e is String) {
        return RecommendedExpression(ja: e, ko: '');
      }
      return RecommendedExpression.fromJson(e as Map<String, dynamic>);
    }).toList();

    return FeedbackSummary(
      overallScore: json['overallScore'] as int? ?? 0,
      fluency: json['fluency'] as int? ?? 0,
      accuracy: json['accuracy'] as int? ?? 0,
      vocabularyDiversity: json['vocabularyDiversity'] as int? ?? 0,
      naturalness: json['naturalness'] as int? ?? 0,
      strengths: (json['strengths'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      improvements: (json['improvements'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      recommendedExpressions: expressions,
      corrections: (json['corrections'] as List<dynamic>?)
              ?.map(
                  (e) => GrammarCorrection.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      translatedTranscript: (json['translatedTranscript'] as List<dynamic>?)
              ?.map((e) =>
                  TranslatedMessage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class GrammarCorrection {
  final String original;
  final String corrected;
  final String explanation;

  const GrammarCorrection({
    required this.original,
    required this.corrected,
    required this.explanation,
  });

  factory GrammarCorrection.fromJson(Map<String, dynamic> json) {
    return GrammarCorrection(
      original: json['original'] as String? ?? '',
      corrected: json['corrected'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
    );
  }
}

class RecommendedExpression {
  final String ja;
  final String ko;

  const RecommendedExpression({required this.ja, required this.ko});

  factory RecommendedExpression.fromJson(Map<String, dynamic> json) {
    return RecommendedExpression(
      ja: json['ja'] as String? ?? '',
      ko: json['ko'] as String? ?? '',
    );
  }
}

class TranslatedMessage {
  final String role; // 'user' | 'assistant'
  final String ja;
  final String ko;

  const TranslatedMessage({
    required this.role,
    required this.ja,
    required this.ko,
  });

  factory TranslatedMessage.fromJson(Map<String, dynamic> json) {
    return TranslatedMessage(
      role: json['role'] as String? ?? 'assistant',
      ja: json['ja'] as String? ?? '',
      ko: json['ko'] as String? ?? '',
    );
  }
}
