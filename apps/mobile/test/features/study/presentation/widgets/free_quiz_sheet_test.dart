import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_session_model.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/free_quiz_selection.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/free_quiz_sheet.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';

void main() {
  testWidgets('keeps the entry category and returns chosen level and mode',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      FreeQuizSelection? submitted;
      await _openSheet(
        tester,
        initial: const FreeQuizSelection(level: 'N4', type: 'GRAMMAR'),
        fetchStats: (level, type) {
          expect(type, 'GRAMMAR');
          return Future.value(level == 'N4' ? _n4Stats : _n5Stats);
        },
        onSubmit: (choice) => submitted = choice,
      );

      expect(find.text('문법 퀴즈 풀기'), findsOneWidget);
      expect(find.text('매칭'), findsNothing);
      expect(
        tester
            .getSemantics(find.text('4지선다'))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      expect(find.text('문법 96개'), findsOneWidget);
      expect(find.text('진행률 25%'), findsOneWidget);

      await tester.tap(find.text('N5'));
      await tester.pumpAndSettle();
      expect(find.text('문법 184개'), findsOneWidget);
      expect(find.text('진행률 0%'), findsOneWidget);

      await tester.tap(find.text('어순'));
      await tester.tap(find.text('퀴즈 시작'));
      await tester.pumpAndSettle();
      expect(submitted?.type, 'GRAMMAR');
      expect(submitted?.level, 'N5');
      expect(submitted?.mode, 'arrange');
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('first-step default opens at N5 and stats can retry',
      (tester) async {
    final pending = Completer<StudyStatsModel>();
    var attempts = 0;
    await _openSheet(
      tester,
      initial: const FreeQuizSelection(level: 'ABSOLUTE_ZERO'),
      fetchStats: (level, type) {
        expect(level, 'N5');
        expect(type, 'VOCABULARY');
        attempts++;
        return attempts == 1 ? pending.future : Future.value(_n5Stats);
      },
    );
    expect(find.text('진행률 불러오는 중'), findsOneWidget);
    expect(find.text('매칭'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);

    pending.completeError(StateError('No connection'));
    await tester.pumpAndSettle();
    expect(find.text('진행률을 불러오지 못했어요'), findsOneWidget);
    expect(find.text('진행률 0%'), findsNothing);

    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('단어 184개'), findsOneWidget);
    expect(find.text('진행률 0%'), findsOneWidget);
  });

  testWidgets('keeps controls reachable on a small dark screen with large text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _openSheet(
      tester,
      initial: const FreeQuizSelection(),
      fetchStats: (level, type) => Future.value(_n5Stats),
      brightness: Brightness.dark,
      textScaler: const TextScaler.linear(2),
    );
    await tester.ensureVisible(find.text('N1'));
    await tester.pumpAndSettle();
    expect(find.text('N1').hitTestable(), findsOneWidget);

    await tester.ensureVisible(find.text('퀴즈 시작'));
    await tester.pumpAndSettle();
    expect(find.text('퀴즈 시작').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

const _n4Stats = StudyStatsModel(
  totalCount: 96,
  studiedCount: 24,
  progress: 25,
);
const _n5Stats = StudyStatsModel(
  totalCount: 184,
  studiedCount: 0,
  progress: 0,
);

Future<void> _openSheet(
  WidgetTester tester, {
  required FreeQuizSelection initial,
  required Future<StudyStatsModel> Function(String level, String type)
      fetchStats,
  ValueChanged<FreeQuizSelection?>? onSubmit,
  Brightness brightness = Brightness.light,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: (attempt, error) => null,
      overrides: [
        for (final level in FreeQuizSelection.jlptLevels)
          quizStatsProvider((level: level, type: initial.type))
              .overrideWith((ref) => fetchStats(level, initial.type)),
      ],
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        builder: (context, widget) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: widget!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final selection = await showModalBottomSheet<FreeQuizSelection>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => FreeQuizSheet(initialSelection: initial),
                );
                onSubmit?.call(selection);
              },
              child: const Text('시트 열기'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('시트 열기'));
  await tester.pumpAndSettle();
}
