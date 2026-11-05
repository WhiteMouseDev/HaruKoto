import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/kana/domain/kana_writing_audio.dart';
import 'package:harukoto_mobile/features/kana/domain/katakana_pilot.dart';

void main() {
  final letters = <KanaPracticeLetter>[
    ...HiraganaPilotLetter.values,
    ...KatakanaPilotLetter.values,
  ];

  test('all 166 normal and review targets fit the existing kana TTS contract',
      () {
    final permitted =
        RegExp(r'^[\u3040-\u309F\u30A0-\u30FF\u3000-\u303F\uFF66-\uFF9F]+$');
    expect(letters, hasLength(166));
    for (final letter in letters) {
      for (final review in [false, true]) {
        final audio = KanaWritingAudio.forLetter(letter, review: review);
        for (final target in [
          if (audio.character != null) audio.character!,
          audio.example
        ]) {
          expect(permitted.hasMatch(target.text), isTrue,
              reason: '${letter.glyph}: ${target.text}');
          expect(target.text.runes.length, inInclusiveRange(1, 10));
        }
      }
    }
  });

  test('ordinary letters send Japanese glyphs rather than Korean sound hints',
      () {
    final hira = KanaWritingAudio.forLetter(HiraganaPilotLetter.a);
    expect(HiraganaPilotLetter.a.reading, '아');
    expect(hira.character!.text, 'あ');
    expect(hira.character!.label, '글자 듣기');
    final kata = KanaWritingAudio.forLetter(KatakanaPilotLetter.ka);
    expect(kata.character!.text, 'カ');
    expect(kata.example.text, 'かめら');
  });

  test('small and context dependent glyphs have only contextual listening', () {
    const contextual = 'をヲはへんンゔヴぁぃぅぇぉゃゅょっゎァィゥェォャュョッヮヵヶ';
    final glyphs = contextual.runes.map(String.fromCharCode).toSet();
    for (final letter in letters) {
      final audio = KanaWritingAudio.forLetter(letter);
      expect(audio.character == null, glyphs.contains(letter.glyph),
          reason: letter.glyph);
      if (glyphs.contains(letter.glyph)) {
        expect(audio.example.text, isNot(letter.glyph));
      }
    }
  });

  test('daily review hears its own alternate example', () {
    final learning = KanaWritingAudio.forLetter(KatakanaPilotLetter.shi);
    final review =
        KanaWritingAudio.forLetter(KatakanaPilotLetter.shi, review: true);
    expect(learning.example.text, 'みしん');
    expect(review.example.text, 'しーる');
    expect(review.example.label, '단어 듣기');
  });

  test('particle, combination and counter targets retain truthful labels', () {
    final particle = KanaWritingAudio.forLetter(HiraganaPilotLetter.wo);
    expect(particle.example.text, 'ほんをよむ');
    expect(particle.example.label, '문장 듣기');
    final combination = KanaWritingAudio.forLetter(HiraganaPilotLetter.smallA);
    expect(combination.example.label, '조합 듣기');
    final counter = KanaWritingAudio.forLetter(KatakanaPilotLetter.smallKa);
    expect(counter.example.label, '표기 읽기 듣기');
    expect(counter.example.text, KatakanaPilotLetter.smallKa.wordReading);
    expect(counter.example.text, isNot(KatakanaPilotLetter.smallKa.word));
  });
}
