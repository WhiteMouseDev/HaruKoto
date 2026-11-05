import 'dart:ui';

class KatakanaPracticeWord {
  const KatakanaPracticeWord(this.text, this.reading, this.meaning);

  final String text;
  final String reading;
  final String meaning;
}

enum KanaPracticeExampleKind {
  word('단어'),
  sentence('문장'),
  transcribedWord('단어', contextLabel: '가타카나로 옮겨 적은 단어'),
  transcribedSentence('문장', contextLabel: '가타카나로 옮겨 적은 문장'),
  combination('글자 조합'),
  counter('표기', contextLabel: '수를 세는 표기');

  const KanaPracticeExampleKind(this.label, {String? contextLabel})
      : contextLabel = contextLabel ?? label;

  final String label;
  final String contextLabel;
}

abstract interface class KanaPracticeLetter {
  String get glyph;
  String get reading;
  String get cue;
  String get word;
  String get wordReading;
  String get meaning;
  KatakanaPracticeWord get reviewWord;
  String get reviewId;
  KanaPracticeExampleKind get exampleKind;
}

/// Fallback coordinates in a unit square, in stroke order.
/// Stroke counts and directions were checked against the Japan Foundation
/// katakana worksheets and MLC's シ・ツ・ソ・ン lesson.
enum KatakanaPilotLetter implements KanaPracticeLetter {
  shi(
    glyph: 'シ',
    reading: 'し',
    cue: '짧은 두 획은 왼쪽에 위아래로, 긴 획은 왼쪽 아래에서 오른쪽 위로.',
    strokeNumberPositions: [
      Offset(.14, .24),
      Offset(.08, .43),
      Offset(.12, .78)
    ],
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
    strokeNumberPositions: [
      Offset(.19, .18),
      Offset(.41, .11),
      Offset(.80, .12)
    ],
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
    strokeNumberPositions: [Offset(.17, .17), Offset(.79, .10)],
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
    strokeNumberPositions: [Offset(.13, .32), Offset(.13, .78)],
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
    strokeNumberPositions: [Offset(.56, .13), Offset(.31, .24)],
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
    strokeNumberPositions: [
      Offset(.56, .13),
      Offset(.31, .24),
      Offset(.30, .55)
    ],
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
    strokeNumberPositions: [Offset(.12, .29)],
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
      Offset(.49, .08),
      Offset(.13, .32),
      Offset(.35, .25),
    ],
    strokes: [
      [Offset(.49, .18), Offset(.49, .32)],
      [Offset(.23, .32), Offset(.25, .52)],
      [
        Offset(.232, .34),
        Offset(.49, .326),
        Offset(.77, .31),
        Offset(.74, .45),
        Offset(.67, .58),
        Offset(.58, .69),
        Offset(.46, .77),
        Offset(.36, .82),
      ],
    ],
    word: 'ウサギ',
    wordReading: 'うさぎ',
    meaning: '토끼',
    reviewWord: KatakanaPracticeWord('ウール', 'うーる', '울(양모)'),
  ),
  a(
    glyph: 'ア',
    reading: 'あ',
    cue: '윗선을 오른쪽으로 긋고 왼쪽 아래로 꺾어요. 그 안쪽에서 시작해 왼쪽 아래로 내려와요.',
    strokeNumberPositions: [Offset(.13, .26), Offset(.41, .39)],
    strokes: [
      [
        Offset(.23, .26),
        Offset(.50, .245),
        Offset(.77, .23),
        Offset(.73, .33),
        Offset(.67, .41),
        Offset(.59, .47),
      ],
      [
        Offset(.51, .39),
        Offset(.51, .51),
        Offset(.49, .62),
        Offset(.44, .71),
        Offset(.36, .79),
      ],
    ],
    word: 'アイス',
    wordReading: 'あいす',
    meaning: '아이스크림',
    reviewWord: KatakanaPracticeWord('ピアノ', 'ぴあの', '피아노'),
  ),
  i(
    glyph: 'イ',
    reading: 'い',
    cue: '오른쪽 위에서 왼쪽 아래로 비스듬히 긋고, 그 중간에서 세로로 내려와요.',
    strokeNumberPositions: [Offset(.82, .16), Offset(.67, .42)],
    strokes: [
      [
        Offset(.74, .22),
        Offset(.66, .32),
        Offset(.57, .416),
        Offset(.45, .50),
        Offset(.34, .56),
        Offset(.25, .60),
      ],
      [Offset(.57, .416), Offset(.57, .81)],
    ],
    word: 'イチゴ',
    wordReading: 'いちご',
    meaning: '딸기',
    reviewWord: KatakanaPracticeWord('サイン', 'さいん', '서명'),
  ),
  e(
    glyph: 'エ',
    reading: 'え',
    cue: '위에 짧은 가로획을 긋고 가운데를 세로로 내려요. 아래에 더 긴 가로획을 그어요.',
    strokeNumberPositions: [
      Offset(.22, .32),
      Offset(.62, .39),
      Offset(.13, .70),
    ],
    strokes: [
      [Offset(.32, .32), Offset(.70, .30)],
      [Offset(.51, .31), Offset(.51, .69)],
      [Offset(.23, .705), Offset(.79, .675)],
    ],
    word: 'エアコン',
    wordReading: 'えあこん',
    meaning: '에어컨',
    reviewWord: KatakanaPracticeWord('バレエ', 'ばれえ', '발레'),
  ),
  o(
    glyph: 'オ',
    reading: 'お',
    cue: '가로획을 긋고 세로로 내려 끝을 왼쪽으로 올려요. 마지막 획은 교차점에서 왼쪽 아래로 내려요.',
    strokeNumberPositions: [
      Offset(.12, .39),
      Offset(.60, .10),
      Offset(.45, .43),
    ],
    strokes: [
      [Offset(.22, .39), Offset(.78, .36)],
      [Offset(.60, .20), Offset(.60, .80), Offset(.48, .75)],
      [
        Offset(.60, .37),
        Offset(.52, .47),
        Offset(.44, .55),
        Offset(.34, .63),
        Offset(.24, .69),
      ],
    ],
    word: 'カラオケ',
    wordReading: 'からおけ',
    meaning: '노래방',
    reviewWord: KatakanaPracticeWord('ラジオ', 'らじお', '라디오'),
  ),
  ka.basic(
      'カ', 'か', 'カメラ', 'かめら', '카메라', KatakanaPracticeWord('カード', 'かーど', '카드')),
  ki.basic('キ', 'き', 'キッチン', 'きっちん', '주방',
      KatakanaPracticeWord('ケーキ', 'けーき', '케이크')),
  ke.basic('ケ', 'け', 'ケチャップ', 'けちゃっぷ', '케첩',
      KatakanaPracticeWord('ケース', 'けーす', '케이스')),
  ko.basic(
      'コ', 'こ', 'コーヒー', 'こーひー', '커피', KatakanaPracticeWord('コップ', 'こっぷ', '컵')),
  sa.basic('サ', 'さ', 'サラダ', 'さらだ', '샐러드',
      KatakanaPracticeWord('サンドイッチ', 'さんどいっち', '샌드위치')),
  su.basic(
      'ス', 'す', 'スープ', 'すーぷ', '수프', KatakanaPracticeWord('バス', 'ばす', '버스')),
  se.basic('セ', 'せ', 'セーター', 'せーたー', '스웨터',
      KatakanaPracticeWord('セロリ', 'せろり', '셀러리')),
  chi.basic(
      'チ', 'ち', 'チーズ', 'ちーず', '치즈', KatakanaPracticeWord('チョコ', 'ちょこ', '초콜릿')),
  te.basic('テ', 'て', 'テレビ', 'てれび', '텔레비전',
      KatakanaPracticeWord('テニス', 'てにす', '테니스')),
  to.basic('ト', 'と', 'トイレ', 'といれ', '화장실',
      KatakanaPracticeWord('トンネル', 'とんねる', '터널')),
  na.basic('ナ', 'な', 'ナッツ', 'なっつ', '견과류',
      KatakanaPracticeWord('ナン', 'なん', '난(납작한 빵)')),
  ni.basic('ニ', 'に', 'ニット', 'にっと', '니트',
      KatakanaPracticeWord('ピクニック', 'ぴくにっく', '소풍')),
  nu.basic(
      'ヌ', 'ぬ', 'カヌー', 'かぬー', '카누', KatakanaPracticeWord('ヌードル', 'ぬーどる', '면')),
  ne.basic('ネ', 'ね', 'ネクタイ', 'ねくたい', '넥타이',
      KatakanaPracticeWord('ネックレス', 'ねっくれす', '목걸이')),
  no.basic(
      'ノ', 'の', 'ノート', 'のーと', '공책', KatakanaPracticeWord('ノック', 'のっく', '노크')),
  ha.basic(
      'ハ', 'は', 'ハンカチ', 'はんかち', '손수건', KatakanaPracticeWord('ハム', 'はむ', '햄')),
  hi.basic('ヒ', 'ひ', 'ヒーター', 'ひーたー', '난방기',
      KatakanaPracticeWord('ヒント', 'ひんと', '힌트')),
  he.basic('ヘ', 'へ', 'ヘルメット', 'へるめっと', '헬멧',
      KatakanaPracticeWord('ヘアブラシ', 'へあぶらし', '머리빗')),
  ho.basic('ホ', 'ほ', 'ホテル', 'ほてる', '호텔',
      KatakanaPracticeWord('ホットケーキ', 'ほっとけーき', '핫케이크')),
  ma.basic(
      'マ', 'ま', 'マスク', 'ますく', '마스크', KatakanaPracticeWord('マイク', 'まいく', '마이크')),
  mi.basic(
      'ミ', 'み', 'ミキサー', 'みきさー', '믹서', KatakanaPracticeWord('ミント', 'みんと', '민트')),
  mu.basic(
      'ム', 'む', 'ゲーム', 'げーむ', '게임', KatakanaPracticeWord('クリーム', 'くりーむ', '크림')),
  me.basic(
      'メ', 'め', 'メモ', 'めも', '메모', KatakanaPracticeWord('メール', 'めーる', '이메일')),
  mo.basic(
      'モ', 'も', 'モデル', 'もでる', '모델', KatakanaPracticeWord('モーター', 'もーたー', '모터')),
  ya.basic('ヤ', 'や', 'タイヤ', 'たいや', '타이어',
      KatakanaPracticeWord('イヤホン', 'いやほん', '이어폰')),
  yu.basic('ユ', 'ゆ', 'ユニフォーム', 'ゆにふぉーむ', '유니폼',
      KatakanaPracticeWord('ユニット', 'ゆにっと', '유닛')),
  yo.basic('ヨ', 'よ', 'ヨーグルト', 'よーぐると', '요구르트',
      KatakanaPracticeWord('ヨット', 'よっと', '요트')),
  ra.basic(
      'ラ', 'ら', 'ラーメン', 'らーめん', '라멘', KatakanaPracticeWord('ランプ', 'らんぷ', '램프')),
  ri.basic(
      'リ', 'り', 'リボン', 'りぼん', '리본', KatakanaPracticeWord('プリン', 'ぷりん', '푸딩')),
  ru.basic(
      'ル', 'る', 'ルーム', 'るーむ', '방', KatakanaPracticeWord('プール', 'ぷーる', '수영장')),
  re.basic(
      'レ', 'れ', 'レモン', 'れもん', '레몬', KatakanaPracticeWord('レタス', 'れたす', '양상추')),
  ro.basic(
      'ロ', 'ろ', 'ロボット', 'ろぼっと', '로봇', KatakanaPracticeWord('メロン', 'めろん', '멜론')),
  wo.basic('ヲ', 'を', 'パンヲタベル', 'ぱんをたべる', '빵을 먹다',
      KatakanaPracticeWord('ミズヲノム', 'みずをのむ', '물을 마시다'),
      exampleKind: KanaPracticeExampleKind.transcribedSentence),
  ga.basic('ガ', 'が', 'ガラス', 'がらす', '유리',
      KatakanaPracticeWord('ガソリン', 'がそりん', '휘발유')),
  gi.basic(
      'ギ', 'ぎ', 'ギプス', 'ぎぷす', '깁스', KatakanaPracticeWord('ギフト', 'ぎふと', '선물')),
  gu.basic('グ', 'ぐ', 'グラス', 'ぐらす', '유리잔',
      KatakanaPracticeWord('グラタン', 'ぐらたん', '그라탱')),
  ge.basic(
      'ゲ', 'げ', 'ゲート', 'げーと', '탑승구', KatakanaPracticeWord('ゲスト', 'げすと', '손님')),
  go.basic(
      'ゴ', 'ご', 'ゴム', 'ごむ', '고무', KatakanaPracticeWord('ゴール', 'ごーる', '결승점')),
  za.basic(
      'ザ', 'ざ', 'ザリガニ', 'ざりがに', '가재', KatakanaPracticeWord('ピザ', 'ぴざ', '피자')),
  ji.basic(
      'ジ', 'じ', 'ジャム', 'じゃむ', '잼', KatakanaPracticeWord('ジム', 'じむ', '헬스장')),
  zu.basic(
      'ズ', 'ず', 'ズーム', 'ずーむ', '확대', KatakanaPracticeWord('サイズ', 'さいず', '크기')),
  ze.basic('ゼ', 'ぜ', 'ゼリー', 'ぜりー', '젤리', KatakanaPracticeWord('ゼロ', 'ぜろ', '영')),
  zo.basic('ゾ', 'ぞ', 'ゾーン', 'ぞーん', '구역',
      KatakanaPracticeWord('リゾート', 'りぞーと', '휴양지')),
  da.basic(
      'ダ', 'だ', 'ダンス', 'だんす', '춤', KatakanaPracticeWord('ダイヤ', 'だいや', '다이아몬드')),
  di.basic(
      'ヂ', 'ぢ', 'ハナヂ', 'はなぢ', '코피', KatakanaPracticeWord('チヂム', 'ちぢむ', '줄어들다'),
      exampleKind: KanaPracticeExampleKind.transcribedWord),
  du.basic('ヅ', 'づ', 'ツヅク', 'つづく', '계속되다',
      KatakanaPracticeWord('テヅクリ', 'てづくり', '손수 만들기'),
      exampleKind: KanaPracticeExampleKind.transcribedWord),
  de.basic('デ', 'で', 'デパート', 'でぱーと', '백화점',
      KatakanaPracticeWord('デザート', 'でざーと', '디저트')),
  do_.basic(
      'ド', 'ど', 'ドア', 'どあ', '문', KatakanaPracticeWord('ドラム', 'どらむ', '드럼')),
  ba.basic(
      'バ', 'ば', 'バター', 'ばたー', '버터', KatakanaPracticeWord('バナナ', 'ばなな', '바나나')),
  bi.basic(
      'ビ', 'び', 'ビール', 'びーる', '맥주', KatakanaPracticeWord('ビデオ', 'びでお', '비디오')),
  bu.basic(
      'ブ', 'ぶ', 'ブーツ', 'ぶーつ', '부츠', KatakanaPracticeWord('ブラシ', 'ぶらし', '솔')),
  be.basic(
      'ベ', 'べ', 'ベンチ', 'べんち', '벤치', KatakanaPracticeWord('ベルト', 'べると', '벨트')),
  bo.basic(
      'ボ', 'ぼ', 'ボール', 'ぼーる', '공', KatakanaPracticeWord('ボタン', 'ぼたん', '단추')),
  pa.basic('パ', 'ぱ', 'パン', 'ぱん', '빵', KatakanaPracticeWord('パンダ', 'ぱんだ', '판다')),
  pi.basic(
      'ピ', 'ぴ', 'ピン', 'ぴん', '핀', KatakanaPracticeWord('ピーマン', 'ぴーまん', '피망')),
  pu.basic('プ', 'ぷ', 'プレゼント', 'ぷれぜんと', '선물',
      KatakanaPracticeWord('プロ', 'ぷろ', '전문가')),
  pe.basic('ペ', 'ぺ', 'ペット', 'ぺっと', '반려동물',
      KatakanaPracticeWord('ページ', 'ぺーじ', '페이지')),
  po.basic('ポ', 'ぽ', 'ポスト', 'ぽすと', '우체통',
      KatakanaPracticeWord('ポケット', 'ぽけっと', '주머니')),
  vu.basic('ヴ', 'ゔ', 'ヴァイオリン', 'ゔぁいおりん', '바이올린',
      KatakanaPracticeWord('ヴィーナス', 'ゔぃーなす', '비너스')),
  smallA.basic(
      'ァ', 'ぁ', 'ファイル', 'ふぁいる', '파일', KatakanaPracticeWord('ファン', 'ふぁん', '팬')),
  smallI.basic('ィ', 'ぃ', 'フィルム', 'ふぃるむ', '필름',
      KatakanaPracticeWord('ウィンドー', 'うぃんどー', '창')),
  smallU.basic('ゥ', 'ぅ', 'トゥシューズ', 'とぅしゅーず', '토슈즈',
      KatakanaPracticeWord('タトゥー', 'たとぅー', '문신')),
  smallE.basic(
      'ェ', 'ぇ', 'チェス', 'ちぇす', '체스', KatakanaPracticeWord('シェフ', 'しぇふ', '요리사')),
  smallO.basic('ォ', 'ぉ', 'フォーク', 'ふぉーく', '포크',
      KatakanaPracticeWord('ウォーキング', 'うぉーきんぐ', '걷기 운동')),
  smallYa.basic('ャ', 'ゃ', 'キャンプ', 'きゃんぷ', '캠핑',
      KatakanaPracticeWord('キャベツ', 'きゃべつ', '양배추')),
  smallYu.basic('ュ', 'ゅ', 'ジュース', 'じゅーす', '주스',
      KatakanaPracticeWord('チューブ', 'ちゅーぶ', '튜브')),
  smallYo.basic(
      'ョ', 'ょ', 'ショー', 'しょー', '쇼', KatakanaPracticeWord('チョーク', 'ちょーく', '분필')),
  smallTsu.basic(
      'ッ', 'っ', 'チケット', 'ちけっと', '표', KatakanaPracticeWord('ベッド', 'べっど', '침대')),
  smallWa.basic('ヮ', 'ゎ', 'クヮ', 'くゎ', '쿠와를 합친 소리',
      KatakanaPracticeWord('グヮ', 'ぐゎ', '구와를 합친 소리'),
      exampleKind: KanaPracticeExampleKind.combination,
      cue: '일부 표기에서는 앞 글자에 작은 와를 붙여 적어요.'),
  smallKa.basic('ヵ', '작은 카 (단위)', '三ヵ月', 'さんかげつ', '세 달',
      KatakanaPracticeWord('一ヵ所', 'いっかしょ', '한 곳'),
      exampleKind: KanaPracticeExampleKind.counter, cue: '이 예에서는 か(카)로 읽어요.'),
  smallKe.basic('ヶ', '작은 케 (단위)', '三ヶ月', 'さんかげつ', '세 달',
      KatakanaPracticeWord('一ヶ所', 'いっかしょ', '한 곳'),
      exampleKind: KanaPracticeExampleKind.counter, cue: '이 예에서는 か(카)로 읽어요.');

  const KatakanaPilotLetter({
    required this.glyph,
    required this.reading,
    required this.cue,
    required this.strokes,
    required this.strokeNumberPositions,
    required this.word,
    required this.wordReading,
    required this.meaning,
    required this.reviewWord,
  }) : exampleKind = KanaPracticeExampleKind.word;

  const KatakanaPilotLetter.basic(
    this.glyph,
    this.reading,
    this.word,
    this.wordReading,
    this.meaning,
    this.reviewWord, {
    this.cue = '',
    this.exampleKind = KanaPracticeExampleKind.word,
  })  : strokes = const [],
        strokeNumberPositions = const [];

  @override
  final String glyph;
  @override
  final String reading;
  @override
  final String cue;
  final List<List<Offset>> strokes;
  final List<Offset> strokeNumberPositions;
  @override
  final String word;
  @override
  final String wordReading;
  @override
  final String meaning;
  @override
  final KatakanaPracticeWord reviewWord;
  @override
  final KanaPracticeExampleKind exampleKind;

  @override
  String get reviewId => name;

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
        _ => [this],
      };
}

enum HiraganaPilotLetter implements KanaPracticeLetter {
  a('あ', '아', '윗가로획, 세로획, 마지막으로 둥근 획을 이어 그려요.', 'あめ', '비',
      KatakanaPracticeWord('あさ', 'あさ', '아침')),
  i('い', '이', '왼쪽 긴 획을 먼저 쓰고, 오른쪽 짧은 획을 나중에 써요.', 'いぬ', '개',
      KatakanaPracticeWord('いす', 'いす', '의자')),
  u('う', '우', '위쪽 짧은 획을 쓰고, 아래에서 오른쪽으로 갔다가 왼쪽 아래로 내려와요.', 'うみ', '바다',
      KatakanaPracticeWord('うた', 'うた', '노래')),
  e('え', '에', '위쪽 짧은 획을 먼저 쓰고, 아래의 꺾이는 획을 이어 그려요.', 'えき', '역',
      KatakanaPracticeWord('えんぴつ', 'えんぴつ', '연필')),
  o('お', '오', '가로획, 아래로 내려와 둥글게 도는 획, 오른쪽 위 짧은 획 순서예요.', 'おちゃ', '차',
      KatakanaPracticeWord('おに', 'おに', '도깨비')),
  ka.basic('か', '카', 'かさ', '우산', KatakanaPracticeWord('かみ', 'かみ', '종이')),
  ki.basic('き', '키', 'きつね', '여우', KatakanaPracticeWord('きのこ', 'きのこ', '버섯')),
  ku.basic('く', '쿠', 'くつ', '신발', KatakanaPracticeWord('くも', 'くも', '구름')),
  ke.basic('け', '케', 'けしごむ', '지우개', KatakanaPracticeWord('けむり', 'けむり', '연기')),
  ko.basic('こ', '코', 'こえ', '목소리', KatakanaPracticeWord('こめ', 'こめ', '쌀')),
  sa.basic('さ', '사', 'さかな', '물고기', KatakanaPracticeWord('さる', 'さる', '원숭이')),
  shi.basic('し', '시', 'しお', '소금', KatakanaPracticeWord('しろ', 'しろ', '흰색')),
  su.basic('す', '스', 'すし', '초밥', KatakanaPracticeWord('すいか', 'すいか', '수박')),
  se.basic('せ', '세', 'せかい', '세계', KatakanaPracticeWord('せなか', 'せなか', '등')),
  so.basic('そ', '소', 'そら', '하늘', KatakanaPracticeWord('そと', 'そと', '바깥')),
  ta.basic('た', '타', 'たまご', '달걀', KatakanaPracticeWord('たけ', 'たけ', '대나무')),
  chi.basic('ち', '치', 'ちず', '지도', KatakanaPracticeWord('ちから', 'ちから', '힘')),
  tsu.basic('つ', '츠', 'つき', '달', KatakanaPracticeWord('つくえ', 'つくえ', '책상')),
  te.basic('て', '테', 'てがみ', '편지', KatakanaPracticeWord('てぶくろ', 'てぶくろ', '장갑')),
  to.basic('と', '토', 'とけい', '시계', KatakanaPracticeWord('とり', 'とり', '새')),
  na.basic('な', '나', 'なつ', '여름', KatakanaPracticeWord('なまえ', 'なまえ', '이름')),
  ni.basic('に', '니', 'にわ', '정원', KatakanaPracticeWord('にく', 'にく', '고기')),
  nu.basic(
      'ぬ', '누', 'ぬの', '천', KatakanaPracticeWord('ぬいぐるみ', 'ぬいぐるみ', '봉제 인형')),
  ne.basic('ね', '네', 'ねこ', '고양이', KatakanaPracticeWord('ねつ', 'ねつ', '열')),
  no.basic('の', '노', 'のり', '김', KatakanaPracticeWord('のど', 'のど', '목')),
  ha.basic('は', '하', 'はな', '꽃', KatakanaPracticeWord('はし', 'はし', '젓가락')),
  hi.basic('ひ', '히', 'ひと', '사람', KatakanaPracticeWord('ひこうき', 'ひこうき', '비행기')),
  fu.basic('ふ', '후', 'ふね', '배', KatakanaPracticeWord('ふく', 'ふく', '옷')),
  he.basic('へ', '헤', 'へや', '방', KatakanaPracticeWord('へび', 'へび', '뱀')),
  ho.basic('ほ', '호', 'ほし', '별', KatakanaPracticeWord('ほね', 'ほね', '뼈')),
  ma.basic('ま', '마', 'まど', '창문', KatakanaPracticeWord('まち', 'まち', '동네')),
  mi.basic('み', '미', 'みず', '물', KatakanaPracticeWord('みち', 'みち', '길')),
  mu.basic('む', '무', 'むし', '벌레', KatakanaPracticeWord('むね', 'むね', '가슴')),
  me.basic('め', '메', 'めがね', '안경', KatakanaPracticeWord('めいし', 'めいし', '명함')),
  mo.basic('も', '모', 'もり', '숲', KatakanaPracticeWord('もくようび', 'もくようび', '목요일')),
  ya.basic('や', '야', 'やま', '산', KatakanaPracticeWord('やさい', 'やさい', '채소')),
  yu.basic('ゆ', '유', 'ゆき', '눈', KatakanaPracticeWord('ゆび', 'ゆび', '손가락')),
  yo.basic('よ', '요', 'よる', '밤', KatakanaPracticeWord('よこ', 'よこ', '옆')),
  ra.basic('ら', '라', 'さくら', '벚꽃', KatakanaPracticeWord('らいねん', 'らいねん', '내년')),
  ri.basic('り', '리', 'りんご', '사과', KatakanaPracticeWord('りす', 'りす', '다람쥐')),
  ru.basic('る', '루', 'くるま', '자동차', KatakanaPracticeWord('ひる', 'ひる', '낮')),
  re.basic('れ', '레', 'れきし', '역사', KatakanaPracticeWord('れんしゅう', 'れんしゅう', '연습')),
  ro.basic(
      'ろ', '로', 'ろく', '육(숫자 6)', KatakanaPracticeWord('ろうそく', 'ろうそく', '양초')),
  wa.basic('わ', '와', 'わに', '악어', KatakanaPracticeWord('わたし', 'わたし', '나')),
  wo.basic('を', '오 (목적격 조사)', 'ほんをよむ', '책을 읽다',
      KatakanaPracticeWord('みずをのむ', 'みずをのむ', '물을 마시다'),
      exampleKind: KanaPracticeExampleKind.sentence),
  n.basic('ん', 'ㄴ·ㅁ·ㅇ', 'ほん', '책', KatakanaPracticeWord('みかん', 'みかん', '귤')),
  ga.basic('が', '가', 'がくせい', '학생', KatakanaPracticeWord('がっき', 'がっき', '악기')),
  gi.basic(
      'ぎ', '기', 'ぎんこう', '은행', KatakanaPracticeWord('ぎゅうどん', 'ぎゅうどん', '소고기 덮밥')),
  gu.basic('ぐ', '구', 'ぐんて', '작업용 장갑', KatakanaPracticeWord('ぐあい', 'ぐあい', '상태')),
  ge.basic('げ', '게', 'げんき', '건강함', KatakanaPracticeWord('げんかん', 'げんかん', '현관')),
  go.basic('ご', '고', 'ごはん', '밥', KatakanaPracticeWord('ごぜん', 'ごぜん', '오전')),
  za.basic('ざ', '자', 'ざっし', '잡지', KatakanaPracticeWord('ざる', 'ざる', '소쿠리')),
  ji.basic('じ', '지 (시에 탁점)', 'じかん', '시간',
      KatakanaPracticeWord('じてんしゃ', 'じてんしゃ', '자전거')),
  zu.basic(
      'ず', '즈 (스에 탁점)', 'ずぼん', '바지', KatakanaPracticeWord('ずかん', 'ずかん', '도감')),
  ze.basic('ぜ', '제', 'ぜんぶ', '전부', KatakanaPracticeWord('ぜったい', 'ぜったい', '반드시')),
  zo.basic('ぞ', '조', 'ぞう', '코끼리', KatakanaPracticeWord('ぞうきん', 'ぞうきん', '걸레')),
  da.basic('だ', '다', 'だいがく', '대학교', KatakanaPracticeWord('だれ', 'だれ', '누구')),
  di.basic('ぢ', '지 (치에 탁점)', 'はなぢ', '코피',
      KatakanaPracticeWord('ちぢむ', 'ちぢむ', '줄어들다')),
  du.basic('づ', '즈 (츠에 탁점)', 'つづく', '계속되다',
      KatakanaPracticeWord('てづくり', 'てづくり', '손수 만들기')),
  de.basic('で', '데', 'でんわ', '전화', KatakanaPracticeWord('でぐち', 'でぐち', '출구')),
  do_.basic('ど', '도', 'どようび', '토요일', KatakanaPracticeWord('どろ', 'どろ', '진흙')),
  ba.basic('ば', '바', 'ばしょ', '장소', KatakanaPracticeWord('ばんごう', 'ばんごう', '번호')),
  bi.basic('び', '비', 'びょういん', '병원', KatakanaPracticeWord('びじゅつ', 'びじゅつ', '미술')),
  bu.basic(
      'ぶ', '부', 'ぶどう', '포도', KatakanaPracticeWord('ぶんぼうぐ', 'ぶんぼうぐ', '문방구')),
  be.basic(
      'べ', '베', 'べんとう', '도시락', KatakanaPracticeWord('べんきょう', 'べんきょう', '공부')),
  bo.basic('ぼ', '보', 'ぼうし', '모자', KatakanaPracticeWord('ぼたん', 'ぼたん', '단추')),
  pa.basic('ぱ', '파', 'はっぱ', '잎', KatakanaPracticeWord('いっぱい', 'いっぱい', '가득')),
  pi.basic(
      'ぴ', '피', 'いっぴき', '한 마리', KatakanaPracticeWord('ぴったり', 'ぴったり', '딱 맞게')),
  pu.basic('ぷ', '푸', 'てんぷら', '튀김', KatakanaPracticeWord('きっぷ', 'きっぷ', '승차권')),
  pe.basic('ぺ', '페', 'いっぺん', '한 번', KatakanaPracticeWord('ぺこり', 'ぺこり', '꾸벅')),
  po.basic('ぽ', '포', 'さんぽ', '산책', KatakanaPracticeWord('しっぽ', 'しっぽ', '꼬리')),
  vu.basic('ゔ', '우에 탁점', 'ゔぁ', 'ヴァ에 대응하는 히라가나 표기',
      KatakanaPracticeWord('ゔぃ', 'ゔぃ', 'ヴィ에 대응하는 히라가나 표기'),
      exampleKind: KanaPracticeExampleKind.combination,
      cue: '우에 탁점을 붙여 외래어의 소리를 나타낼 때 써요.'),
  smallA.basic('ぁ', '작은 아', 'ふぁ', 'ファ에 대응하는 히라가나 표기',
      KatakanaPracticeWord('つぁ', 'つぁ', 'ツァ에 대응하는 히라가나 표기'),
      exampleKind: KanaPracticeExampleKind.combination),
  smallI.basic('ぃ', '작은 이', 'ふぃ', 'フィ에 대응하는 히라가나 표기',
      KatakanaPracticeWord('うぃ', 'うぃ', 'ウィ에 대응하는 히라가나 표기'),
      exampleKind: KanaPracticeExampleKind.combination),
  smallU.basic('ぅ', '작은 우', 'とぅ', 'トゥ에 대응하는 히라가나 표기',
      KatakanaPracticeWord('どぅ', 'どぅ', 'ドゥ에 대응하는 히라가나 표기'),
      exampleKind: KanaPracticeExampleKind.combination),
  smallE.basic('ぇ', '작은 에', 'ちぇ', 'チェ에 대응하는 히라가나 표기',
      KatakanaPracticeWord('しぇ', 'しぇ', 'シェ에 대응하는 히라가나 표기'),
      exampleKind: KanaPracticeExampleKind.combination),
  smallO.basic('ぉ', '작은 오', 'ふぉ', 'フォ에 대응하는 히라가나 표기',
      KatakanaPracticeWord('うぉ', 'うぉ', 'ウォ에 대응하는 히라가나 표기'),
      exampleKind: KanaPracticeExampleKind.combination),
  smallYa.basic(
      'ゃ', '작은 야', 'きゃく', '손님', KatakanaPracticeWord('ひゃく', 'ひゃく', '백')),
  smallYu.basic(
      'ゅ', '작은 유', 'きゅうり', '오이', KatakanaPracticeWord('しゅくだい', 'しゅくだい', '숙제')),
  smallYo.basic(
      'ょ', '작은 요', 'ちょきん', '저축', KatakanaPracticeWord('りょこう', 'りょこう', '여행')),
  smallTsu.basic('っ', '작은 츠 (뒤 자음을 겹쳐 냄)', 'きって', '우표',
      KatakanaPracticeWord('がっこう', 'がっこう', '학교')),
  smallWa.basic('ゎ', '작은 와', 'くゎ', '쿠와를 합친 소리',
      KatakanaPracticeWord('ぐゎ', 'ぐゎ', '구와를 합친 소리'),
      exampleKind: KanaPracticeExampleKind.combination,
      cue: '일부 표기에서는 앞 글자에 작은 와를 붙여 적어요.');

  const HiraganaPilotLetter(this.glyph, this.reading, this.cue, this.word,
      this.meaning, this.reviewWord)
      : exampleKind = KanaPracticeExampleKind.word;

  const HiraganaPilotLetter.basic(
    this.glyph,
    this.reading,
    this.word,
    this.meaning,
    this.reviewWord, {
    this.cue = '',
    this.exampleKind = KanaPracticeExampleKind.word,
  });

  @override
  final String glyph;
  @override
  final String reading;
  @override
  final String cue;
  @override
  final String word;
  @override
  final String meaning;
  @override
  final KatakanaPracticeWord reviewWord;
  @override
  final KanaPracticeExampleKind exampleKind;
  @override
  String get wordReading => word;
  @override
  String get reviewId => name;
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
      [KatakanaPilotLetter.fu, KatakanaPilotLetter.wa, KatakanaPilotLetter.u]),
  firstRow(_katakanaFirstRow);

  const KatakanaPracticeGroup(this.letters);

  final List<KatakanaPilotLetter> letters;

  String get label => letters.map((letter) => letter.glyph).join('・');
}

enum KanaPracticeSection { basic, voiced, small }

/// Modern kana practice groups in gojuon order.
enum KanaPracticeRow {
  firstRow(
    [
      HiraganaPilotLetter.a,
      HiraganaPilotLetter.i,
      HiraganaPilotLetter.u,
      HiraganaPilotLetter.e,
      HiraganaPilotLetter.o,
    ],
    _katakanaFirstRow,
  ),
  kaRow(
    [
      HiraganaPilotLetter.ka,
      HiraganaPilotLetter.ki,
      HiraganaPilotLetter.ku,
      HiraganaPilotLetter.ke,
      HiraganaPilotLetter.ko,
    ],
    [
      KatakanaPilotLetter.ka,
      KatakanaPilotLetter.ki,
      KatakanaPilotLetter.ku,
      KatakanaPilotLetter.ke,
      KatakanaPilotLetter.ko,
    ],
  ),
  saRow(
    [
      HiraganaPilotLetter.sa,
      HiraganaPilotLetter.shi,
      HiraganaPilotLetter.su,
      HiraganaPilotLetter.se,
      HiraganaPilotLetter.so,
    ],
    [
      KatakanaPilotLetter.sa,
      KatakanaPilotLetter.shi,
      KatakanaPilotLetter.su,
      KatakanaPilotLetter.se,
      KatakanaPilotLetter.so,
    ],
  ),
  taRow(
    [
      HiraganaPilotLetter.ta,
      HiraganaPilotLetter.chi,
      HiraganaPilotLetter.tsu,
      HiraganaPilotLetter.te,
      HiraganaPilotLetter.to,
    ],
    [
      KatakanaPilotLetter.ta,
      KatakanaPilotLetter.chi,
      KatakanaPilotLetter.tsu,
      KatakanaPilotLetter.te,
      KatakanaPilotLetter.to,
    ],
  ),
  naRow(
    [
      HiraganaPilotLetter.na,
      HiraganaPilotLetter.ni,
      HiraganaPilotLetter.nu,
      HiraganaPilotLetter.ne,
      HiraganaPilotLetter.no,
    ],
    [
      KatakanaPilotLetter.na,
      KatakanaPilotLetter.ni,
      KatakanaPilotLetter.nu,
      KatakanaPilotLetter.ne,
      KatakanaPilotLetter.no,
    ],
  ),
  haRow(
    [
      HiraganaPilotLetter.ha,
      HiraganaPilotLetter.hi,
      HiraganaPilotLetter.fu,
      HiraganaPilotLetter.he,
      HiraganaPilotLetter.ho,
    ],
    [
      KatakanaPilotLetter.ha,
      KatakanaPilotLetter.hi,
      KatakanaPilotLetter.fu,
      KatakanaPilotLetter.he,
      KatakanaPilotLetter.ho,
    ],
  ),
  maRow(
    [
      HiraganaPilotLetter.ma,
      HiraganaPilotLetter.mi,
      HiraganaPilotLetter.mu,
      HiraganaPilotLetter.me,
      HiraganaPilotLetter.mo,
    ],
    [
      KatakanaPilotLetter.ma,
      KatakanaPilotLetter.mi,
      KatakanaPilotLetter.mu,
      KatakanaPilotLetter.me,
      KatakanaPilotLetter.mo,
    ],
  ),
  yaRow(
    [
      HiraganaPilotLetter.ya,
      HiraganaPilotLetter.yu,
      HiraganaPilotLetter.yo,
    ],
    [
      KatakanaPilotLetter.ya,
      KatakanaPilotLetter.yu,
      KatakanaPilotLetter.yo,
    ],
  ),
  raRow(
    [
      HiraganaPilotLetter.ra,
      HiraganaPilotLetter.ri,
      HiraganaPilotLetter.ru,
      HiraganaPilotLetter.re,
      HiraganaPilotLetter.ro,
    ],
    [
      KatakanaPilotLetter.ra,
      KatakanaPilotLetter.ri,
      KatakanaPilotLetter.ru,
      KatakanaPilotLetter.re,
      KatakanaPilotLetter.ro,
    ],
  ),
  waRow(
    [
      HiraganaPilotLetter.wa,
      HiraganaPilotLetter.wo,
      HiraganaPilotLetter.n,
    ],
    [
      KatakanaPilotLetter.wa,
      KatakanaPilotLetter.wo,
      KatakanaPilotLetter.n,
    ],
  ),
  gaRow(
    [
      HiraganaPilotLetter.ga,
      HiraganaPilotLetter.gi,
      HiraganaPilotLetter.gu,
      HiraganaPilotLetter.ge,
      HiraganaPilotLetter.go,
    ],
    [
      KatakanaPilotLetter.ga,
      KatakanaPilotLetter.gi,
      KatakanaPilotLetter.gu,
      KatakanaPilotLetter.ge,
      KatakanaPilotLetter.go,
    ],
    KanaPracticeSection.voiced,
  ),
  zaRow(
    [
      HiraganaPilotLetter.za,
      HiraganaPilotLetter.ji,
      HiraganaPilotLetter.zu,
      HiraganaPilotLetter.ze,
      HiraganaPilotLetter.zo,
    ],
    [
      KatakanaPilotLetter.za,
      KatakanaPilotLetter.ji,
      KatakanaPilotLetter.zu,
      KatakanaPilotLetter.ze,
      KatakanaPilotLetter.zo,
    ],
    KanaPracticeSection.voiced,
  ),
  daRow(
    [
      HiraganaPilotLetter.da,
      HiraganaPilotLetter.di,
      HiraganaPilotLetter.du,
      HiraganaPilotLetter.de,
      HiraganaPilotLetter.do_,
    ],
    [
      KatakanaPilotLetter.da,
      KatakanaPilotLetter.di,
      KatakanaPilotLetter.du,
      KatakanaPilotLetter.de,
      KatakanaPilotLetter.do_,
    ],
    KanaPracticeSection.voiced,
  ),
  baRow(
    [
      HiraganaPilotLetter.ba,
      HiraganaPilotLetter.bi,
      HiraganaPilotLetter.bu,
      HiraganaPilotLetter.be,
      HiraganaPilotLetter.bo,
    ],
    [
      KatakanaPilotLetter.ba,
      KatakanaPilotLetter.bi,
      KatakanaPilotLetter.bu,
      KatakanaPilotLetter.be,
      KatakanaPilotLetter.bo,
    ],
    KanaPracticeSection.voiced,
  ),
  paRow(
    [
      HiraganaPilotLetter.pa,
      HiraganaPilotLetter.pi,
      HiraganaPilotLetter.pu,
      HiraganaPilotLetter.pe,
      HiraganaPilotLetter.po,
    ],
    [
      KatakanaPilotLetter.pa,
      KatakanaPilotLetter.pi,
      KatakanaPilotLetter.pu,
      KatakanaPilotLetter.pe,
      KatakanaPilotLetter.po,
    ],
    KanaPracticeSection.voiced,
  ),
  vuRow(
    [
      HiraganaPilotLetter.vu,
    ],
    [
      KatakanaPilotLetter.vu,
    ],
    KanaPracticeSection.voiced,
  ),
  smallVowels(
    [
      HiraganaPilotLetter.smallA,
      HiraganaPilotLetter.smallI,
      HiraganaPilotLetter.smallU,
      HiraganaPilotLetter.smallE,
      HiraganaPilotLetter.smallO,
    ],
    [
      KatakanaPilotLetter.smallA,
      KatakanaPilotLetter.smallI,
      KatakanaPilotLetter.smallU,
      KatakanaPilotLetter.smallE,
      KatakanaPilotLetter.smallO,
    ],
    KanaPracticeSection.small,
  ),
  smallYRow(
    [
      HiraganaPilotLetter.smallYa,
      HiraganaPilotLetter.smallYu,
      HiraganaPilotLetter.smallYo,
    ],
    [
      KatakanaPilotLetter.smallYa,
      KatakanaPilotLetter.smallYu,
      KatakanaPilotLetter.smallYo,
    ],
    KanaPracticeSection.small,
  ),
  smallTsu(
    [
      HiraganaPilotLetter.smallTsu,
    ],
    [
      KatakanaPilotLetter.smallTsu,
    ],
    KanaPracticeSection.small,
  ),
  smallWa(
    [
      HiraganaPilotLetter.smallWa,
    ],
    [
      KatakanaPilotLetter.smallWa,
    ],
    KanaPracticeSection.small,
  ),
  smallKaKe(
    [],
    [
      KatakanaPilotLetter.smallKa,
      KatakanaPilotLetter.smallKe,
    ],
    KanaPracticeSection.small,
  );

  const KanaPracticeRow(this._hiragana, this._katakana,
      [this.section = KanaPracticeSection.basic]);

  final KanaPracticeSection section;

  final List<HiraganaPilotLetter> _hiragana;
  final List<KatakanaPilotLetter> _katakana;

  List<KanaPracticeLetter> letters({required bool hiragana}) =>
      hiragana ? _hiragana : _katakana;

  String label({required bool hiragana}) =>
      letters(hiragana: hiragana).map((letter) => letter.glyph).join('・');
}

const _katakanaFirstRow = [
  KatakanaPilotLetter.a,
  KatakanaPilotLetter.i,
  KatakanaPilotLetter.u,
  KatakanaPilotLetter.e,
  KatakanaPilotLetter.o,
];
