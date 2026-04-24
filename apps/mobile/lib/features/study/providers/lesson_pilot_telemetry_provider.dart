import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

typedef LessonPilotTelemetrySink = void Function(LessonPilotEvent event);
typedef LessonPilotBreadcrumbRecorder = Future<void> Function(
  Breadcrumb breadcrumb,
);

class LessonPilotEvent {
  const LessonPilotEvent({required this.name, required this.properties});

  final String name;
  final Map<String, Object> properties;

  @override
  String toString() => 'LessonPilotEvent($name, $properties)';
}

class LessonPilotEventNames {
  const LessonPilotEventNames._();

  static const lessonListViewed = 'lesson_list_viewed';
  static const lessonStarted = 'lesson_started';
  static const lessonStepCompleted = 'lesson_step_completed';
  static const lessonSubmitted = 'lesson_submitted';
  static const lessonCompleted = 'lesson_completed';
  static const lessonRetryClicked = 'lesson_retry_clicked';
  static const reviewCtaClicked = 'review_cta_clicked';
}

final lessonPilotTelemetrySinkProvider = Provider<LessonPilotTelemetrySink>((
  ref,
) {
  return LessonPilotSentryTelemetrySink().call;
});

final lessonPilotTelemetryProvider = Provider<LessonPilotTelemetry>((ref) {
  return LessonPilotTelemetry(ref.watch(lessonPilotTelemetrySinkProvider));
});

class LessonPilotTelemetry {
  const LessonPilotTelemetry(this._sink);

  final LessonPilotTelemetrySink _sink;

  void trackLessonListViewed({
    required String jlptLevel,
    required String source,
    required int chapterCount,
    required int lessonCount,
    String? recommendedLessonId,
  }) {
    _track(LessonPilotEventNames.lessonListViewed, {
      'jlptLevel': jlptLevel,
      'source': source,
      'chapterCount': chapterCount,
      'lessonCount': lessonCount,
      'recommendedLessonId': recommendedLessonId,
    });
  }

  void trackLessonStarted({
    required String lessonId,
    required int lessonNo,
    required int chapterLessonNo,
    required bool hasRecognitionStep,
    required bool hasReorderStep,
    required int recognitionQuestionCount,
    required int reorderQuestionCount,
  }) {
    _track(LessonPilotEventNames.lessonStarted, {
      'lessonId': lessonId,
      'lessonNo': lessonNo,
      'chapterLessonNo': chapterLessonNo,
      'hasRecognitionStep': hasRecognitionStep,
      'hasReorderStep': hasReorderStep,
      'recognitionQuestionCount': recognitionQuestionCount,
      'reorderQuestionCount': reorderQuestionCount,
    });
  }

  void trackLessonStepCompleted({
    required String lessonId,
    required String step,
    bool skipped = false,
  }) {
    _track(LessonPilotEventNames.lessonStepCompleted, {
      'lessonId': lessonId,
      'step': step,
      'skipped': skipped,
    });
  }

  void trackLessonSubmitted({
    required String lessonId,
    required String outcome,
    required int answerCount,
    String? status,
    int? scoreCorrect,
    int? scoreTotal,
    int? srsItemsRegistered,
    String? errorType,
  }) {
    _track(LessonPilotEventNames.lessonSubmitted, {
      'lessonId': lessonId,
      'outcome': outcome,
      'answerCount': answerCount,
      'status': status,
      'scoreCorrect': scoreCorrect,
      'scoreTotal': scoreTotal,
      'srsItemsRegistered': srsItemsRegistered,
      'errorType': errorType,
    });
  }

  void trackLessonCompleted({
    required String lessonId,
    required int scoreCorrect,
    required int scoreTotal,
    required int srsItemsRegistered,
  }) {
    _track(LessonPilotEventNames.lessonCompleted, {
      'lessonId': lessonId,
      'scoreCorrect': scoreCorrect,
      'scoreTotal': scoreTotal,
      'srsItemsRegistered': srsItemsRegistered,
    });
  }

  void trackLessonRetryClicked({required String lessonId}) {
    _track(LessonPilotEventNames.lessonRetryClicked, {'lessonId': lessonId});
  }

  void trackReviewCtaClicked({
    required String jlptLevel,
    required int totalDue,
    required int wordDue,
    required int grammarDue,
    required String quizType,
  }) {
    _track(LessonPilotEventNames.reviewCtaClicked, {
      'jlptLevel': jlptLevel,
      'totalDue': totalDue,
      'wordDue': wordDue,
      'grammarDue': grammarDue,
      'quizType': quizType,
    });
  }

  void _track(String name, Map<String, Object?> properties) {
    _sink(LessonPilotEvent(name: name, properties: _compact(properties)));
  }

  static Map<String, Object> _compact(Map<String, Object?> properties) {
    return {
      for (final entry in properties.entries)
        if (entry.value != null) entry.key: entry.value!,
    };
  }
}

class LessonPilotSentryTelemetrySink {
  LessonPilotSentryTelemetrySink({
    this.debugLog = kDebugMode,
    LessonPilotBreadcrumbRecorder? recordBreadcrumb,
  }) : _recordBreadcrumb = recordBreadcrumb ??
            ((breadcrumb) => Sentry.addBreadcrumb(breadcrumb));

  static const _category = 'harukoto.lesson_pilot';

  final bool debugLog;
  final LessonPilotBreadcrumbRecorder _recordBreadcrumb;

  void call(LessonPilotEvent event) {
    if (debugLog) {
      debugPrint('[LessonPilotTelemetry] $event');
    }

    unawaited(
      _recordBreadcrumb(
        Breadcrumb(
          category: _category,
          message: event.name,
          level: SentryLevel.info,
          data: event.properties,
        ),
      ).catchError((Object error, StackTrace stackTrace) {
        if (debugLog) {
          debugPrint(
            '[LessonPilotTelemetry] Failed to record breadcrumb: $error',
          );
        }
      }),
    );
  }
}
