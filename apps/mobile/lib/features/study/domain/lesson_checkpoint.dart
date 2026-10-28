import 'dart:convert';

import '../data/models/lesson_models.dart';
import 'lesson_flow_policy.dart';
import 'lesson_practice_layout.dart';
import 'lesson_session_state.dart';

class LessonCheckpoint {
  const LessonCheckpoint(
      {required this.state,
      required this.progressStamp,
      this.acknowledged = false,
      this.lastStudiedAt});

  final LessonSessionState state;
  final String progressStamp;
  final bool acknowledged;
  final DateTime? lastStudiedAt;

  /// Optional ranking metadata never makes a valid saved answer unreadable.
  static DateTime? readLastStudiedAt(Map<String, dynamic> json) {
    final value = json['lastStudiedAtMs'];
    if (value is! int || value <= 0 || value > 253402300799999) return null;
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }

  String encode(LessonDetailModel detail) => jsonEncode({
        'version': 1,
        if (lastStudiedAt != null)
          'lastStudiedAtMs': lastStudiedAt!.toUtc().millisecondsSinceEpoch,
        'lessonId': detail.id,
        'content': lessonContentSignature(detail),
        'progressStamp': progressStamp,
        'acknowledged': acknowledged,
        'step': state.step.name,
        'vocabIndex': state.vocabIndex,
        'grammarIndex': state.grammarIndex,
        'recognitionIndex': state.recognitionIndex,
        'reorderIndex': state.reorderIndex,
        'answers': {
          for (final entry in state.answers.entries) '${entry.key}': entry.value
        },
        'practiceStarted': state.practiceStarted,
        'submissionPending': state.submissionPending,
        'seed': state.seed,
        'layout': state.layout.toJson(),
        'recognitionSelection': state.recognitionSelection,
        'matchingMatched': state.matchingMatched.toList()..sort(),
        'matchingLeft': state.matchingLeft,
        'matchingRight': state.matchingRight,
        'reorderSelected': state.reorderSelected,
        'reorderAvailable': state.reorderAvailable,
      });

  factory LessonCheckpoint.decode(String raw, LessonDetailModel detail) {
    if (raw.length > 512 * 1024) {
      throw const FormatException('checkpoint too large');
    }
    final json = _map(jsonDecode(raw));
    if (json['version'] != 1 ||
        json['lessonId'] != detail.id ||
        json['content'] != lessonContentSignature(detail)) {
      throw const FormatException('checkpoint content changed');
    }
    final step = LessonStep.values
        .where((step) => step.name == json['step'])
        .firstOrNull;
    if (step == null ||
        (step == LessonStep.result && json['acknowledged'] != true)) {
      throw const FormatException('invalid step');
    }
    final recognition = lessonRecognitionQuestions(detail);
    final reorder = lessonReorderQuestions(detail);
    final layoutJson = _map(json['layout']);
    final options = _stringLists(layoutJson['recognitionOptions']);
    if (options.length != recognition.length) {
      throw const FormatException('option count');
    }
    for (final question in recognition) {
      if (!_sameBag(options[question.order] ?? [], [
        for (final option in question.options ?? <QuizOptionModel>[]) option.id
      ])) {
        throw const FormatException('option order');
      }
    }
    final pairIds = _strings(layoutJson['matchingVocabIds']);
    final rightIndices = _ints(layoutJson['matchingRightIndices']);
    final seenMeanings = <String>{};
    if (pairIds.length > 4 ||
        pairIds.toSet().length != pairIds.length ||
        rightIndices.length != pairIds.length ||
        !_sameBag(rightIndices,
            List<int>.generate(pairIds.length, (index) => index))) {
      throw const FormatException('matching layout');
    }
    for (final id in pairIds) {
      final item = detail.vocabItems.where((item) => item.id == id).firstOrNull;
      if (item == null ||
          item.meaningKo.trim().isEmpty ||
          !seenMeanings.add(item.meaningKo.trim())) {
        throw const FormatException('matching pairs');
      }
    }
    final expectedPairCount = detail.vocabItems
        .map((item) => item.meaningKo.trim())
        .where((meaning) => meaning.isNotEmpty)
        .toSet()
        .length
        .clamp(0, 4);
    if (pairIds.length != expectedPairCount) {
      throw const FormatException('matching count');
    }
    final banks = _stringLists(layoutJson['reorderBanks']);
    if (banks.length != reorder.length) {
      throw const FormatException('bank count');
    }
    for (final question in reorder) {
      final bank = banks[question.order] ?? [];
      final tokens = question.tokens ?? [];
      final remainder = List<String>.from(bank);
      for (final token in tokens) {
        if (!remainder.remove(token)) {
          throw const FormatException('missing token');
        }
      }
      final distractors = detail.vocabItems
          .map((item) => item.word)
          .where((word) => word.trim().isNotEmpty && !tokens.contains(word))
          .toSet();
      if (remainder.length != distractors.length.clamp(0, 3) ||
          remainder.toSet().length != remainder.length ||
          !distractors.containsAll(remainder)) {
        throw const FormatException('invalid distractor');
      }
    }
    final recognitionIndex =
        _index(json['recognitionIndex'], recognition.length);
    final reorderIndex = _index(json['reorderIndex'], reorder.length);
    final vocabIndex =
        _index(json['vocabIndex'], uniqueLessonVocab(detail).length);
    final grammarIndex =
        _index(json['grammarIndex'], uniqueLessonGrammar(detail).length);
    if ((step == LessonStep.recognition && recognition.isEmpty) ||
        (step == LessonStep.sentenceReorder && reorder.isEmpty) ||
        (step == LessonStep.grammarLearning && detail.grammarItems.isEmpty)) {
      throw const FormatException('empty step');
    }
    final answersJson = _map(json['answers']);
    final answers = <int, Map<String, dynamic>>{};
    for (final entry in answersJson.entries) {
      final order = int.tryParse(entry.key);
      final question = detail.content.questions
          .where((question) => question.order == order)
          .firstOrNull;
      final answer = _map(entry.value);
      if (order == null ||
          question == null ||
          answer['order'] != order ||
          answer['responseMs'] is! int ||
          (answer['responseMs'] as int) < 0) {
        throw const FormatException('invalid answer');
      }
      if (question.type == 'SENTENCE_REORDER') {
        final submitted = _strings(answer['submittedOrder']);
        final bank = banks[order] ?? [];
        if (submitted.length != (question.tokens ?? []).length ||
            !_isSubBag(submitted, bank) ||
            answer.containsKey('selectedAnswer')) {
          throw const FormatException('invalid reorder answer');
        }
      } else if (answer['selectedAnswer'] is! String ||
          !(question.options ?? [])
              .any((option) => option.id == answer['selectedAnswer']) ||
          answer.containsKey('submittedOrder')) {
        throw const FormatException('invalid choice answer');
      }
      answers[order] = answer;
    }
    final selected = json['recognitionSelection'];
    if (selected != null &&
        (selected is! String ||
            recognition.isEmpty ||
            !(recognition[recognitionIndex].options ?? [])
                .any((option) => option.id == selected))) {
      throw const FormatException('invalid selected option');
    }
    final matched = _ints(json['matchingMatched']);
    if (matched.toSet().length != matched.length ||
        matched.any((index) => index < 0 || index >= pairIds.length)) {
      throw const FormatException('invalid matched index');
    }
    final left = _nullableIndex(json['matchingLeft'], pairIds.length);
    final right = _nullableIndex(json['matchingRight'], pairIds.length);
    if (matched.contains(left) || matched.contains(right)) {
      throw const FormatException('matched selection');
    }
    final reorderSelected = _strings(json['reorderSelected']);
    final reorderAvailable = json['reorderAvailable'] == null
        ? null
        : _strings(json['reorderAvailable']);
    if (reorder.isEmpty) {
      if (reorderSelected.isNotEmpty || reorderAvailable != null) {
        throw const FormatException('unexpected bank');
      }
    } else if (reorderAvailable != null) {
      if (reorderSelected.length >
              (reorder[reorderIndex].tokens ?? []).length ||
          !_sameBag([...reorderSelected, ...reorderAvailable],
              banks[reorder[reorderIndex].order] ?? [])) {
        throw const FormatException('reorder multiset');
      }
    } else if (reorderSelected.isNotEmpty) {
      throw const FormatException('missing bank');
    }
    final seed = json['seed'];
    if (seed is! int ||
        seed < 0 ||
        json['practiceStarted'] is! bool ||
        json['submissionPending'] is! bool ||
        json['acknowledged'] is! bool ||
        json['progressStamp'] is! String) {
      throw const FormatException('invalid checkpoint flags');
    }
    if (!(json['practiceStarted'] as bool) &&
        (step.index >= LessonStep.recognition.index ||
            answers.isNotEmpty ||
            (json['submissionPending'] as bool))) {
      throw const FormatException('practice not started');
    }
    // Answered questions before the current position must be present. Going
    // backwards may retain later answers; that must never erase their history.
    for (final question in recognition.take(recognitionIndex)) {
      if (!answers.containsKey(question.order)) {
        throw const FormatException('missing earlier answer');
      }
    }
    for (final question in reorder.take(reorderIndex)) {
      if (!answers.containsKey(question.order)) {
        throw const FormatException('missing earlier reorder');
      }
    }
    return LessonCheckpoint(
      progressStamp: json['progressStamp'] as String,
      acknowledged: json['acknowledged'] as bool,
      lastStudiedAt: readLastStudiedAt(json),
      state: LessonSessionState(
        step: step,
        vocabIndex: vocabIndex,
        grammarIndex: grammarIndex,
        recognitionIndex: recognitionIndex,
        reorderIndex: reorderIndex,
        answers: answers,
        hasRecognitionStep: recognition.isNotEmpty,
        hasReorderStep: reorder.isNotEmpty,
        practiceStarted: json['practiceStarted'] as bool,
        submissionPending: json['submissionPending'] as bool,
        seed: seed,
        layout: LessonPracticeLayout(
            recognitionOptions: options,
            matchingVocabIds: pairIds,
            matchingRightIndices: rightIndices,
            reorderBanks: banks),
        recognitionSelection: selected as String?,
        matchingMatched: matched.toSet(),
        matchingLeft: left,
        matchingRight: right,
        reorderSelected: reorderSelected,
        reorderAvailable: reorderAvailable,
        restored: true,
      ),
    );
  }
}

String lessonProgressStamp(LessonProgressModel? progress) =>
    jsonEncode(progress == null
        ? null
        : {
            'status': progress.status,
            'attempts': progress.attempts,
            'scoreCorrect': progress.scoreCorrect,
            'scoreTotal': progress.scoreTotal,
            'startedAt': progress.startedAt,
            'completedAt': progress.completedAt,
            'srsRegisteredAt': progress.srsRegisteredAt,
          });

/// Canonical, collision-free equality over the content used by all lesson
/// steps. Do not use hashCode: it is not a persistent content identifier.
String lessonContentSignature(LessonDetailModel detail) => jsonEncode({
      'id': detail.id,
      'title': detail.title,
      'subtitle': detail.subtitle,
      'lessonNo': detail.lessonNo,
      'chapterLessonNo': detail.chapterLessonNo,
      'topic': detail.topic,
      'reading': {
        'type': detail.content.reading.type,
        'scene': detail.content.reading.scene,
        'script': [
          for (final line in detail.content.reading.script)
            [line.speaker, line.voiceId, line.text, line.translation]
        ],
        'highlights': detail.content.reading.highlights,
        'audioUrl': detail.content.reading.audioUrl
      },
      'questions': [
        for (final question in detail.content.questions)
          {
            'order': question.order,
            'type': question.type,
            'cognitiveLevel': question.cognitiveLevel,
            'prompt': question.prompt,
            'options': [
              for (final option in question.options ?? <QuizOptionModel>[])
                [option.id, option.text]
            ],
            'correctAnswer': question.correctAnswer,
            'tokens': question.tokens,
            'explanation': question.explanation,
          }
      ],
      'vocab': [
        for (final item in detail.vocabItems)
          [item.id, item.word, item.reading, item.meaningKo, item.partOfSpeech]
      ],
      'grammar': [
        for (final item in detail.grammarItems)
          [item.id, item.pattern, item.meaningKo, item.explanation]
      ],
    });

Map<String, dynamic> _map(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('expected map');
  }
  return value;
}

List<String> _strings(Object? value) {
  if (value is! List || value.any((item) => item is! String)) {
    throw const FormatException('expected strings');
  }
  return value.cast<String>();
}

List<int> _ints(Object? value) {
  if (value is! List || value.any((item) => item is! int)) {
    throw const FormatException('expected indices');
  }
  return value.cast<int>();
}

Map<int, List<String>> _stringLists(Object? value) => {
      for (final entry in _map(value).entries)
        _order(entry.key): _strings(entry.value),
    };
int _order(String value) {
  final order = int.tryParse(value);
  if (order == null) throw const FormatException('invalid order');
  return order;
}

int _index(Object? value, int length) {
  if (value is! int ||
      value < 0 ||
      (length == 0 ? value != 0 : value >= length)) {
    throw const FormatException('index out of range');
  }
  return value;
}

int? _nullableIndex(Object? value, int length) =>
    value == null ? null : _index(value, length == 0 ? -1 : length);
bool _sameBag<T>(List<T> a, List<T> b) =>
    a.length == b.length && _isSubBag(a, b);
bool _isSubBag<T>(List<T> a, List<T> b) {
  final remainder = List<T>.from(b);
  return a.every(remainder.remove);
}
