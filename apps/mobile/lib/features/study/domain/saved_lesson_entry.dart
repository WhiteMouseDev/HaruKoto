import 'dart:convert';

import '../data/models/lesson_models.dart';
import 'lesson_session_state.dart';

/// A local navigation hint, never proof that a checkpoint can be restored.
/// The lesson page still validates fresh server content and progress.
class SavedLessonHint {
  const SavedLessonHint(
      {this.step,
      this.needsRecordCheck = false,
      this.submissionPending = false});

  final LessonStep? step;
  final bool needsRecordCheck;
  final bool submissionPending;

  String get label {
    if (submissionPending) return '제출 기록 확인';
    if (needsRecordCheck) return '저장 기록 확인';
    return switch (step) {
      LessonStep.vocabLearning => '단어 학습 저장 위치',
      LessonStep.grammarLearning => '문법 학습 저장 위치',
      LessonStep.guidedReading => '대화 읽기 저장 위치',
      LessonStep.recognition => '이해 확인 저장 위치',
      LessonStep.matching => '단어 매칭 저장 위치',
      LessonStep.sentenceReorder => '문장 배열 저장 위치',
      _ => '저장 기록 확인',
    };
  }

  String get actionLabel => needsRecordCheck ? '기록 확인' : '저장 위치 열기';

  static SavedLessonHint? inspect(String raw, String lessonId) {
    const unknown = SavedLessonHint(needsRecordCheck: true);
    if (raw.length > 512 * 1024) return unknown;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return unknown;
      // Never attach a different lesson's payload to a known curriculum key.
      if (json['lessonId'] is String && json['lessonId'] != lessonId) {
        return null;
      }
      if (json['lessonId'] != lessonId) return unknown;
      if (json['version'] != 1) return unknown;
      if (json['submissionPending'] == true) {
        return const SavedLessonHint(
            needsRecordCheck: true, submissionPending: true);
      }
      if (json['acknowledged'] == true && json['submissionPending'] == false) {
        return null;
      }
      if (json['submissionPending'] != false ||
          json['acknowledged'] != false ||
          json['practiceStarted'] is! bool ||
          json['progressStamp'] is! String ||
          json['content'] is! String ||
          json['layout'] is! Map<String, dynamic> ||
          json['answers'] is! Map<String, dynamic> ||
          json['seed'] is! int ||
          (json['seed'] as int) < 0) {
        return unknown;
      }
      final content = jsonDecode(json['content'] as String);
      if (content is! Map<String, dynamic> || content['id'] != lessonId) {
        return unknown;
      }
      final step = LessonStep.values
          .where((step) => step.name == json['step'])
          .firstOrNull;
      if (step == null || step == LessonStep.result) return unknown;
      if (step == LessonStep.contextPreview) return null;
      if (step.index >= LessonStep.recognition.index &&
          json['practiceStarted'] != true) {
        return unknown;
      }
      for (final key in [
        'vocabIndex',
        'grammarIndex',
        'recognitionIndex',
        'reorderIndex'
      ]) {
        if (json[key] is! int || (json[key] as int) < 0) return unknown;
      }
      return SavedLessonHint(step: step);
    } on FormatException {
      return unknown;
    }
  }
}

class SavedLessonEntry {
  const SavedLessonEntry(
      {required this.accountId,
      required this.jlptLevel,
      required this.chapter,
      required this.lesson,
      required this.hint});
  final String accountId;
  final String jlptLevel;
  final ChapterModel chapter;
  final LessonSummaryModel lesson;
  final SavedLessonHint hint;
}

class SavedLessonEntries {
  const SavedLessonEntries(
      {this.accountId,
      this.jlptLevel,
      this.entries = const [],
      this.failedLessonIds = const []});
  final String? accountId;
  final String? jlptLevel;
  final List<SavedLessonEntry> entries;
  final List<String> failedLessonIds;
}
