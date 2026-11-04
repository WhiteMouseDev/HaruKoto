import 'dart:convert';
import 'dart:math';

import '../data/models/kana_character_model.dart';
import '../data/models/kana_stage_model.dart';

final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

String newKanaCardActivityId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex =
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

enum KanaCardPhase { intro, practice, quiz }

class KanaCardCursor {
  const KanaCardCursor(this.phase, this.index);
  final KanaCardPhase phase;
  final int index;

  Map<String, dynamic> toJson() => {'phase': phase.name, 'index': index};

  factory KanaCardCursor.fromJson(Map<String, dynamic> json, int count) {
    final phase = KanaCardPhase.values
        .where((value) => value.name == json['phase'])
        .firstOrNull;
    final index = json['index'];
    if (phase == null ||
        index is! int ||
        index < 0 ||
        (phase == KanaCardPhase.quiz ? index != 0 : index >= count)) {
      throw const FormatException('Invalid kana card cursor');
    }
    return KanaCardCursor(phase, index);
  }

  KanaCardCursor next(int count) => index + 1 < count
      ? KanaCardCursor(phase, index + 1)
      : KanaCardCursor(
          phase == KanaCardPhase.intro
              ? KanaCardPhase.practice
              : KanaCardPhase.quiz,
          0);

  @override
  bool operator ==(Object other) =>
      other is KanaCardCursor && other.phase == phase && other.index == index;
  @override
  int get hashCode => Object.hash(phase, index);
}

/// Ordered visible content is frozen as well as IDs. A changed lesson cannot
/// reinterpret a pending request as a different card or overwrite its only ID.
class KanaCardContent {
  KanaCardContent(
      {required this.owner,
      required this.stageId,
      required this.kanaType,
      required this.stageNumber,
      required List<({String id, String text})> characters})
      : characters = List.unmodifiable(characters);

  factory KanaCardContent.fromStage(
          String owner, KanaStageModel stage, List<KanaCharacterModel> chars) =>
      KanaCardContent(
        owner: owner,
        stageId: stage.id,
        kanaType: stage.kanaType,
        stageNumber: stage.stageNumber,
        characters: [
          for (final char in chars) (id: char.id, text: char.character)
        ],
      );

  final String owner;
  final String stageId;
  final String kanaType;
  final int stageNumber;
  final List<({String id, String text})> characters;
  String get signature => jsonEncode(toJson());

  Map<String, dynamic> toJson() => {
        'owner': owner,
        'stageId': stageId,
        'kanaType': kanaType,
        'stageNumber': stageNumber,
        'characters': [
          for (final char in characters) {'id': char.id, 'text': char.text}
        ],
      };

  factory KanaCardContent.fromJson(Map<String, dynamic> json) {
    final chars = json['characters'];
    if (json['owner'] is! String ||
        json['stageId'] is! String ||
        !['HIRAGANA', 'KATAKANA'].contains(json['kanaType']) ||
        json['stageNumber'] is! int ||
        (json['stageNumber'] as int) < 1 ||
        chars is! List ||
        chars.isEmpty ||
        chars.length > 128) {
      throw const FormatException('Invalid kana card content');
    }
    final parsed = <({String id, String text})>[];
    final ids = <String>{};
    for (final char in chars) {
      if (char is! Map<String, dynamic> ||
          char['id'] is! String ||
          char['text'] is! String ||
          (char['id'] as String).isEmpty ||
          (char['text'] as String).isEmpty ||
          !ids.add(char['id'] as String)) {
        throw const FormatException('Invalid kana character snapshot');
      }
      parsed.add((id: char['id'] as String, text: char['text'] as String));
    }
    return KanaCardContent(
        owner: json['owner'] as String,
        stageId: json['stageId'] as String,
        kanaType: json['kanaType'] as String,
        stageNumber: json['stageNumber'] as int,
        characters: parsed);
  }

  @override
  bool operator ==(Object other) =>
      other is KanaCardContent && other.signature == signature;
  @override
  int get hashCode => signature.hashCode;
}

class KanaCardActivity {
  const KanaCardActivity(
      {required this.activityId, required this.owner, required this.kanaId});
  final String activityId;
  final String owner;
  final String kanaId;

  Map<String, dynamic> toJson() =>
      {'activityId': activityId, 'expectedUserId': owner, 'kanaId': kanaId};
  factory KanaCardActivity.fromJson(Map<String, dynamic> json) {
    if (!_uuid.hasMatch('${json['activityId']}') ||
        !_uuid.hasMatch('${json['expectedUserId']}') ||
        !_uuid.hasMatch('${json['kanaId']}') ||
        json.length != 3) {
      throw const FormatException('Invalid kana card activity');
    }
    return KanaCardActivity(
        activityId: json['activityId'] as String,
        owner: json['expectedUserId'] as String,
        kanaId: json['kanaId'] as String);
  }
}

class KanaCardReceipt {
  const KanaCardReceipt({required this.activityId, required this.processedAt});
  final String activityId;
  final DateTime processedAt;

  Map<String, dynamic> toJson() => {
        'ok': true,
        'activityId': activityId,
        'processedAt': processedAt.toUtc().toIso8601String()
      };

  factory KanaCardReceipt.fromJson(Map<String, dynamic> json) {
    final value = json['processedAt'];
    if (json['ok'] != true ||
        !_uuid.hasMatch('${json['activityId']}') ||
        value is! String ||
        !RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(value)) {
      throw const FormatException('Invalid kana card receipt');
    }
    final parsed = DateTime.tryParse(value);
    final date = RegExp(
            r'^(\d{4})-(\d{2})-(\d{2})T([01]\d|2[0-3]):[0-5]\d:[0-5]\d(?:\.\d{1,6})?(?:Z|\+00:00)$')
        .firstMatch(value);
    final year = date == null ? null : int.tryParse(date[1]!);
    final month = date == null ? null : int.tryParse(date[2]!);
    final day = date == null ? null : int.tryParse(date[3]!);
    if (parsed == null ||
        date == null ||
        year == null ||
        month == null ||
        day == null ||
        parsed.toUtc().year != year ||
        parsed.toUtc().month != month ||
        parsed.toUtc().day != day) {
      throw const FormatException('Invalid kana card receipt time');
    }
    return KanaCardReceipt(
        activityId: json['activityId'] as String, processedAt: parsed.toUtc());
  }
}

class KanaCardJournal {
  const KanaCardJournal(
      {required this.content,
      required this.cursor,
      this.pending,
      this.receipt,
      this.lastReceipt});
  final KanaCardContent content;
  final KanaCardCursor cursor;
  final KanaCardActivity? pending;
  final KanaCardReceipt? receipt;
  final KanaCardReceipt? lastReceipt;

  KanaCardJournal prepare(String id) {
    if (pending != null || cursor.phase == KanaCardPhase.quiz) {
      throw const FormatException('Card action already pending');
    }
    return KanaCardJournal(
        content: content,
        cursor: cursor,
        lastReceipt: lastReceipt,
        pending: KanaCardActivity.fromJson({
          'activityId': id,
          'expectedUserId': content.owner,
          'kanaId': content.characters[cursor.index].id,
        }));
  }

  KanaCardJournal acknowledge(KanaCardReceipt value) {
    if (pending == null || value.activityId != pending!.activityId) {
      throw const FormatException('Kana receipt identity mismatch');
    }
    return KanaCardJournal(
        content: content,
        cursor: cursor,
        pending: pending,
        receipt: value,
        lastReceipt: lastReceipt);
  }

  KanaCardJournal advance() {
    if ((pending != null && receipt == null) ||
        cursor.phase == KanaCardPhase.quiz) {
      throw const FormatException('Kana card is not acknowledged');
    }
    return KanaCardJournal(
        content: content,
        cursor: cursor.next(content.characters.length),
        lastReceipt: receipt ?? lastReceipt);
  }

  String encode() => jsonEncode({
        'version': 1,
        'content': content.toJson(),
        'cursor': cursor.toJson(),
        'pending': pending?.toJson(),
        'lastReceipt': lastReceipt?.toJson(),
        'receipt': receipt?.toJson()
      });

  factory KanaCardJournal.decode(String raw) {
    if (raw.length > 64 * 1024) {
      throw const FormatException('Kana journal too large');
    }
    final value = jsonDecode(raw);
    if (value is! Map<String, dynamic> ||
        value['version'] != 1 ||
        value['content'] is! Map<String, dynamic> ||
        value['cursor'] is! Map<String, dynamic> ||
        (value['pending'] != null &&
            value['pending'] is! Map<String, dynamic>) ||
        (value['receipt'] != null &&
            value['receipt'] is! Map<String, dynamic>) ||
        (value['lastReceipt'] != null &&
            value['lastReceipt'] is! Map<String, dynamic>)) {
      throw const FormatException('Invalid kana card journal');
    }
    final content =
        KanaCardContent.fromJson(value['content'] as Map<String, dynamic>);
    final cursor = KanaCardCursor.fromJson(
        value['cursor'] as Map<String, dynamic>, content.characters.length);
    final pending = value['pending'] == null
        ? null
        : KanaCardActivity.fromJson(value['pending'] as Map<String, dynamic>);
    final lastReceipt = value['lastReceipt'] == null
        ? null
        : KanaCardReceipt.fromJson(
            value['lastReceipt'] as Map<String, dynamic>);
    final receipt = value['receipt'] == null
        ? null
        : KanaCardReceipt.fromJson(value['receipt'] as Map<String, dynamic>);
    if ((receipt != null && receipt.activityId != pending?.activityId) ||
        (pending != null &&
            (cursor.phase == KanaCardPhase.quiz ||
                pending.owner != content.owner ||
                pending.kanaId != content.characters[cursor.index].id))) {
      throw const FormatException('Kana journal action mismatch');
    }
    return KanaCardJournal(
        content: content,
        cursor: cursor,
        pending: pending,
        receipt: receipt,
        lastReceipt: lastReceipt);
  }
}
