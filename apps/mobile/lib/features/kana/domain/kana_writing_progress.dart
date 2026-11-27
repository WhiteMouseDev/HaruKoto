import 'dart:convert';
import 'dart:ui';

import 'katakana_pilot.dart';

enum KanaWritingMode { row, comparison }

enum KanaWritingStep { compare, recall, word }

class KanaWritingScope {
  const KanaWritingScope({required this.owner, required this.hiragana});

  final String owner;
  final bool hiragana;
  String get script => hiragana ? 'hiragana' : 'katakana';

  @override
  bool operator ==(Object other) =>
      other is KanaWritingScope &&
      owner == other.owner &&
      hiragana == other.hiragana;

  @override
  int get hashCode => Object.hash(owner, hiragana);
}

class KanaWritingSession {
  KanaWritingSession({
    required List<KanaPracticeLetter> letters,
    required this.index,
    required this.step,
    required this.mode,
    this.showExample = false,
    this.selectedIndex,
    List<List<Offset>> strokes = const [],
  })  : letters = List.unmodifiable(letters),
        strokes = List.unmodifiable(
            strokes.map((stroke) => List<Offset>.unmodifiable(stroke)));

  final List<KanaPracticeLetter> letters;
  final int index;
  final KanaWritingStep step;
  final KanaWritingMode mode;
  final bool showExample;
  final int? selectedIndex;
  final List<List<Offset>> strokes;

  KanaPracticeLetter get letter => letters[index];

  KanaPracticeRow? get row {
    if (mode != KanaWritingMode.row || letters.isEmpty) return null;
    final hiragana = letters.first is HiraganaPilotLetter;
    for (final row in KanaPracticeRow.values) {
      final expected = row.letters(hiragana: hiragana);
      if (expected.length == letters.length &&
          List.generate(expected.length, (i) => expected[i] == letters[i])
              .every((same) => same)) {
        return row;
      }
    }
    return null;
  }

  void validate(KanaWritingScope scope) {
    final allowed = scope.hiragana
        ? HiraganaPilotLetter.values.cast<KanaPracticeLetter>()
        : KatakanaPilotLetter.values.cast<KanaPracticeLetter>();
    if (letters.isEmpty ||
        letters.length > allowed.length ||
        letters.toSet().length != letters.length ||
        !letters.every(allowed.contains) ||
        index < 0 ||
        index >= letters.length ||
        (mode == KanaWritingMode.row && row == null) ||
        (showExample && (step != KanaWritingStep.recall || strokes.isEmpty)) ||
        (selectedIndex != null &&
            (step != KanaWritingStep.word ||
                selectedIndex! < 0 ||
                selectedIndex! >= letter.word.runes.length)) ||
        (step != KanaWritingStep.recall && strokes.isNotEmpty) ||
        strokes.length > 32) {
      throw const FormatException('Invalid kana writing checkpoint');
    }
    for (final stroke in strokes) {
      if (stroke.length < 2 || stroke.length > 1024) {
        throw const FormatException('Invalid kana drawing stroke');
      }
      for (final point in stroke) {
        if (!point.dx.isFinite ||
            !point.dy.isFinite ||
            point.dx < 0 ||
            point.dx > 1 ||
            point.dy < 0 ||
            point.dy > 1) {
          throw const FormatException('Invalid kana drawing point');
        }
      }
    }
  }

  Map<String, Object?> toJson() => {
        'mode': mode.name,
        'letters': letters.map((letter) => letter.reviewId).toList(),
        'index': index,
        'step': step.name,
        'showExample': showExample,
        'selectedIndex': selectedIndex,
        'strokes': [
          for (final stroke in strokes)
            [
              for (final point in stroke) [point.dx, point.dy]
            ]
        ],
      };

  static KanaWritingSession fromJson(
      Map<String, Object?> json, KanaWritingScope scope) {
    final ids = json['letters'];
    final index = json['index'];
    final selected = json['selectedIndex'];
    final showExample = json['showExample'];
    final rawStrokes = json['strokes'];
    if (ids is! List ||
        ids.length > 84 ||
        index is! int ||
        (selected != null && selected is! int) ||
        showExample is! bool ||
        rawStrokes is! List ||
        rawStrokes.length > 32) {
      throw const FormatException('Invalid kana writing session');
    }
    final allowed = scope.hiragana
        ? HiraganaPilotLetter.values.cast<KanaPracticeLetter>()
        : KatakanaPilotLetter.values.cast<KanaPracticeLetter>();
    final byId = {for (final letter in allowed) letter.reviewId: letter};
    final letters = <KanaPracticeLetter>[];
    for (final id in ids) {
      if (id is! String || byId[id] == null) {
        throw const FormatException('Unknown kana writing letter');
      }
      letters.add(byId[id]!);
    }
    final strokes = <List<Offset>>[];
    for (final stroke in rawStrokes) {
      if (stroke is! List || stroke.length < 2 || stroke.length > 1024) {
        throw const FormatException('Invalid kana drawing stroke');
      }
      final points = <Offset>[];
      for (final point in stroke) {
        if (point is! List ||
            point.length != 2 ||
            point[0] is! num ||
            point[1] is! num) {
          throw const FormatException('Invalid kana drawing point');
        }
        points.add(
            Offset((point[0] as num).toDouble(), (point[1] as num).toDouble()));
      }
      strokes.add(points);
    }
    final KanaWritingMode mode;
    final KanaWritingStep step;
    try {
      mode = KanaWritingMode.values.byName(json['mode'] as String);
      step = KanaWritingStep.values.byName(json['step'] as String);
    } catch (_) {
      throw const FormatException('Unknown kana writing step');
    }
    final session = KanaWritingSession(
        letters: letters,
        index: index,
        step: step,
        mode: mode,
        showExample: showExample,
        selectedIndex: selected as int?,
        strokes: strokes);
    session.validate(scope);
    return session;
  }
}

class KanaWritingProgress {
  KanaWritingProgress({
    required this.scope,
    Set<KanaPracticeRow> completedBasicRows = const {},
    this.session,
  }) : completedBasicRows = Set.unmodifiable(completedBasicRows);

  final KanaWritingScope scope;
  final Set<KanaPracticeRow> completedBasicRows;
  final KanaWritingSession? session;

  static Iterable<KanaPracticeRow> get basicRows => KanaPracticeRow.values
      .where((row) => row.section == KanaPracticeSection.basic);

  KanaPracticeRow? get recommendedRow {
    for (final row in basicRows) {
      if (!completedBasicRows.contains(row)) return row;
    }
    return null;
  }

  int get completedBasicCount => completedBasicRows.fold(
      0, (count, row) => count + row.letters(hiragana: scope.hiragana).length);

  void validate() {
    if (scope.owner.isEmpty ||
        !completedBasicRows
            .every((row) => row.section == KanaPracticeSection.basic)) {
      throw const FormatException('Invalid kana writing progress');
    }
    session?.validate(scope);
  }

  String encode() {
    validate();
    final value = jsonEncode({
      'version': 1,
      'owner': scope.owner,
      'script': scope.script,
      'completedBasicRows': [
        for (final row in basicRows)
          if (completedBasicRows.contains(row)) row.name,
      ],
      'session': session?.toJson(),
    });
    if (value.length > 2 * 1024 * 1024) {
      throw const FormatException('Kana drawing is too large');
    }
    return value;
  }

  static KanaWritingProgress decode(String raw, KanaWritingScope scope) {
    if (raw.length > 2 * 1024 * 1024) {
      throw const FormatException('Kana drawing is too large');
    }
    final Object? value = jsonDecode(raw);
    if (value is! Map<String, Object?> ||
        value['version'] != 1 ||
        value['owner'] != scope.owner ||
        value['script'] != scope.script ||
        value['completedBasicRows'] is! List) {
      throw const FormatException('Unknown kana writing document');
    }
    final completed = <KanaPracticeRow>{};
    for (final name in value['completedBasicRows'] as List) {
      if (name is! String) {
        throw const FormatException('Invalid kana writing row');
      }
      final KanaPracticeRow row;
      try {
        row = KanaPracticeRow.values.byName(name);
      } catch (_) {
        throw const FormatException('Unknown kana writing row');
      }
      if (!completed.add(row)) {
        throw const FormatException('Duplicate kana writing row');
      }
    }
    final savedSession = value['session'];
    if (savedSession != null && savedSession is! Map<String, Object?>) {
      throw const FormatException('Invalid kana writing session');
    }
    final result = KanaWritingProgress(
      scope: scope,
      completedBasicRows: completed,
      session: savedSession == null
          ? null
          : KanaWritingSession.fromJson(
              savedSession as Map<String, Object?>, scope),
    );
    result.validate();
    return result;
  }
}
