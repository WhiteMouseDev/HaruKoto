class QuizOption {
  final String id;
  final String text;

  const QuizOption({required this.id, required this.text});

  factory QuizOption.fromJson(Map<String, dynamic> json) {
    return QuizOption(
      id: json['id'] as String,
      text: json['text'] as String,
    );
  }
}


class QuizQuestionModel {
  final String questionId;
  final String questionText;
  final String? questionSubText;
  final String? hint;
  final List<QuizOption> options;
  final String correctOptionId;
  // Cloze fields
  final String? sentence;
  final String? translation;
  final String? explanation;
  final String? grammarPoint;
  // Sentence arrange fields
  final String? koreanSentence;
  final String? japaneseSentence;
  final List<String>? tokens;
  // Typing fields
  final String? prompt;
  final String? answer;
  final List<String>? distractors;
  // Matching fields (from matchingPairs API response)
  final String? matchingWord;
  final String? matchingMeaning;

  const QuizQuestionModel({
    required this.questionId,
    required this.questionText,
    this.questionSubText,
    this.hint,
    required this.options,
    required this.correctOptionId,
    this.sentence,
    this.translation,
    this.explanation,
    this.grammarPoint,
    this.koreanSentence,
    this.japaneseSentence,
    this.tokens,
    this.prompt,
    this.answer,
    this.distractors,
    this.matchingWord,
    this.matchingMeaning,
  });

  factory QuizQuestionModel.fromJson(Map<String, dynamic> json) {
    return QuizQuestionModel(
      questionId: json['questionId'] as String,
      questionText: json['questionText'] as String,
      questionSubText: json['questionSubText'] as String?,
      hint: json['hint'] as String?,
      options: (json['options'] as List<dynamic>)
          .map((e) => QuizOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      correctOptionId: (json['correctOptionId'] ?? '') as String,
      sentence: json['sentence'] as String?,
      translation: json['translation'] as String?,
      explanation: json['explanation'] as String?,
      grammarPoint: json['grammarPoint'] as String?,
      koreanSentence: json['koreanSentence'] as String?,
      japaneseSentence: json['japaneseSentence'] as String?,
      tokens: (json['tokens'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      prompt: json['prompt'] as String?,
      answer: json['answer'] as String?,
      distractors: (json['distractors'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      matchingWord: json['word'] as String?,
      matchingMeaning: json['meaning'] as String?,
    );
  }
}
