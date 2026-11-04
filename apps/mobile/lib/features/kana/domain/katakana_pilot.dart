import 'dart:ui';

class KatakanaPracticeWord {
  const KatakanaPracticeWord(this.text, this.reading, this.meaning);

  final String text;
  final String reading;
  final String meaning;
}

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
    reviewWord: KatakanaPracticeWord('シール', 'しーる', '스티커'),
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
    reviewWord: KatakanaPracticeWord('ツアー', 'つあー', '투어'),
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
    reviewWord: KatakanaPracticeWord('ソース', 'そーす', '소스'),
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
    reviewWord: KatakanaPracticeWord('ペン', 'ぺん', '펜'),
  ),
  ku(
    glyph: 'ク',
    reading: 'く',
    cue: '왼쪽에 짧은 사선을 쓰고, 윗선에서 꺾어 왼쪽 아래로 내려와요.',
    strokes: [
      [Offset(.49, .21), Offset(.43, .31), Offset(.34, .41), Offset(.24, .50)],
      [
        Offset(.43, .32),
        Offset(.76, .30),
        Offset(.73, .42),
        Offset(.66, .55),
        Offset(.54, .68),
        Offset(.40, .79),
        Offset(.27, .85),
      ],
    ],
    word: 'クラス',
    wordReading: 'くらす',
    meaning: '학급',
    reviewWord: KatakanaPracticeWord('ミルク', 'みるく', '우유'),
  ),
  ta(
    glyph: 'タ',
    reading: 'た',
    cue: 'ク와 같은 두 획을 쓴 뒤, 가운데에 오른쪽 아래로 짧은 획을 더해요.',
    strokes: [
      [Offset(.49, .21), Offset(.42, .32), Offset(.32, .42), Offset(.23, .49)],
      [
        Offset(.42, .32),
        Offset(.77, .30),
        Offset(.74, .42),
        Offset(.66, .55),
        Offset(.55, .67),
        Offset(.41, .78),
        Offset(.28, .85),
      ],
      [Offset(.37, .47), Offset(.46, .52), Offset(.56, .60)],
    ],
    word: 'タクシー',
    wordReading: 'たくしー',
    meaning: '택시',
    reviewWord: KatakanaPracticeWord('ギター', 'ぎたー', '기타'),
  ),
  fu(
    glyph: 'フ',
    reading: 'ふ',
    cue: '윗선을 왼쪽에서 오른쪽으로 긋고, 꺾어서 왼쪽 아래로 한 번에 내려와요.',
    strokes: [
      [
        Offset(.22, .29),
        Offset(.49, .27),
        Offset(.77, .25),
        Offset(.75, .38),
        Offset(.69, .52),
        Offset(.59, .65),
        Offset(.47, .75),
        Offset(.33, .82),
      ],
    ],
    word: 'フランス',
    wordReading: 'ふらんす',
    meaning: '프랑스',
    reviewWord: KatakanaPracticeWord('ナイフ', 'ないふ', '나이프'),
  ),
  wa(
    glyph: 'ワ',
    reading: 'わ',
    cue: '왼쪽에 짧은 세로획을 먼저 쓰고, フ처럼 윗선에서 꺾어 내려와요.',
    strokeNumberPositions: [Offset(.11, .27), Offset(.33, .20)],
    strokes: [
      [Offset(.23, .28), Offset(.24, .38), Offset(.26, .51)],
      [
        Offset(.24, .31),
        Offset(.51, .29),
        Offset(.78, .27),
        Offset(.75, .42),
        Offset(.69, .55),
        Offset(.60, .67),
        Offset(.47, .77),
        Offset(.36, .84),
      ],
    ],
    word: 'ワイン',
    wordReading: 'わいん',
    meaning: '와인',
    reviewWord: KatakanaPracticeWord('シャワー', 'しゃわー', '샤워'),
  ),
  u(
    glyph: 'ウ',
    reading: 'う',
    cue: '가운데 위, 왼쪽 순서로 짧은 획을 쓰고 마지막에 윗선에서 꺾어 내려와요.',
    strokeNumberPositions: [
      Offset(.49, .10),
      Offset(.11, .35),
      Offset(.34, .23)
    ],
    strokes: [
      [Offset(.49, .17), Offset(.49, .24), Offset(.49, .34)],
      [Offset(.23, .33), Offset(.24, .42), Offset(.26, .55)],
      [
        Offset(.24, .36),
        Offset(.51, .34),
        Offset(.77, .32),
        Offset(.74, .46),
        Offset(.67, .60),
        Offset(.58, .71),
        Offset(.46, .80),
        Offset(.36, .86),
      ],
    ],
    word: 'ウサギ',
    wordReading: 'うさぎ',
    meaning: '토끼',
    reviewWord: KatakanaPracticeWord('ウール', 'うーる', '울(양모)'),
  );

  const KatakanaPilotLetter({
    required this.glyph,
    required this.reading,
    required this.cue,
    required this.strokes,
    this.strokeNumberPositions,
    required this.word,
    required this.wordReading,
    required this.meaning,
    required this.reviewWord,
  });

  final String glyph;
  final String reading;
  final String cue;
  final List<List<Offset>> strokes;
  final List<Offset>? strokeNumberPositions;
  final String word;
  final String wordReading;
  final String meaning;
  final KatakanaPracticeWord reviewWord;

  List<KatakanaPilotLetter> get comparisonLetters => switch (this) {
        shi => const [shi, tsu],
        tsu => const [tsu, shi],
        so => const [so, n],
        n => const [n, so],
        ku => const [ku, ta],
        ta => const [ta, ku],
        fu => const [fu, wa, u],
        wa => const [wa, fu, u],
        u => const [u, fu, wa],
      };
}

enum KatakanaPracticeGroup {
  original([
    KatakanaPilotLetter.shi,
    KatakanaPilotLetter.tsu,
    KatakanaPilotLetter.so,
    KatakanaPilotLetter.n,
  ]),
  kuTa([KatakanaPilotLetter.ku, KatakanaPilotLetter.ta]),
  fuWaU(
      [KatakanaPilotLetter.fu, KatakanaPilotLetter.wa, KatakanaPilotLetter.u]);

  const KatakanaPracticeGroup(this.letters);

  final List<KatakanaPilotLetter> letters;

  String get label => letters.map((letter) => letter.glyph).join('・');
}
