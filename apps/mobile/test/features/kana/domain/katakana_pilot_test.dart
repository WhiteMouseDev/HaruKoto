import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/kana/domain/katakana_pilot.dart';

void main() {
  test('focused practice groups preserve the nine comparison exercises', () {
    const groups = [
      KatakanaPracticeGroup.original,
      KatakanaPracticeGroup.kuTa,
      KatakanaPracticeGroup.fuWaU,
    ];
    expect(groups.map((group) => group.label), ['シ・ツ・ソ・ン', 'ク・タ', 'フ・ワ・ウ']);
    final letters = groups.expand((group) => group.letters).toList();
    expect(letters.toSet(), hasLength(9));
    for (final group in groups) {
      for (final letter in group.letters) {
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

  test('the first row is in kana order and shares ウ with focused practice', () {
    const row = KatakanaPracticeGroup.firstRow;
    expect(row.label, 'ア・イ・ウ・エ・オ');
    expect(row.letters[2], same(KatakanaPracticeGroup.fuWaU.letters.last));
    final letters =
        KatakanaPracticeGroup.values.expand((group) => group.letters);
    expect(letters, hasLength(14));
    expect(letters.toSet(), unorderedEquals(KatakanaPilotLetter.values));
  });

  test('practice and next-day words are distinct and have one target', () {
    const letters = KatakanaPilotLetter.values;
    final practiceWords = letters.map((letter) => letter.word).toSet();
    expect(practiceWords, hasLength(letters.length));
    expect(
      letters.map((letter) => letter.reviewWord.text).toSet(),
      hasLength(letters.length),
    );
    for (final letter in letters) {
      final reviewWord = letter.reviewWord;
      expect(practiceWords, isNot(contains(reviewWord.text)));
      for (final word in [letter.word, reviewWord.text]) {
        expect(
          word.runes.where((rune) => rune == letter.glyph.runes.single),
          hasLength(1),
          reason: '$word must contain one ${letter.glyph}',
        );
      }
      expect(reviewWord.reading, isNotEmpty);
      expect(reviewWord.meaning, isNotEmpty);
    }
  });

  test('schematic coordinates preserve stroke count, ordering and directions',
      () {
    const letters = KatakanaPilotLetter.values;
    expect(letters.map((letter) => letter.strokes.length),
        [3, 3, 2, 2, 2, 3, 1, 2, 3, 2, 2, 3, 3]);
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

  test('first-row stroke guides preserve the checked order and directions', () {
    final a = KatakanaPilotLetter.a.strokes;
    expect(a[0].first.dx, lessThan(a[0][2].dx));
    expect(a[0].last.dx, lessThan(a[0][2].dx));
    expect(a[1].last.dy, greaterThan(a[0].last.dy));

    final i = KatakanaPilotLetter.i.strokes;
    expect(i[0].last.dx, lessThan(i[0].first.dx));
    expect(i[0].last.dy, greaterThan(i[0].first.dy));
    expect(i[1].last.dx, closeTo(i[1].first.dx, .04));
    expect(i[1].last.dy, greaterThan(i[1].first.dy));

    final e = KatakanaPilotLetter.e.strokes;
    expect(e[0].last.dx, greaterThan(e[0].first.dx));
    expect(e[1].last.dx, e[1].first.dx);
    expect(e[1].last.dy, greaterThan(e[1].first.dy));
    expect(e[2].last.dx - e[2].first.dx,
        greaterThan(e[0].last.dx - e[0].first.dx));
    expect(e[2].first.dy, greaterThan(e[0].first.dy));

    final o = KatakanaPilotLetter.o.strokes;
    expect(o[0].last.dx, greaterThan(o[0].first.dx));
    final hook = o[1][o[1].length - 2];
    expect(hook.dx, o[1].first.dx);
    expect(hook.dy, greaterThan(o[1].first.dy));
    expect(o[1].last.dx, lessThan(hook.dx));
    expect(o[1].last.dy, lessThan(hook.dy));
    expect(o[2].first.dx, o[1].first.dx);
    expect(o[2].last.dx, lessThan(o[2].first.dx));
    expect(o[2].last.dy, greaterThan(o[2].first.dy));
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
