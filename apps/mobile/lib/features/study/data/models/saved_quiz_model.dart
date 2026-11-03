import 'quiz_session_model.dart';

/// List summaries deliberately do not contain answers or a correctness score.
class SavedQuizModel {
  const SavedQuizModel({
    required this.id,
    required this.quizType,
    required this.jlptLevel,
    required this.mode,
    required this.totalQuestions,
    required this.answeredCount,
    required this.remainingCount,
    required this.startedAt,
    required this.resumeStatus,
    this.resumeReason,
  });

  final String id;
  final String quizType;
  final String jlptLevel;
  final String? mode;
  final int totalQuestions;
  final int answeredCount;
  final int? remainingCount;
  final String startedAt;
  final String resumeStatus;
  final String? resumeReason;

  bool get canResume =>
      resumeStatus == 'available' &&
      (mode == null ||
          const {
            'normal',
            'smart',
            'review',
            'wrong_answer_review',
            'matching',
            'arrange',
            'cloze',
            'typing',
          }.contains(mode)) &&
      totalQuestions > 0 &&
      answeredCount >= 0 &&
      answeredCount <= totalQuestions &&
      remainingCount == totalQuestions - answeredCount;

  bool get readyForResult => canResume && remainingCount == 0;

  String get actionLabel => readyForResult ? '결과 확인하기' : '이어서 풀기';

  String get categoryLabel => switch (quizType) {
        'VOCABULARY' => '단어',
        'GRAMMAR' => '문법',
        'KANJI' => '한자',
        'LISTENING' => '듣기',
        'CLOZE' => '빈칸 채우기',
        'SENTENCE_ARRANGE' => '문장 배열',
        _ => '퀴즈',
      };

  String get modeLabel => switch (mode) {
        'matching' => '짝 맞추기',
        'arrange' => '문장 배열',
        'cloze' => '빈칸 채우기',
        'typing' => '직접 입력',
        'wrong_answer_review' => '이번 오답 복습',
        'smart' => '추천 퀴즈',
        'review' => '복습',
        _ => '기본 퀴즈',
      };

  String get startedLabel {
    final parsed = DateTime.tryParse(startedAt);
    if (parsed == null) return '시작일 확인 필요';
    // The contract is UTC with an offset. Handle legacy naive UTC only on read.
    final utc = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(startedAt)
        ? parsed.toUtc()
        : DateTime.utc(parsed.year, parsed.month, parsed.day, parsed.hour,
            parsed.minute, parsed.second);
    final kst = utc.add(const Duration(hours: 9));
    return '${kst.year}.${kst.month.toString().padLeft(2, '0')}.${kst.day.toString().padLeft(2, '0')} 시작';
  }

  factory SavedQuizModel.fromJson(Map<String, dynamic> json) => SavedQuizModel(
        id: json['id'] as String,
        quizType: json['quizType'] as String,
        jlptLevel: json['jlptLevel'] as String,
        mode: json['mode'] as String?,
        totalQuestions: json['totalQuestions'] as int,
        answeredCount: json['answeredCount'] as int,
        remainingCount: json['remainingCount'] as int?,
        startedAt: json['startedAt'] as String,
        resumeStatus: json['resumeStatus'] as String,
        resumeReason: json['resumeReason'] as String?,
      );

  factory SavedQuizModel.fromLegacy(IncompleteSessionModel session) =>
      SavedQuizModel(
        id: session.id,
        quizType: session.quizType,
        jlptLevel: session.jlptLevel,
        mode: session.mode,
        totalQuestions: session.totalQuestions,
        answeredCount: session.answeredCount,
        remainingCount: session.canResume
            ? session.totalQuestions - session.answeredCount
            : null,
        startedAt: session.startedAt,
        resumeStatus: session.resumeStatus ?? 'available',
      );
}

class SavedQuizPageModel {
  const SavedQuizPageModel({
    required this.sessions,
    this.nextCursor,
    this.legacyFallback = false,
  });

  final List<SavedQuizModel> sessions;
  final String? nextCursor;
  final bool legacyFallback;

  factory SavedQuizPageModel.fromJson(Map<String, dynamic> json) =>
      SavedQuizPageModel(
        sessions: (json['sessions'] as List<dynamic>)
            .map((value) =>
                SavedQuizModel.fromJson(value as Map<String, dynamic>))
            .toList(growable: false),
        nextCursor: json['nextCursor'] as String?,
      );
}
