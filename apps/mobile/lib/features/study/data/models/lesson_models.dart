// Lesson API 모델 (Chapter 목록, Lesson 상세, 퀴즈 제출)

// ── Chapter 목록 ──

class ChapterListModel {
  final List<ChapterModel> chapters;

  const ChapterListModel({required this.chapters});

  factory ChapterListModel.fromJson(Map<String, dynamic> json) {
    return ChapterListModel(
      chapters: (json['chapters'] as List<dynamic>? ?? [])
          .map((e) => ChapterModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ChapterModel {
  final String id;
  final String jlptLevel;
  final int partNo;
  final int chapterNo;
  final String title;
  final String? topic;
  final List<LessonSummaryModel> lessons;
  final int completedLessons;
  final int totalLessons;

  const ChapterModel({
    required this.id,
    required this.jlptLevel,
    required this.partNo,
    required this.chapterNo,
    required this.title,
    this.topic,
    required this.lessons,
    required this.completedLessons,
    required this.totalLessons,
  });

  factory ChapterModel.fromJson(Map<String, dynamic> json) {
    return ChapterModel(
      id: json['id'] as String,
      jlptLevel: json['jlptLevel'] as String? ?? 'N5',
      partNo: json['partNo'] as int? ?? 1,
      chapterNo: json['chapterNo'] as int? ?? 1,
      title: json['title'] as String? ?? '',
      topic: json['topic'] as String?,
      lessons: (json['lessons'] as List<dynamic>? ?? [])
          .map((e) => LessonSummaryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      completedLessons: json['completedLessons'] as int? ?? 0,
      totalLessons: json['totalLessons'] as int? ?? 0,
    );
  }
}

class LessonSummaryModel {
  final String id;
  final int lessonNo;
  final int chapterLessonNo;
  final String title;
  final String topic;
  final int estimatedMinutes;
  final String status; // NOT_STARTED | IN_PROGRESS | COMPLETED
  final int scoreCorrect;
  final int scoreTotal;

  const LessonSummaryModel({
    required this.id,
    required this.lessonNo,
    required this.chapterLessonNo,
    required this.title,
    required this.topic,
    required this.estimatedMinutes,
    required this.status,
    required this.scoreCorrect,
    required this.scoreTotal,
  });

  factory LessonSummaryModel.fromJson(Map<String, dynamic> json) {
    return LessonSummaryModel(
      id: json['id'] as String,
      lessonNo: json['lessonNo'] as int? ?? 0,
      chapterLessonNo: json['chapterLessonNo'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      topic: json['topic'] as String? ?? '',
      estimatedMinutes: json['estimatedMinutes'] as int? ?? 10,
      status: json['status'] as String? ?? 'NOT_STARTED',
      scoreCorrect: json['scoreCorrect'] as int? ?? 0,
      scoreTotal: json['scoreTotal'] as int? ?? 0,
    );
  }
}

// ── Lesson 상세 ──

class LessonDetailModel {
  final String id;
  final int lessonNo;
  final int chapterLessonNo;
  final String title;
  final String? subtitle;
  final String topic;
  final int estimatedMinutes;
  final LessonContentModel content;
  final List<VocabItemModel> vocabItems;
  final List<GrammarItemModel> grammarItems;
  final LessonProgressModel? progress;

  const LessonDetailModel({
    required this.id,
    required this.lessonNo,
    required this.chapterLessonNo,
    required this.title,
    this.subtitle,
    required this.topic,
    required this.estimatedMinutes,
    required this.content,
    required this.vocabItems,
    required this.grammarItems,
    this.progress,
  });

  factory LessonDetailModel.fromJson(Map<String, dynamic> json) {
    return LessonDetailModel(
      id: json['id'] as String,
      lessonNo: json['lessonNo'] as int? ?? 0,
      chapterLessonNo: json['chapterLessonNo'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      topic: json['topic'] as String? ?? '',
      estimatedMinutes: json['estimatedMinutes'] as int? ?? 10,
      content: LessonContentModel.fromJson(
          json['content'] as Map<String, dynamic>? ?? {}),
      vocabItems: (json['vocabItems'] as List<dynamic>? ?? [])
          .map((e) => VocabItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      grammarItems: (json['grammarItems'] as List<dynamic>? ?? [])
          .map((e) => GrammarItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      progress: json['progress'] != null
          ? LessonProgressModel.fromJson(
              json['progress'] as Map<String, dynamic>)
          : null,
    );
  }
}

class LessonContentModel {
  final ReadingModel reading;
  final List<LessonQuestionModel> questions;

  const LessonContentModel({required this.reading, required this.questions});

  factory LessonContentModel.fromJson(Map<String, dynamic> json) {
    return LessonContentModel(
      reading:
          ReadingModel.fromJson(json['reading'] as Map<String, dynamic>? ?? {}),
      questions: (json['questions'] as List<dynamic>? ?? [])
          .map((e) => LessonQuestionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ReadingModel {
  final String type;
  final String? scene;
  final List<ScriptLineModel> script;
  final List<String> highlights;
  final String? audioUrl;

  const ReadingModel({
    this.type = 'dialogue',
    this.scene,
    required this.script,
    this.highlights = const [],
    this.audioUrl,
  });

  factory ReadingModel.fromJson(Map<String, dynamic> json) {
    return ReadingModel(
      type: json['type'] as String? ?? 'dialogue',
      scene: json['scene'] as String?,
      script: (json['script'] as List<dynamic>? ?? [])
          .map((e) => ScriptLineModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      highlights: (json['highlights'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      audioUrl: json['audioUrl'] as String?,
    );
  }
}

class ScriptLineModel {
  final String speaker;
  final String voiceId;
  final String text;
  final String? translation;

  const ScriptLineModel({
    required this.speaker,
    required this.voiceId,
    required this.text,
    this.translation,
  });

  factory ScriptLineModel.fromJson(Map<String, dynamic> json) {
    return ScriptLineModel(
      speaker: json['speaker'] as String? ?? '',
      voiceId: json['voiceId'] as String? ?? '',
      text: json['text'] as String? ?? '',
      translation: json['translation'] as String?,
    );
  }
}

class LessonQuestionModel {
  final int order;
  final String type; // VOCAB_MCQ | CONTEXT_CLOZE | SENTENCE_REORDER
  final String? cognitiveLevel;
  final String prompt;
  final List<QuizOptionModel>? options;
  final List<String>? tokens; // SENTENCE_REORDER
  final String? explanation;

  const LessonQuestionModel({
    required this.order,
    required this.type,
    this.cognitiveLevel,
    required this.prompt,
    this.options,
    this.tokens,
    this.explanation,
  });

  factory LessonQuestionModel.fromJson(Map<String, dynamic> json) {
    return LessonQuestionModel(
      order: json['order'] as int? ?? 0,
      type: json['type'] as String? ?? '',
      cognitiveLevel: json['cognitiveLevel'] as String?,
      prompt: json['prompt'] as String? ?? '',
      options: (json['options'] as List<dynamic>?)
          ?.map((e) => QuizOptionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      tokens:
          (json['tokens'] as List<dynamic>?)?.map((e) => e as String).toList(),
      explanation: json['explanation'] as String?,
    );
  }
}

class QuizOptionModel {
  final String id;
  final String text;

  const QuizOptionModel({required this.id, required this.text});

  factory QuizOptionModel.fromJson(Map<String, dynamic> json) {
    return QuizOptionModel(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
    );
  }
}

class VocabItemModel {
  final String id;
  final String word;
  final String reading;
  final String meaningKo;
  final String partOfSpeech;

  const VocabItemModel({
    required this.id,
    required this.word,
    required this.reading,
    required this.meaningKo,
    required this.partOfSpeech,
  });

  factory VocabItemModel.fromJson(Map<String, dynamic> json) {
    return VocabItemModel(
      id: json['id'] as String? ?? '',
      word: json['word'] as String? ?? '',
      reading: json['reading'] as String? ?? '',
      meaningKo: json['meaningKo'] as String? ?? '',
      partOfSpeech: json['partOfSpeech'] as String? ?? '',
    );
  }
}

class GrammarItemModel {
  final String id;
  final String pattern;
  final String meaningKo;
  final String explanation;

  const GrammarItemModel({
    required this.id,
    required this.pattern,
    required this.meaningKo,
    required this.explanation,
  });

  factory GrammarItemModel.fromJson(Map<String, dynamic> json) {
    return GrammarItemModel(
      id: json['id'] as String? ?? '',
      pattern: json['pattern'] as String? ?? '',
      meaningKo: json['meaningKo'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
    );
  }

  String get normalizedPatternKey => normalizeGrammarPatternKey(pattern);
}

String normalizeGrammarPatternKey(String pattern) {
  return pattern
      .replaceAll('〜', '~')
      .replaceAll('～', '~')
      .replaceAll(RegExp(r'\s+'), '')
      .toLowerCase();
}

class LessonProgressModel {
  final String status;
  final int attempts;
  final int scoreCorrect;
  final int scoreTotal;
  final String? startedAt;
  final String? completedAt;
  final String? srsRegisteredAt;

  const LessonProgressModel({
    required this.status,
    required this.attempts,
    required this.scoreCorrect,
    required this.scoreTotal,
    this.startedAt,
    this.completedAt,
    this.srsRegisteredAt,
  });

  factory LessonProgressModel.fromJson(Map<String, dynamic> json) {
    return LessonProgressModel(
      status: json['status'] as String? ?? 'NOT_STARTED',
      attempts: json['attempts'] as int? ?? 0,
      scoreCorrect: json['scoreCorrect'] as int? ?? 0,
      scoreTotal: json['scoreTotal'] as int? ?? 0,
      startedAt: json['startedAt'] as String?,
      completedAt: json['completedAt'] as String?,
      srsRegisteredAt: json['srsRegisteredAt'] as String?,
    );
  }
}

// ── Submit ──

class LessonSubmitResultModel {
  final int scoreCorrect;
  final int scoreTotal;
  final List<QuestionResultModel> results;
  final String status;
  final int srsItemsRegistered;

  const LessonSubmitResultModel({
    required this.scoreCorrect,
    required this.scoreTotal,
    required this.results,
    required this.status,
    this.srsItemsRegistered = 0,
  });

  factory LessonSubmitResultModel.fromJson(Map<String, dynamic> json) {
    return LessonSubmitResultModel(
      scoreCorrect: json['scoreCorrect'] as int? ?? 0,
      scoreTotal: json['scoreTotal'] as int? ?? 0,
      results: (json['results'] as List<dynamic>? ?? [])
          .map((e) => QuestionResultModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      status: json['status'] as String? ?? '',
      srsItemsRegistered: json['srsItemsRegistered'] as int? ?? 0,
    );
  }
}

class QuestionResultModel {
  final int order;
  final bool isCorrect;
  final String? correctAnswer;
  final List<String>? correctOrder;
  final String? explanation;
  final String? stateBefore;
  final String? stateAfter;
  final String? nextReviewAt;
  final bool isProvisionalPhase;

  const QuestionResultModel({
    required this.order,
    required this.isCorrect,
    this.correctAnswer,
    this.correctOrder,
    this.explanation,
    this.stateBefore,
    this.stateAfter,
    this.nextReviewAt,
    this.isProvisionalPhase = false,
  });

  factory QuestionResultModel.fromJson(Map<String, dynamic> json) {
    return QuestionResultModel(
      order: json['order'] as int? ?? 0,
      isCorrect: json['isCorrect'] as bool? ?? false,
      correctAnswer: json['correctAnswer'] as String?,
      correctOrder: (json['correctOrder'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      explanation: json['explanation'] as String?,
      stateBefore: json['stateBefore'] as String?,
      stateAfter: json['stateAfter'] as String?,
      nextReviewAt: json['nextReviewAt'] as String?,
      isProvisionalPhase: json['isProvisionalPhase'] as bool? ?? false,
    );
  }
}
