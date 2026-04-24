import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/providers/lesson_pilot_telemetry_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  group('LessonPilotSentryTelemetrySink', () {
    test('records lesson pilot events as Sentry breadcrumbs', () async {
      final recorded = Completer<Breadcrumb>();
      final sink = LessonPilotSentryTelemetrySink(
        debugLog: false,
        recordBreadcrumb: (breadcrumb) async {
          recorded.complete(breadcrumb);
        },
      );

      sink(
        const LessonPilotEvent(
          name: LessonPilotEventNames.lessonCompleted,
          properties: {
            'lessonId': 'lesson-1',
            'scoreCorrect': 5,
            'scoreTotal': 5,
          },
        ),
      );

      final breadcrumb = await recorded.future;
      expect(breadcrumb.category, 'harukoto.lesson_pilot');
      expect(breadcrumb.message, LessonPilotEventNames.lessonCompleted);
      expect(breadcrumb.level, SentryLevel.info);
      expect(breadcrumb.data, {
        'lessonId': 'lesson-1',
        'scoreCorrect': 5,
        'scoreTotal': 5,
      });
    });
  });
}
