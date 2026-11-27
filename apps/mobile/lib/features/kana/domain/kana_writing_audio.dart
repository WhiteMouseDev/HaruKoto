import 'katakana_pilot.dart';

class KanaWritingAudioTarget {
  const KanaWritingAudioTarget({required this.text, required this.label});

  final String text;
  final String label;
}

/// Speech targets are Japanese text, independent of the displayed Korean hint.
/// Context-dependent and small kana are heard within the existing example.
class KanaWritingAudio {
  const KanaWritingAudio({required this.example, this.character});

  final KanaWritingAudioTarget? character;
  final KanaWritingAudioTarget example;

  factory KanaWritingAudio.forLetter(KanaPracticeLetter letter,
      {bool review = false}) {
    const contextual = {
      'を',
      'ヲ',
      'は',
      'へ',
      'ん',
      'ン',
      'ゔ',
      'ヴ',
      'ぁ',
      'ぃ',
      'ぅ',
      'ぇ',
      'ぉ',
      'ゃ',
      'ゅ',
      'ょ',
      'っ',
      'ゎ',
      'ァ',
      'ィ',
      'ゥ',
      'ェ',
      'ォ',
      'ャ',
      'ュ',
      'ョ',
      'ッ',
      'ヮ',
      'ヵ',
      'ヶ',
    };
    final label = switch (letter.exampleKind) {
      KanaPracticeExampleKind.word ||
      KanaPracticeExampleKind.transcribedWord =>
        '단어 듣기',
      KanaPracticeExampleKind.sentence ||
      KanaPracticeExampleKind.transcribedSentence =>
        '문장 듣기',
      KanaPracticeExampleKind.combination => '조합 듣기',
      KanaPracticeExampleKind.counter => '표기 읽기 듣기',
    };
    return KanaWritingAudio(
      character: contextual.contains(letter.glyph)
          ? null
          : KanaWritingAudioTarget(text: letter.glyph, label: '글자 듣기'),
      example: KanaWritingAudioTarget(
          text: review ? letter.reviewWord.reading : letter.wordReading,
          label: label),
    );
  }
}
