import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/kana/domain/kana_card_progress.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _other = '22222222-2222-4222-8222-222222222222';
const _kana = '33333333-3333-4333-8333-333333333333';
const _secondKana = '44444444-4444-4444-8444-444444444444';
const _activity = '55555555-5555-4555-8555-555555555555';
const _secondActivity = '66666666-6666-4666-8666-666666666666';

void main() {
  test('prepared action survives encoding with identical owner, kana and ID',
      () {
    final prepared = _initial().prepare(_activity);
    final restored = KanaCardJournal.decode(prepared.encode());
    expect(restored.pending!.toJson(), {
      'activityId': _activity,
      'expectedUserId': _owner,
      'kanaId': _kana,
    });
    expect(restored.cursor, const KanaCardCursor(KanaCardPhase.intro, 0));
    expect(restored.receipt, isNull);
    expect(() => restored.prepare(_secondActivity), throwsFormatException);
    expect(restored.encode(), prepared.encode());
  });

  test('unacknowledged pending action cannot advance the cursor', () {
    final pending = _initial().prepare(_activity);
    expect(pending.advance, throwsFormatException);
    expect(pending.cursor.index, 0);
    expect(pending.pending!.activityId, _activity);
  });

  test(
      'ACK keeps original cursor until explicit advance and retains one receipt',
      () {
    final prepared = _initial().prepare(_activity);
    final acked = prepared.acknowledge(_receipt(_activity));
    final restoredAck = KanaCardJournal.decode(acked.encode());
    expect(restoredAck.cursor, prepared.cursor);
    expect(restoredAck.pending!.activityId, _activity);
    expect(restoredAck.receipt!.activityId, _activity);
    final next = restoredAck.advance();
    expect(next.cursor, const KanaCardCursor(KanaCardPhase.practice, 0));
    expect(next.pending, isNull);
    expect(next.receipt, isNull);
    expect(next.lastReceipt!.activityId, _activity);
  });

  test(
      'intro and practice of same kana use separate IDs, bounded quiz tombstone',
      () {
    final intro = _initial()
        .prepare(_activity)
        .acknowledge(_receipt(_activity))
        .advance();
    final practice = intro.prepare(_secondActivity);
    expect(practice.pending!.kanaId, _kana);
    expect(practice.pending!.activityId, isNot(_activity));
    final quiz = practice.acknowledge(_receipt(_secondActivity)).advance();
    final restored = KanaCardJournal.decode(quiz.encode());
    expect(restored.cursor, const KanaCardCursor(KanaCardPhase.quiz, 0));
    expect(restored.lastReceipt!.activityId, _secondActivity);
    expect(restored.encode(), isNot(contains(_activity)));
    expect(restored.encode().length, lessThan(2048));
    expect(restored.pending, isNull);
    expect(() => restored.prepare(_activity), throwsFormatException);
    expect(restored.advance, throwsFormatException);
  });

  test('wrong ACK identity cannot replace a prepared action', () {
    final pending = _initial().prepare(_activity);
    expect(() => pending.acknowledge(_receipt(_secondActivity)),
        throwsFormatException);
    expect(pending.pending!.activityId, _activity);
    expect(() => _initial().acknowledge(_receipt(_activity)),
        throwsFormatException);
  });

  test(
      'ordered visible content is immutable and distinguishes owner/text/order',
      () {
    final chars = [(id: _kana, text: 'あ'), (id: _secondKana, text: 'い')];
    final content = _content(characters: chars);
    chars.clear();
    expect(content.characters, hasLength(2));
    expect(() => content.characters.clear(), throwsUnsupportedError);
    expect(content, KanaCardContent.fromJson(content.toJson()));
    expect(content,
        isNot(_content(owner: _other, characters: content.characters)));
    expect(content,
        isNot(_content(characters: content.characters.reversed.toList())));
    expect(
        content,
        isNot(_content(characters: [
          (id: _kana, text: 'ア'),
          (id: _secondKana, text: 'い')
        ])));
  });

  for (final value in [
    '2026-11-04T01:02:03Z',
    '2026-11-04T01:02:03.123456+00:00'
  ]) {
    test('receipt accepts real explicit UTC time $value', () {
      final receipt = KanaCardReceipt.fromJson(
          {'ok': true, 'activityId': _activity, 'processedAt': value});
      expect(receipt.processedAt.isUtc, isTrue);
      expect(receipt.toJson()['processedAt'], endsWith('Z'));
    });
  }
  for (final value in [
    '2026-11-04T01:02:03',
    '2026-11-04T10:02:03+09:00',
    '2026-02-30T01:02:03Z',
    '2026-13-01T01:02:03Z',
    '2026-00-01T01:02:03Z',
    '2026-11-04T24:02:03Z',
    '2026-11-04T01:60:03Z',
    '2026-11-04T01:02:60Z',
    '2026-11-04T01:02:03.1234567Z',
    'not-a-date',
  ]) {
    test('receipt rejects invalid or non-UTC time $value', () {
      expect(
          () => KanaCardReceipt.fromJson(
              {'ok': true, 'activityId': _activity, 'processedAt': value}),
          throwsFormatException);
    });
  }

  for (final field in ['activityId', 'expectedUserId', 'kanaId']) {
    test('activity rejects malformed $field', () {
      final json = _initial().prepare(_activity).pending!.toJson()
        ..[field] = 'not-an-id';
      expect(() => KanaCardActivity.fromJson(json), throwsFormatException);
    });
  }
  test('activity rejects unrecognized request fields', () {
    final json = _initial().prepare(_activity).pending!.toJson()
      ..['learned'] = true;
    expect(() => KanaCardActivity.fromJson(json), throwsFormatException);
  });
  test('generated activity ID is a fresh UUID v4', () {
    final ids = List.generate(100, (_) => newKanaCardActivityId());
    expect(ids.toSet(), hasLength(100));
    expect(
        ids,
        everyElement(matches(RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'))));
  });

  final changes = <String, void Function(Map<String, dynamic>)>{
    'version': (j) => j['version'] = 2,
    'negative cursor': (j) =>
        (j['cursor'] as Map<String, dynamic>)['index'] = -1,
    'out of range cursor': (j) =>
        (j['cursor'] as Map<String, dynamic>)['index'] = 1,
    'unknown phase': (j) =>
        (j['cursor'] as Map<String, dynamic>)['phase'] = 'unknown',
    'quiz pending': (j) =>
        (j['cursor'] as Map<String, dynamic>)['phase'] = 'quiz',
    'different owner': (j) =>
        (j['pending'] as Map<String, dynamic>)['expectedUserId'] = _other,
    'different kana': (j) =>
        (j['pending'] as Map<String, dynamic>)['kanaId'] = _secondKana,
    'unmatched receipt': (j) =>
        j['receipt'] = _receipt(_secondActivity).toJson(),
    'receipt without pending': (j) {
      j['pending'] = null;
      j['receipt'] = _receipt(_activity).toJson();
    },
    'empty characters': (j) =>
        (j['content'] as Map<String, dynamic>)['characters'] = [],
    'duplicate characters': (j) =>
        (j['content'] as Map<String, dynamic>)['characters'] = [
          {'id': _kana, 'text': 'あ'},
          {'id': _kana, 'text': 'い'}
        ],
  };
  for (final change in changes.entries) {
    test('corrupted journal rejected: ${change.key}', () {
      final json = jsonDecode(_initial().prepare(_activity).encode())
          as Map<String, dynamic>;
      change.value(json);
      expect(() => KanaCardJournal.decode(jsonEncode(json)),
          throwsFormatException);
    });
  }
  for (final field in ['pending', 'receipt', 'lastReceipt']) {
    for (final value in <Object>[[], 'corrupt-object', 7]) {
      test(
          'wrong nested $field shape is a non-retryable format failure: $value',
          () {
        final json = jsonDecode(_initial().prepare(_activity).encode())
            as Map<String, dynamic>;
        json[field] = value;
        expect(() => KanaCardJournal.decode(jsonEncode(json)),
            throwsFormatException);
      });
    }
  }

  for (final raw in ['not-json', '[]', '{}', ' ' * (64 * 1024 + 1)]) {
    test('invalid or oversized journal is rejected (length ${raw.length})', () {
      expect(() => KanaCardJournal.decode(raw), throwsFormatException);
    });
  }
}

KanaCardContent _content(
        {String owner = _owner,
        List<({String id, String text})>? characters}) =>
    KanaCardContent(
        owner: owner,
        stageId: 'stage-one',
        kanaType: 'HIRAGANA',
        stageNumber: 1,
        characters: characters ?? [(id: _kana, text: 'あ')]);
KanaCardJournal _initial() => KanaCardJournal(
    content: _content(), cursor: const KanaCardCursor(KanaCardPhase.intro, 0));
KanaCardReceipt _receipt(String id) => KanaCardReceipt(
    activityId: id, processedAt: DateTime.utc(2026, 11, 4, 1, 2, 3));
