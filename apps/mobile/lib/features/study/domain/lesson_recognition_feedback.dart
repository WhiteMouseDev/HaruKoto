/// Feedback for a single submitted recognition choice.
// OPENAPI_SCHEMA: LessonRecognitionFeedbackResponse
class LessonRecognitionFeedback {
  const LessonRecognitionFeedback({
    required this.feedbackVersion,
    required this.questionOrder,
    required this.selectedAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    this.explanation,
  });

  final String feedbackVersion;
  final int questionOrder;
  final String selectedAnswer;
  final String correctAnswer;
  final bool isCorrect;
  final String? explanation;

  static String? parseVersion(Object? value) =>
      value is String && value.length <= 64 && value.trim().isNotEmpty
          ? value
          : null;

  factory LessonRecognitionFeedback.fromJson(Map<String, dynamic> json) {
    final version = parseVersion(json['feedbackVersion']);
    final order = json['questionOrder'];
    final selected = json['selectedAnswer'];
    final correct = json['correctAnswer'];
    final isCorrect = json['isCorrect'];
    final explanation = json['explanation'];
    if (version == null ||
        order is! int ||
        order < 1 ||
        selected is! String ||
        selected.isEmpty ||
        correct is! String ||
        correct.isEmpty ||
        isCorrect is! bool ||
        isCorrect != (selected == correct) ||
        (explanation != null && explanation is! String)) {
      throw const FormatException('Invalid lesson recognition feedback');
    }
    final feedbackExplanation = (explanation as String?)?.trim();
    return LessonRecognitionFeedback(
      feedbackVersion: version,
      questionOrder: order,
      selectedAnswer: selected,
      correctAnswer: correct,
      isCorrect: isCorrect,
      explanation:
          feedbackExplanation?.isEmpty == true ? null : feedbackExplanation,
    );
  }

  Map<String, dynamic> toJson() => {
        'feedbackVersion': feedbackVersion,
        'questionOrder': questionOrder,
        'selectedAnswer': selectedAnswer,
        'correctAnswer': correctAnswer,
        'isCorrect': isCorrect,
        'explanation': explanation,
      };
}
