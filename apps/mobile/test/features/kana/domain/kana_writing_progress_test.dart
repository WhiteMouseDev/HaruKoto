import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/kana/domain/kana_writing_progress.dart';
import 'package:harukoto_mobile/features/kana/domain/katakana_pilot.dart';

void main() {
  const katakana = KanaWritingScope(owner: 'account-a', hiragana: false);
  const hiragana = KanaWritingScope(owner: 'account-a', hiragana: true);

  test('all 166 stable letter IDs round trip without rewriting review IDs', () {
    for (final scope in [hiragana, katakana]) {
      final letters = scope.hiragana
          ? HiraganaPilotLetter.values.cast<KanaPracticeLetter>()
          : KatakanaPilotLetter.values.cast<KanaPracticeLetter>();
      for (final letter in letters) {
        final progress = KanaWritingProgress(
            scope: scope,
            session: KanaWritingSession(
              letters: [letter],
              index: 0,
              step: KanaWritingStep.compare,
              mode: KanaWritingMode.comparison,
            ));
        final restored = KanaWritingProgress.decode(progress.encode(), scope);
        expect(restored.session!.letter, same(letter));
        expect(restored.session!.letters.single.reviewId, letter.reviewId);
      }
    }
    expect(
        HiraganaPilotLetter.values.length + KatakanaPilotLetter.values.length,
        166);
  });

  test('same glyph and stage restore including finished ink and reveal state',
      () {
    final original = KanaWritingProgress(
      scope: katakana,
      session: KanaWritingSession(
        letters: KanaPracticeRow.firstRow.letters(hiragana: false),
        index: 2,
        step: KanaWritingStep.recall,
        mode: KanaWritingMode.row,
        showExample: true,
        strokes: const [
          [Offset(.1, .2), Offset(.7, .4)],
          [Offset(.2, .3), Offset(.3, .9)],
        ],
      ),
    );
    final restored = KanaWritingProgress.decode(original.encode(), katakana);
    expect(restored.session!.letter, KatakanaPilotLetter.u);
    expect(restored.session!.row, KanaPracticeRow.firstRow);
    expect(restored.session!.index, 2);
    expect(restored.session!.step, KanaWritingStep.recall);
    expect(restored.session!.showExample, isTrue);
    expect(restored.session!.strokes, original.session!.strokes);
  });

  test('all basic rows recommend in order and total 46 for each script', () {
    for (final scope in [hiragana, katakana]) {
      final done = <KanaPracticeRow>{};
      for (final row in KanaWritingProgress.basicRows) {
        final progress =
            KanaWritingProgress(scope: scope, completedBasicRows: done);
        expect(progress.recommendedRow, row);
        expect(
            progress.completedBasicCount,
            done.fold<int>(
                0, (n, r) => n + r.letters(hiragana: scope.hiragana).length));
        done.add(row);
      }
      final completed =
          KanaWritingProgress(scope: scope, completedBasicRows: done);
      expect(completed.recommendedRow, isNull);
      expect(completed.completedBasicCount, 46);
      expect(
          KanaWritingProgress.decode(completed.encode(), scope)
              .completedBasicCount,
          46);
    }
  });

  test('comparison session never identifies a basic row for completion', () {
    final session = KanaWritingSession(
        letters: KanaPracticeRow.firstRow.letters(hiragana: false),
        index: 0,
        step: KanaWritingStep.compare,
        mode: KanaWritingMode.comparison);
    expect(session.row, isNull);
  });

  test('immutable snapshots do not track mutable UI lists', () {
    final letters = <KanaPracticeLetter>[KatakanaPilotLetter.u];
    final strokes = [
      [const Offset(.1, .2), const Offset(.3, .4)]
    ];
    final session = KanaWritingSession(
        letters: letters,
        index: 0,
        step: KanaWritingStep.recall,
        mode: KanaWritingMode.comparison,
        strokes: strokes);
    letters.clear();
    strokes.single.clear();
    expect(session.letters.single, KatakanaPilotLetter.u);
    expect(session.strokes.single, hasLength(2));
  });

  final invalid = <String, void Function(Map<String, Object?>)>{
    'future version': (json) => json['version'] = 2,
    'another owner': (json) => json['owner'] = 'account-b',
    'another script': (json) => json['script'] = 'hiragana',
    'unknown row': (json) => json['completedBasicRows'] = ['missingRow'],
    'advanced row as basic': (json) => json['completedBasicRows'] = ['gaRow'],
    'duplicate completion': (json) =>
        json['completedBasicRows'] = ['firstRow', 'firstRow'],
    'unknown glyph ID': (json) => _sessionJson(json)['letters'] = ['unknown'],
    'duplicate glyph ID': (json) => _sessionJson(json)['letters'] = ['u', 'u'],
    'unknown step': (json) => _sessionJson(json)['step'] = 'futureStep',
    'negative index': (json) => _sessionJson(json)['index'] = -1,
    'out of range index': (json) => _sessionJson(json)['index'] = 6,
    'noninteger index': (json) => _sessionJson(json)['index'] = .5,
    'partial row': (json) {
      _sessionJson(json)['mode'] = 'row';
      _sessionJson(json)['letters'] = ['u'];
    },
    'reveal without ink': (json) {
      _sessionJson(json)['step'] = 'recall';
      _sessionJson(json)['showExample'] = true;
    },
    'word selection outside word': (json) {
      _sessionJson(json)['step'] = 'word';
      _sessionJson(json)['selectedIndex'] = 999;
    },
    'ink outside canvas': (json) {
      _sessionJson(json)['step'] = 'recall';
      _sessionJson(json)['strokes'] = [
        [
          [.1, .2],
          [1.1, .4]
        ]
      ];
    },
    'too many strokes': (json) {
      _sessionJson(json)['step'] = 'recall';
      _sessionJson(json)['strokes'] = List.generate(
          33,
          (_) => [
                [.1, .2],
                [.3, .4]
              ]);
    },
  };
  for (final entry in invalid.entries) {
    test('rejects ${entry.key} while preserving caller raw bytes', () {
      final initial = KanaWritingProgress(
          scope: katakana,
          session: KanaWritingSession(
              letters: [KatakanaPilotLetter.u],
              index: 0,
              step: KanaWritingStep.compare,
              mode: KanaWritingMode.comparison));
      final json = jsonDecode(initial.encode()) as Map<String, Object?>;
      entry.value(json);
      final raw = jsonEncode(json);
      expect(() => KanaWritingProgress.decode(raw, katakana),
          throwsFormatException);
    });
  }

  test('nonfinite UI drawing coordinates cannot be persisted', () {
    final progress = KanaWritingProgress(
        scope: katakana,
        session: KanaWritingSession(
            letters: [KatakanaPilotLetter.u],
            index: 0,
            step: KanaWritingStep.recall,
            mode: KanaWritingMode.comparison,
            strokes: const [
              [Offset(.1, .2), Offset(double.nan, .3)]
            ]));
    expect(progress.encode, throwsFormatException);
  });
}

Map<String, Object?> _sessionJson(Map<String, Object?> json) =>
    json['session']! as Map<String, Object?>;
