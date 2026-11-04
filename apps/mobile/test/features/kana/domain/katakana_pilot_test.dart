import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/kana/domain/katakana_pilot.dart';

void main() {
  test('each word exercise has one answer and a reciprocal contrast letter',
      () {
    const letters = KatakanaPilotLetter.values;
    expect(letters.map((letter) => letter.glyph), ['シ', 'ツ', 'ソ', 'ン']);
    expect(letters.map((letter) => letter.word).toSet(), hasLength(4));
    for (final letter in letters) {
      expect(letter.contrast, isNot(letter));
      expect(letter.contrast.contrast, letter);
      expect(
        letter.word.runes.where((rune) => rune == letter.glyph.runes.single),
        hasLength(1),
      );
    }
  });

  test('schematic coordinates preserve stroke count, ordering and directions',
      () {
    const letters = KatakanaPilotLetter.values;
    expect(letters.map((letter) => letter.strokes.length), [3, 3, 2, 2]);
    for (final letter in letters) {
      for (final stroke in letter.strokes) {
        expect(stroke, hasLength(greaterThanOrEqualTo(2)));
        for (final point in stroke) {
          expect(point.dx, inInclusiveRange(0.0, 1.0));
          expect(point.dy, inInclusiveRange(0.0, 1.0));
        }
      }
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
}
