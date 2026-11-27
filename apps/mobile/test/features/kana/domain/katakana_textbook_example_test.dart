import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/kana/domain/katakana_textbook_example.dart';

void main() {
  test('each practice glyph has the expected number of logical strokes', () {
    for (final MapEntry(:key, :value) in _allStrokeCounts.entries) {
      expect(kanaTextbookExample(key)?.strokes, hasLength(value), reason: key);
    }
    const hiraganaParts = {
      'あ': [1, 1, 2],
      'い': [1, 1],
      'う': [1, 1],
      'え': [1, 1],
      'お': [1, 2, 1],
    };
    for (final MapEntry(:key, :value) in hiraganaParts.entries) {
      final example = kanaTextbookExample(key)!;
      expect(example.strokes.map((stroke) => stroke.parts.length), value,
          reason: key);
    }
    expect(kanaTextbookExample('ー'), isNull);
  });

  test('small examples stay visibly smaller than their paired kana', () {
    const pairs = {
      'ぁ': 'あ',
      'ぃ': 'い',
      'ぅ': 'う',
      'ぇ': 'え',
      'ぉ': 'お',
      'っ': 'つ',
      'ゃ': 'や',
      'ゅ': 'ゆ',
      'ょ': 'よ',
      'ゎ': 'わ',
      'ァ': 'ア',
      'ィ': 'イ',
      'ゥ': 'ウ',
      'ェ': 'エ',
      'ォ': 'オ',
      'ッ': 'ツ',
      'ャ': 'ヤ',
      'ュ': 'ユ',
      'ョ': 'ヨ',
      'ヮ': 'ワ',
      'ヵ': 'カ',
      'ヶ': 'ケ',
    };
    for (final MapEntry(:key, :value) in pairs.entries) {
      final small = kanaTextbookExample(key)!.silhouette.getBounds();
      final full = kanaTextbookExample(value)!.silhouette.getBounds();
      expect(small.width, lessThan(full.width * .9), reason: key);
      expect(small.height, lessThan(full.height * .9), reason: key);
    }
  });

  test('handakuten remains a ring in the stroke and combined outline', () {
    for (final glyph in 'ぱぴぷぺぽパピプペポ'.split('')) {
      final example = kanaTextbookExample(glyph)!;
      final ring = example.strokes.last.outline;
      final center = ring.getBounds().center;
      expect(ring.computeMetrics(), hasLength(2), reason: glyph);
      expect(ring.contains(center), isFalse, reason: glyph);
      expect(example.silhouette.contains(center), isFalse, reason: glyph);
    }
  });

  test('ゔ appends the authored dakuten after the base hiragana strokes', () {
    final voiced = kanaTextbookExample('ゔ')!;
    final u = kanaTextbookExample('う')!;
    final vu = kanaTextbookExample('ヴ')!;
    expect(voiced.strokes.take(2), orderedEquals(u.strokes));
    expect(voiced.strokes.skip(2), orderedEquals(vu.strokes.skip(3)));
  });

  test('kana stroke markers align with their replay contours', () {
    for (final glyph in _allStrokeCounts.keys) {
      final example = kanaTextbookExample(glyph)!;
      for (final (index, stroke) in example.strokes.indexed) {
        final name = '$glyph stroke ${index + 1}';
        for (final part in stroke.parts) {
          expect(part.outline.computeMetrics().every((path) => path.isClosed),
              isTrue,
              reason: name);
        }
        expect(stroke.parts.first.outline.contains(stroke.start), isTrue,
            reason: name);
        expect(example.silhouette.contains(stroke.numberPosition), isFalse,
            reason: name);

        // The dot belongs near the beginning of the source replay, which can
        // start outside the shape before entering the visible contour.
        final replay = stroke.parts.first.replay;
        final isVariant = _variantStrokeCounts.containsKey(glyph);
        final earlyDistance = replay.length * (isVariant ? .62 : 1 / 3);
        final maxOffset = isVariant ? 34.0 : 20.0;
        final earlyReplay = [
          for (var distance = 0.0; distance < earlyDistance; distance += 2)
            replay.getTangentForOffset(distance)!.position,
        ];
        expect(
          earlyReplay
              .any((point) => (point - stroke.start).distance < maxOffset),
          isTrue,
          reason: name,
        );
        expect(
          (const Offset(0, 0) & const Size.square(1)).contains(
            KatakanaTextbookExample.unitPosition(stroke.numberPosition),
          ),
          isTrue,
          reason: name,
        );
      }
    }
  });
}

// Logical stroke counts from the pinned StrokeSVG data, in gojuon order.
const _sourceStrokeCounts = {
  'あ': 3,
  'い': 2,
  'う': 2,
  'え': 2,
  'お': 3,
  'か': 3,
  'き': 4,
  'く': 1,
  'け': 3,
  'こ': 2,
  'さ': 3,
  'し': 1,
  'す': 2,
  'せ': 3,
  'そ': 1,
  'た': 4,
  'ち': 2,
  'つ': 1,
  'て': 1,
  'と': 2,
  'な': 4,
  'に': 3,
  'ぬ': 2,
  'ね': 2,
  'の': 1,
  'は': 3,
  'ひ': 1,
  'ふ': 4,
  'へ': 1,
  'ほ': 4,
  'ま': 3,
  'み': 2,
  'む': 3,
  'め': 2,
  'も': 3,
  'や': 3,
  'ゆ': 2,
  'よ': 2,
  'ら': 2,
  'り': 2,
  'る': 1,
  'れ': 2,
  'ろ': 1,
  'わ': 2,
  'を': 3,
  'ん': 1,
  'ア': 2,
  'イ': 2,
  'ウ': 3,
  'エ': 3,
  'オ': 3,
  'カ': 2,
  'キ': 3,
  'ク': 2,
  'ケ': 3,
  'コ': 2,
  'サ': 3,
  'シ': 3,
  'ス': 2,
  'セ': 2,
  'ソ': 2,
  'タ': 3,
  'チ': 3,
  'ツ': 3,
  'テ': 3,
  'ト': 2,
  'ナ': 2,
  'ニ': 2,
  'ヌ': 2,
  'ネ': 4,
  'ノ': 1,
  'ハ': 2,
  'ヒ': 2,
  'フ': 1,
  'ヘ': 1,
  'ホ': 4,
  'マ': 2,
  'ミ': 3,
  'ム': 2,
  'メ': 2,
  'モ': 3,
  'ヤ': 2,
  'ユ': 2,
  'ヨ': 3,
  'ラ': 2,
  'リ': 2,
  'ル': 2,
  'レ': 1,
  'ロ': 3,
  'ワ': 2,
  'ヲ': 3,
  'ン': 2,
};

const _variantStrokeCounts = {
  'が': 5,
  'ぎ': 6,
  'ぐ': 3,
  'げ': 5,
  'ご': 4,
  'ざ': 5,
  'じ': 3,
  'ず': 4,
  'ぜ': 5,
  'ぞ': 3,
  'だ': 6,
  'ぢ': 4,
  'づ': 3,
  'で': 3,
  'ど': 4,
  'ば': 5,
  'び': 3,
  'ぶ': 6,
  'べ': 3,
  'ぼ': 6,
  'ぱ': 4,
  'ぴ': 2,
  'ぷ': 5,
  'ぺ': 2,
  'ぽ': 5,
  'ゔ': 4,
  'ぁ': 3,
  'ぃ': 2,
  'ぅ': 2,
  'ぇ': 2,
  'ぉ': 3,
  'っ': 1,
  'ゃ': 3,
  'ゅ': 2,
  'ょ': 2,
  'ゎ': 2,
  'ガ': 4,
  'ギ': 5,
  'グ': 4,
  'ゲ': 5,
  'ゴ': 4,
  'ザ': 5,
  'ジ': 5,
  'ズ': 4,
  'ゼ': 4,
  'ゾ': 4,
  'ダ': 5,
  'ヂ': 5,
  'ヅ': 5,
  'デ': 5,
  'ド': 4,
  'バ': 4,
  'ビ': 4,
  'ブ': 3,
  'ベ': 3,
  'ボ': 6,
  'パ': 3,
  'ピ': 3,
  'プ': 2,
  'ペ': 2,
  'ポ': 5,
  'ヴ': 5,
  'ァ': 2,
  'ィ': 2,
  'ゥ': 3,
  'ェ': 3,
  'ォ': 3,
  'ッ': 3,
  'ャ': 2,
  'ュ': 2,
  'ョ': 3,
  'ヮ': 2,
  'ヵ': 2,
  'ヶ': 3,
};

const _allStrokeCounts = {..._sourceStrokeCounts, ..._variantStrokeCounts};
