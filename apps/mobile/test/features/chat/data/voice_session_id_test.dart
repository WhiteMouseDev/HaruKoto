import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/voice_session_id.dart';

void main() {
  test('voice session ids are distinct RFC4122 version4 UUIDs', () {
    final ids = List.generate(100, (_) => createVoiceSessionId());
    expect(ids.toSet(), hasLength(100));
    for (final id in ids) {
      expect(
          id,
          matches(RegExp(
              r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$')));
    }
  });
}
