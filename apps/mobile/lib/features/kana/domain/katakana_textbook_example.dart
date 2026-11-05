import 'dart:typed_data';
import 'dart:ui';

part 'kana_hiragana_textbook_paths.dart';
part 'kana_katakana_textbook_paths.dart';

class KatakanaTextbookStrokePart {
  KatakanaTextbookStrokePart({
    required this.outline,
    required Path replayPath,
  }) : replay = replayPath.computeMetrics().single;

  final Path outline;
  final PathMetric replay;
}

class KatakanaTextbookStroke {
  KatakanaTextbookStroke({
    required Path outline,
    required Path replayPath,
    required Offset start,
    required Offset numberPosition,
  }) : this.grouped(
          parts: [
            KatakanaTextbookStrokePart(
                outline: outline, replayPath: replayPath),
          ],
          start: start,
          numberPosition: numberPosition,
        );

  KatakanaTextbookStroke.grouped({
    required this.parts,
    required this.start,
    required this.numberPosition,
  }) : outline = _unionOutlines(parts.map((part) => part.outline));

  final List<KatakanaTextbookStrokePart> parts;
  final Path outline;
  final Offset start;
  final Offset numberPosition;
}

Path _unionOutlines(Iterable<Path> outlines) => outlines.reduce(
      (first, next) => Path.combine(PathOperation.union, first, next),
    );

Path _transformSourcePath(Path path, double scale, Offset translation) =>
    path.transform(Float64List.fromList([
      scale,
      0,
      0,
      0,
      0,
      scale,
      0,
      0,
      0,
      0,
      1,
      0,
      translation.dx,
      translation.dy,
      0,
      1,
    ]));

class KatakanaTextbookExample {
  KatakanaTextbookExample(this.strokes)
      : silhouette = _unionOutlines(strokes.map((stroke) => stroke.outline));

  /// Coordinates and replay brush width from the source SVG viewBox.
  static const viewBoxSize = 1024.0;
  static const replayBrushWidth = 128.0;

  /// Use the same fit as the approved first-row specimen.
  static const fit = 0.88;
  static const inset = (1 - fit) / 2;

  final List<KatakanaTextbookStroke> strokes;
  final Path silhouette;

  static Offset unitPosition(Offset point) =>
      const Offset(inset, inset) + point * (fit / viewBoxSize);
}

final _loadedExamples = <String, KatakanaTextbookExample>{};

KatakanaTextbookExample? kanaTextbookExample(String glyph) {
  final loaded = _loadedExamples[glyph];
  if (loaded != null) return loaded;
  final create = _hiraganaExamples[glyph] ?? _katakanaExamples[glyph];
  if (create == null) return null;
  return _loadedExamples[glyph] = create();
}
