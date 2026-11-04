import 'dart:ui';

/// Coordinates are original practice diagrams in a unit square, in stroke order.
/// The stroke counts and directions were checked against the Japan Foundation
/// katakana worksheets and MLC's シ・ツ・ソ・ン lesson. No source artwork is bundled.
enum KatakanaPilotLetter {
  shi(
    glyph: 'シ',
    reading: 'し',
    cue: '짧은 두 획은 왼쪽에 위아래로, 긴 획은 왼쪽 아래에서 오른쪽 위로.',
    strokes: [
      [Offset(.24, .24), Offset(.34, .28), Offset(.43, .34)],
      [Offset(.18, .43), Offset(.29, .46), Offset(.38, .52)],
      [
        Offset(.22, .78),
        Offset(.38, .74),
        Offset(.52, .68),
        Offset(.64, .59),
        Offset(.75, .47),
        Offset(.82, .35),
      ],
    ],
    word: 'ミシン',
    wordReading: 'みしん',
    meaning: '재봉틀',
  ),
  tsu(
    glyph: 'ツ',
    reading: 'つ',
    cue: '짧은 두 획은 위쪽에 나란히, 긴 획은 오른쪽 위에서 왼쪽 아래로.',
    strokes: [
      [Offset(.20, .29), Offset(.26, .37), Offset(.30, .46)],
      [Offset(.42, .22), Offset(.47, .31), Offset(.50, .40)],
      [
        Offset(.79, .23),
        Offset(.76, .38),
        Offset(.70, .52),
        Offset(.61, .65),
        Offset(.49, .74),
        Offset(.33, .81),
      ],
    ],
    word: 'シャツ',
    wordReading: 'しゃつ',
    meaning: '셔츠',
  ),
  so(
    glyph: 'ソ',
    reading: 'そ',
    cue: '짧은 획 하나는 위쪽에서 아래로, 긴 획은 오른쪽 위에서 왼쪽 아래로.',
    strokes: [
      [Offset(.24, .25), Offset(.31, .35), Offset(.37, .47)],
      [
        Offset(.78, .20),
        Offset(.75, .36),
        Offset(.69, .51),
        Offset(.60, .63),
        Offset(.49, .73),
        Offset(.34, .81),
      ],
    ],
    word: 'ソファ',
    wordReading: 'そふぁ',
    meaning: '소파',
  ),
  n(
    glyph: 'ン',
    reading: 'ん',
    cue: '짧은 획 하나는 왼쪽에서 오른쪽으로, 긴 획은 왼쪽 아래에서 오른쪽 위로.',
    strokes: [
      [Offset(.23, .32), Offset(.33, .37), Offset(.42, .43)],
      [
        Offset(.23, .78),
        Offset(.39, .73),
        Offset(.53, .67),
        Offset(.65, .58),
        Offset(.75, .47),
        Offset(.82, .34),
      ],
    ],
    word: 'コンビニ',
    wordReading: 'こんびに',
    meaning: '편의점',
  );

  const KatakanaPilotLetter({
    required this.glyph,
    required this.reading,
    required this.cue,
    required this.strokes,
    required this.word,
    required this.wordReading,
    required this.meaning,
  });

  final String glyph;
  final String reading;
  final String cue;
  final List<List<Offset>> strokes;
  final String word;
  final String wordReading;
  final String meaning;

  KatakanaPilotLetter get contrast => switch (this) {
        shi => tsu,
        tsu => shi,
        so => n,
        n => so,
      };
}
