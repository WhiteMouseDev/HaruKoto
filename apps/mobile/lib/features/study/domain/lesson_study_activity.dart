import 'dart:convert';
import 'dart:math';

String newLessonActivityId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
final _uuid4 = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$');
final lessonActivityVersionPattern = RegExp(r'^[0-9a-f]{64}$');

/// An immutable attendance request. It never replaces the graded submission.
// The three discriminated request variants have these same top-level fields;
// answer/kind are validated together below (also Reorder/Matching variants).
// OPENAPI_SCHEMA: RecognitionStudyActivityRequest
class LessonStudyActivityDraft {
  LessonStudyActivityDraft._(Map<String, dynamic> json)
      : _encoded = jsonEncode(json),
        expectedUserId = json['expectedUserId'] as String,
        activityId = json['activityId'] as String,
        attemptId = json['attemptId'] as String,
        contentVersion = json['contentVersion'] as String,
        kind = json['kind'] as String,
        answer = Map<String, dynamic>.unmodifiable({
          for (final entry in (json['answer'] as Map<String, dynamic>).entries)
            entry.key: entry.value is List
                ? List<dynamic>.unmodifiable(entry.value as List)
                : entry.value,
        });
  final String _encoded;
  final String expectedUserId;
  final String activityId;
  final String attemptId;
  final String contentVersion;
  final String kind;
  final Map<String, dynamic> answer;

  Map<String, dynamic> toJson() => jsonDecode(_encoded) as Map<String, dynamic>;
  String get owner => expectedUserId;

  factory LessonStudyActivityDraft.create({
    required String owner,
    required String attemptId,
    required String contentVersion,
    required String kind,
    required Map<String, dynamic> answer,
  }) =>
      LessonStudyActivityDraft.fromJson({
        'expectedUserId': owner,
        'attemptId': attemptId,
        'activityId': newLessonActivityId(),
        'contentVersion': contentVersion,
        'kind': kind,
        'answer': answer,
      });

  factory LessonStudyActivityDraft.fromJson(Map<String, dynamic> json) {
    final answer = json['answer'];
    if (json.keys.toSet().difference({
          'expectedUserId',
          'attemptId',
          'activityId',
          'contentVersion',
          'kind',
          'answer'
        }).isNotEmpty ||
        !_uuid.hasMatch('${json['expectedUserId']}') ||
        !_uuid4.hasMatch('${json['attemptId']}') ||
        !_uuid4.hasMatch('${json['activityId']}') ||
        !lessonActivityVersionPattern.hasMatch('${json['contentVersion']}') ||
        answer is! Map<String, dynamic>) {
      throw const FormatException('Invalid lesson activity request');
    }
    final valid = switch (json['kind']) {
      'RECOGNITION' => _hasOnly(answer, {'questionOrder', 'selectedAnswer'}) &&
          answer['questionOrder'] is int &&
          (answer['questionOrder'] as int) >= 1 &&
          _boundedActivityString(answer['selectedAnswer']),
      'SENTENCE_REORDER' =>
        _hasOnly(answer, {'questionOrder', 'submittedOrder'}) &&
            answer['questionOrder'] is int &&
            (answer['questionOrder'] as int) >= 1 &&
            answer['submittedOrder'] is List &&
            (answer['submittedOrder'] as List).isNotEmpty &&
            (answer['submittedOrder'] as List).length <= 256 &&
            (answer['submittedOrder'] as List).every(_boundedActivityString),
      'MATCHING' =>
        _hasOnly(answer, {'leftVocabularyId', 'rightVocabularyId'}) &&
            _uuid.hasMatch('${answer['leftVocabularyId']}') &&
            _uuid.hasMatch('${answer['rightVocabularyId']}'),
      _ => false,
    };
    if (!valid) throw const FormatException('Invalid lesson activity answer');
    return LessonStudyActivityDraft._(json);
  }
}

bool _hasOnly(Map<String, dynamic> value, Set<String> keys) =>
    value.keys.toSet().length == keys.length &&
    value.keys.toSet().difference(keys).isEmpty;

// Pydantic's string bounds count Unicode code points, including supplementary
// characters, rather than Dart's UTF-16 code units.
bool _boundedActivityString(Object? value) =>
    value is String && value.isNotEmpty && value.runes.length <= 4096;

// OPENAPI_SCHEMA: LessonStudyActivityResponse
class LessonStudyActivityReceipt {
  const LessonStudyActivityReceipt({
    required this.activityId,
    required this.processedAt,
    required this.studyDate,
  });
  final String activityId;
  final DateTime processedAt;
  final String studyDate;

  factory LessonStudyActivityReceipt.fromJson(Map<String, dynamic> json) {
    final timestamp = json['processedAt'];
    final day = json['studyDate'];
    if (!_uuid4.hasMatch('${json['activityId']}') ||
        timestamp is! String ||
        !RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(timestamp) ||
        day is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day)) {
      throw const FormatException('Invalid lesson activity receipt');
    }
    final parsed = DateTime.tryParse(timestamp)?.toUtc();
    final parsedDay = DateTime.tryParse(day);
    if (parsed == null ||
        parsedDay == null ||
        parsedDay.toIso8601String().substring(0, 10) != day ||
        parsed
                .add(const Duration(hours: 9))
                .toIso8601String()
                .substring(0, 10) !=
            day) {
      throw const FormatException('Invalid lesson activity day');
    }
    return LessonStudyActivityReceipt(
        activityId: json['activityId'] as String,
        processedAt: parsed,
        studyDate: day);
  }
}

class PendingLessonStudyActivity {
  const PendingLessonStudyActivity({
    required this.lessonId,
    required this.request,
    this.attempted = false,
  });
  final String lessonId;
  final LessonStudyActivityDraft request;
  final bool attempted;

  Map<String, dynamic> toJson() => {
        'request': request.toJson(),
        'attempted': attempted,
      };
}

/// All operations share the checkpoint store's read/modify/write queue.
abstract class LessonActivityJournalStore {
  Future<String?> readActivityAttemptId(String owner, String lessonId);
  Future<void> writeCheckpointAndActivities(
      String owner,
      String lessonId,
      String checkpoint,
      String attemptId,
      List<LessonStudyActivityDraft> requests);
  Future<List<PendingLessonStudyActivity>> pendingActivities(String owner);
  Future<void> markActivityAttempted(
      String owner, String lessonId, String activityId);
  Future<void> acknowledgeActivity(
      String owner, String lessonId, String activityId);
}
