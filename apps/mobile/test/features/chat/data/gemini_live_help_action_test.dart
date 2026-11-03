import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_help_action.dart';

void main() {
  test('support actions retain the selected utterance and conversation', () {
    for (final action in GeminiLiveHelpAction.values) {
      final instruction = action.instruction(targetText: '何名様ですか。');
      expect(instruction, contains('何名様ですか。'));
      expect(instruction, contains('挨拶や状況説明をやり直さない'));
    }
    expect(GeminiLiveHelpAction.repeat.instruction(), contains('同じ日本語'));
    expect(GeminiLiveHelpAction.slower.instruction(), contains('ゆっくり'));
    expect(GeminiLiveHelpAction.meaning.instruction(), contains('韓国語'));
    expect(GeminiLiveHelpAction.replyHint.instruction(), contains('返答例を一つ'));
  });

  test('empty target uses recent conversation and long targets are bounded',
      () {
    expect(
      GeminiLiveHelpAction.meaning.instruction(targetText: '  '),
      contains('直前に話した内容'),
    );
    final longText = List.filled(2000, 'あ').join();
    expect(
      GeminiLiveHelpAction.meaning.instruction(targetText: longText).length,
      lessThan(1800),
    );
  });

  test('Korean meanings translate honorifics instead of sounding them out', () {
    final instruction = GeminiLiveHelpAction.meaning.instruction(
      targetText: 'キム様、少々お待ちください。',
    );

    expect(instruction, contains('キム様、少々お待ちください。'));
    expect(instruction, contains('「さん」「様」を音写せず'));
    expect(instruction, contains('「님」「고객님」'));
    expect(GeminiLiveHelpAction.repeat.instruction(), isNot(contains('「님」')));
  });
}
