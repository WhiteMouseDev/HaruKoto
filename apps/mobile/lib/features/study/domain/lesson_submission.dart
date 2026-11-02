import 'dart:convert';
import 'dart:math';

import '../../../core/network/api_exception.dart';
import '../data/models/lesson_models.dart';

/// Frozen request stored in the SAME checkpoint key before any network write.
/// Its answers and response times must never be reconstructed on retry.
// OPENAPI_SCHEMA: LessonSubmissionRequest
class LessonSubmissionDraft {
  LessonSubmissionDraft._(this._json);
  final Map<String, dynamic> _json;

  String get submissionId => _json['submissionId'] as String;
  String get owner => _json['expectedUserId'] as String;
  Map<String, dynamic> toJson() =>
      jsonDecode(jsonEncode(_json)) as Map<String, dynamic>;

  factory LessonSubmissionDraft.create({
    required String owner,
    required List<Map<String, dynamic>> answers,
  }) {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final id = '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    return LessonSubmissionDraft.fromJson({
      'submissionId': id,
      'expectedUserId': owner,
      'answers': [
        for (final answer in answers)
          {
            'order': answer['order'],
            'selectedAnswer': answer['selectedAnswer'],
            'submittedOrder': answer['submittedOrder'],
            'responseMs': answer['responseMs'] ?? 0,
          }
      ],
    });
  }

  factory LessonSubmissionDraft.fromJson(Map<String, dynamic> json) {
    if (json.keys.toSet().difference(
            {'submissionId', 'expectedUserId', 'answers'}).isNotEmpty ||
        !_uuidV4.hasMatch(json['submissionId'] is String
            ? json['submissionId'] as String
            : '') ||
        json['expectedUserId'] is! String ||
        (json['expectedUserId'] as String).isEmpty ||
        json['answers'] is! List) {
      throw const FormatException('Invalid frozen submission');
    }
    for (final answer in json['answers'] as List) {
      if (answer is! Map<String, dynamic> ||
          answer.keys.toSet().difference({
            'order',
            'selectedAnswer',
            'submittedOrder',
            'responseMs'
          }).isNotEmpty ||
          answer['order'] is! int ||
          answer['responseMs'] is! int ||
          (answer['responseMs'] as int) < 0 ||
          (answer['selectedAnswer'] != null &&
              answer['selectedAnswer'] is! String) ||
          (answer['submittedOrder'] != null &&
              (answer['submittedOrder'] is! List ||
                  (answer['submittedOrder'] as List)
                      .any((token) => token is! String)))) {
        throw const FormatException('Invalid frozen answer');
      }
    }
    return LessonSubmissionDraft._(
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>);
  }
}

final _uuidV4 = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$');

class LessonSubmissionEnvelope {
  const LessonSubmissionEnvelope({
    required this.lessonId,
    required this.submission,
    required this.draft,
    this.title,
    this.jlptLevel,
    this.acknowledged = false,
  });
  final String lessonId;
  final LessonSubmissionDraft submission;
  final Map<String, dynamic> draft;
  final String? title;
  final String? jlptLevel;
  final bool acknowledged;

  String encode({bool? acknowledged}) => jsonEncode({
        'version': 2,
        'lessonId': lessonId,
        // Current older readers preserve this unknown version as pending.
        'submissionPending': true,
        'acknowledged': acknowledged ?? this.acknowledged,
        if (draft['lastStudiedAtMs'] != null)
          'lastStudiedAtMs': draft['lastStudiedAtMs'],
        'protocolVersion': 1,
        'submission': submission.toJson(),
        'draft': draft,
        if (title != null) 'title': title,
        if (jlptLevel != null) 'jlptLevel': jlptLevel,
      });

  static LessonSubmissionEnvelope? inspect(
      String raw, String owner, String lessonId) {
    if (raw.length > 512 * 1024) {
      throw const FormatException('checkpoint too large');
    }
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Invalid checkpoint');
    }
    if (json['version'] == 1) return null;
    if (json['version'] != 2 ||
        json['protocolVersion'] != 1 ||
        json['lessonId'] != lessonId ||
        json['submissionPending'] != true ||
        json['acknowledged'] is! bool ||
        json['submission'] is! Map<String, dynamic> ||
        json['draft'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid submission envelope');
    }
    final submission = LessonSubmissionDraft.fromJson(
        json['submission'] as Map<String, dynamic>);
    final draft = json['draft'] as Map<String, dynamic>;
    if (submission.owner != owner ||
        draft['lessonId'] != lessonId ||
        draft['version'] != 1 ||
        draft['submissionPending'] != true ||
        draft['answers'] is! Map<String, dynamic>) {
      throw const FormatException('Submission owner or lesson mismatch');
    }
    final answers = draft['answers'] as Map<String, dynamic>;
    final orders = answers.keys.map(int.parse).toList()..sort();
    final normalized = [
      for (final order in orders)
        if (answers['$order'] is Map<String, dynamic>)
          {
            'order': (answers['$order'] as Map<String, dynamic>)['order'],
            'selectedAnswer':
                (answers['$order'] as Map<String, dynamic>)['selectedAnswer'],
            'submittedOrder':
                (answers['$order'] as Map<String, dynamic>)['submittedOrder'],
            'responseMs':
                (answers['$order'] as Map<String, dynamic>)['responseMs'] ?? 0,
          }
        else
          throw const FormatException('Invalid original draft answer'),
    ];
    if (jsonEncode(normalized) != jsonEncode(submission.toJson()['answers'])) {
      throw const FormatException(
          'Frozen submission differs from original answers');
    }
    return LessonSubmissionEnvelope(
      lessonId: lessonId,
      submission: submission,
      draft: draft,
      acknowledged: json['acknowledged'] as bool,
      title: json['title'] is String ? json['title'] as String : null,
      jlptLevel:
          json['jlptLevel'] is String ? json['jlptLevel'] as String : null,
    );
  }
}

// OPENAPI_SCHEMA: LessonSubmissionResponse
class LessonSubmissionReceiptModel {
  const LessonSubmissionReceiptModel({
    required this.submissionId,
    required this.processedAt,
    required this.result,
  });
  final String submissionId;
  final DateTime processedAt;
  final LessonSubmitResultModel result;

  factory LessonSubmissionReceiptModel.fromJson(Map<String, dynamic> json) {
    final result = json['result'];
    final processedAt = json['processedAt'];
    if (json['submissionId'] is! String ||
        !_uuidV4.hasMatch(json['submissionId'] as String) ||
        processedAt is! String ||
        !RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(processedAt) ||
        result is! Map<String, dynamic> ||
        result['scoreCorrect'] is! int ||
        result['scoreTotal'] is! int ||
        result['srsItemsRegistered'] is! int ||
        result['results'] is! List ||
        !{'COMPLETED', 'IN_PROGRESS'}.contains(result['status'])) {
      throw const FormatException('Invalid submission receipt');
    }
    for (final row in result['results'] as List) {
      if (row is! Map<String, dynamic> ||
          row['order'] is! int ||
          row['isCorrect'] is! bool) {
        throw const FormatException('Invalid receipt result');
      }
    }
    return LessonSubmissionReceiptModel(
      submissionId: json['submissionId'] as String,
      processedAt: DateTime.parse(processedAt).toUtc(),
      result: LessonSubmitResultModel.fromJson(result),
    );
  }
}

/// Domain wording is deliberately scoped to the new lesson receipt endpoints.
class LessonSubmissionException extends ApiException {
  LessonSubmissionException(ApiException error)
      : super(
            message: error.message,
            statusCode: error.statusCode,
            errorCode: error.errorCode,
            requestPath: error.requestPath);

  @override
  String get userMessage => switch (statusCode) {
        401 => '같은 계정으로 로그인을 확인한 뒤 제출 결과를 다시 확인해 주세요.',
        403 => '제출을 시작한 계정과 현재 계정이 달라요. 원래 계정에서 확인해 주세요.',
        404 || 405 => '서버에서 제출을 확인하지 못했어요. 저장된 답안은 보관하고 있어요.',
        409 => '저장된 제출 정보가 서버 기록과 달라요. 새 제출로 바꾸지 않고 보관할게요.',
        _ => super.userMessage,
      };
}
