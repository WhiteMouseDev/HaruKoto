import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/kana/domain/katakana_pilot.dart';

void main() {
  test('practice groups cover nine distinct exercises', () {
    const groups = KatakanaPracticeGroup.values;
    expect(groups.map((group) => group.label), ['シ・ツ・ソ・ン', 'ク・タ', 'フ・ワ・ウ']);
    final letters = groups.expand((group) => group.letters).toList();
    expect(letters, unorderedEquals(KatakanaPilotLetter.values));
    expect(letters.map((letter) => letter.word).toSet(), hasLength(9));
    for (final group in groups) {
      for (final letter in group.letters) {
        expect(
          letter.word.runes.where((rune) => rune == letter.glyph.runes.single),
          hasLength(1),
        );
        final comparison = letter.comparisonLetters;
        expect(comparison.first, letter);
        expect(comparison, hasLength(comparison.toSet().length));
        expect(comparison.every(group.letters.contains), isTrue);
        expect(
          comparison,
          hasLength(group == KatakanaPracticeGroup.original
              ? 2
              : group.letters.length),
        );
      }
    }
    expect(KatakanaPilotLetter.shi.comparisonLetters.last,
        KatakanaPilotLetter.tsu);
    expect(KatakanaPilotLetter.tsu.comparisonLetters.last,
        KatakanaPilotLetter.shi);
    expect(
        KatakanaPilotLetter.so.comparisonLetters.last, KatakanaPilotLetter.n);
    expect(
        KatakanaPilotLetter.n.comparisonLetters.last, KatakanaPilotLetter.so);
  });

  test('schematic coordinates preserve stroke count, ordering and directions',
      () {
    const letters = KatakanaPilotLetter.values;
    expect(letters.map((letter) => letter.strokes.length),
        [3, 3, 2, 2, 2, 3, 1, 2, 3]);
    for (final letter in letters) {
      final positions = letter.strokeNumberPositions;
      if (positions != null) {
        expect(positions, hasLength(letter.strokes.length));
      }
      for (final stroke in letter.strokes) {
        expect(stroke, hasLength(greaterThanOrEqualTo(2)));
      }
      final points = letter.strokes.expand((stroke) => stroke);
      for (final point in points.followedBy(positions ?? const [])) {
        expect(point.dx, inInclusiveRange(0.0, 1.0));
        expect(point.dy, inInclusiveRange(0.0, 1.0));
      }
    }
    for (final letter in KatakanaPracticeGroup.original.letters) {
      final long = letter.strokes.last;
      final rises =
          letter == KatakanaPilotLetter.shi || letter == KatakanaPilotLetter.n;
      if (rises) {
        expect(long.first.dx, lessThan(long.last.dx));
        expect(long.first.dy, greaterThan(long.last.dy));
      } else {
        expect(long.first.dx, greaterThan(long.last.dx));
        expect(long.first.dy, lessThan(long.last.dy));
      }
    }
    final shi = KatakanaPilotLetter.shi.strokes;
    final tsu = KatakanaPilotLetter.tsu.strokes;
    expect(shi[0].first.dy, lessThan(shi[1].first.dy));
    expect(tsu[0].first.dx, lessThan(tsu[1].first.dx));
  });

  test('new guides distinguish the inner stroke and short vertical strokes',
      () {
    final ta = KatakanaPilotLetter.ta.strokes;
    expect(ta[2].first.dx, lessThan(ta[2].last.dx));
    expect(ta[2].first.dy, lessThan(ta[2].last.dy));
    expect(ta[2].last.dy, lessThan(ta[1].last.dy));

    final wa = KatakanaPilotLetter.wa.strokes;
    final u = KatakanaPilotLetter.u.strokes;
    expect(wa.first.first.dx, closeTo(wa.last.first.dx, .03));
    expect(u.first.first.dx, greaterThan(u[1].first.dx));
    expect(u.first.first.dy, lessThan(u[1].first.dy));

    for (final letter in KatakanaPracticeGroup.fuWaU.letters) {
      final long = letter.strokes.last;
      expect(long.first.dx, lessThan(long[2].dx));
      expect(long.last.dx, lessThan(long[2].dx));
      expect(long.last.dy, greaterThan(long[2].dy));
    }
  });
}
