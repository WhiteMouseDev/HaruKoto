import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/sizes.dart';
import '../../domain/katakana_pilot.dart';
import '../../domain/katakana_textbook_example.dart';

class KatakanaStrokeComparison extends StatefulWidget {
  const KatakanaStrokeComparison({
    super.key,
    required this.letter,
    this.showComparison = true,
  });

  final KanaPracticeLetter letter;
  final bool showComparison;

  @override
  State<KatakanaStrokeComparison> createState() =>
      _KatakanaStrokeComparisonState();
}

class _KatakanaStrokeComparisonState extends State<KatakanaStrokeComparison>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
    value: 1,
  );

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final letter = widget.letter;
    final letters = widget.showComparison && letter is KatakanaPilotLetter
        ? letter.comparisonLetters
        : [letter];
    final showCuesBelow = letters.length > 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (index, letter) in letters.indexed) ...[
              if (index > 0) const SizedBox(width: AppSizes.sm),
              Expanded(
                child: _diagram(letter, theme, showCue: !showCuesBelow),
              ),
            ],
          ],
        ),
        if (showCuesBelow)
          for (final letter in letters)
            Padding(
              padding: const EdgeInsets.only(top: AppSizes.sm),
              child: Text(
                '${letter.glyph}  ${letter.cue}',
                style: theme.textTheme.bodyMedium,
              ),
            ),
        const SizedBox(height: AppSizes.sm),
        OutlinedButton.icon(
          onPressed: () {
            _animation.forward(from: 0);
          },
          icon: const Icon(Icons.replay),
          label: const Text('획순 재생'),
        ),
      ],
    );
  }

  Widget _diagram(
    KanaPracticeLetter letter,
    ThemeData theme, {
    required bool showCue,
  }) {
    final colors = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(showCue ? AppSizes.gap : AppSizes.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${letter.glyph} · ${letter.reading}',
              locale: const Locale('ja'),
              style: theme.textTheme.titleLarge,
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 144),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: CustomPaint(
                    painter: _StrokeDiagramPainter(
                      letter: letter,
                      colors: colors,
                      animation: _animation,
                    ),
                  ),
                ),
              ),
            ),
            if (showCue && letter.cue.isNotEmpty)
              Text(letter.cue, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class KatakanaRecallPad extends StatefulWidget {
  const KatakanaRecallPad({
    super.key,
    required this.onInkChanged,
    this.example,
    this.initialStrokes = const [],
    this.onStrokesChanged,
    this.enabled = true,
  });

  final List<List<Offset>> initialStrokes;
  final ValueChanged<List<List<Offset>>>? onStrokesChanged;
  final bool enabled;
  final ValueChanged<bool> onInkChanged;
  final KanaPracticeLetter? example;

  @override
  State<KatakanaRecallPad> createState() => _KatakanaRecallPadState();
}

class _KatakanaRecallPadState extends State<KatakanaRecallPad>
    with WidgetsBindingObserver {
  final _strokes = <List<Offset>>[];
  final _redraw = ValueNotifier(0);
  List<Offset>? _active;
  int? _pointer;
  double _travel = 0;

  @override
  void initState() {
    super.initState();
    _strokes.addAll(widget.initialStrokes.map((stroke) => [...stroke]));
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant KatakanaRecallPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _cancelStroke();
  }

  void _notifyStrokes() => widget.onStrokesChanged?.call(
        List.unmodifiable(
            _strokes.map((stroke) => List<Offset>.unmodifiable(stroke))),
      );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _cancelStroke();
  }

  @override
  void didChangeMetrics() => _cancelStroke();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _redraw.dispose();
    super.dispose();
  }

  Offset _normalized(Offset point, double side) =>
      Offset(point.dx / side, point.dy / side);

  void _begin(PointerDownEvent event, double side) {
    if (!widget.enabled || _pointer != null || widget.example != null) return;
    _pointer = event.pointer;
    _active = [_normalized(event.localPosition, side)];
    _travel = 0;
    _redraw.value++;
  }

  void _move(PointerMoveEvent event, double side) {
    if (event.pointer != _pointer) return;
    final point = event.localPosition;
    if (!(Offset.zero & Size.square(side)).contains(point)) {
      _cancelStroke();
      return;
    }

    final normalized = _normalized(point, side);
    final active = _active!;
    final step = (normalized - active.last).distance;
    // Ignore sub-pixel movement and bound retained samples for a single stroke.
    if (step < 0.002 || active.length >= 1024) return;
    _travel += step;
    active.add(normalized);
    _redraw.value++;
  }

  void _finish(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    final wasEmpty = _strokes.isEmpty;
    var added = false;
    // A tap or slight jitter should not count as a written stroke.
    if (_travel >= 0.025 && _strokes.length < 32) {
      setState(() => _strokes.add(_active!));
      added = true;
    }
    _cancelStroke();
    if (wasEmpty && _strokes.isNotEmpty) widget.onInkChanged(true);
    if (added) _notifyStrokes();
  }

  void _cancelStroke() {
    if (_pointer == null) return;
    _pointer = null;
    _active = null;
    _redraw.value++;
  }

  void _editInk({required bool clear}) {
    _cancelStroke();
    setState(() {
      if (clear) {
        _strokes.clear();
      } else {
        _strokes.removeLast();
      }
    });
    _redraw.value++;
    widget.onInkChanged(_strokes.isNotEmpty);
    _notifyStrokes();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final showExample = widget.example != null;
    return Column(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 288),
          child: AspectRatio(
            aspectRatio: 1,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final side = constraints.maxWidth;
                return Semantics(
                  label: showExample ? '예시와 내 글씨 비교' : '손글씨 입력 영역',
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerLowest,
                      border: Border.all(color: colors.outline),
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      child: RawGestureDetector(
                        // Keep a vertical stroke on the pad rather than handing
                        // it to the page's ListView as a scroll gesture.
                        gestures: showExample
                            ? const {}
                            : <Type, GestureRecognizerFactory>{
                                EagerGestureRecognizer:
                                    GestureRecognizerFactoryWithHandlers<
                                        EagerGestureRecognizer>(
                                  EagerGestureRecognizer.new,
                                  (_) {},
                                ),
                              },
                        child: Listener(
                          key: const ValueKey('katakana-recall-canvas'),
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: (event) => _begin(event, side),
                          onPointerMove: (event) => _move(event, side),
                          onPointerUp: _finish,
                          onPointerCancel: (event) {
                            if (event.pointer == _pointer) _cancelStroke();
                          },
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: _RecallPainter(
                                colors: colors,
                                strokes: _strokes,
                                activeStroke: () => _active,
                                example: widget.example,
                                redraw: _redraw,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (!showExample)
          Wrap(
            spacing: AppSizes.sm,
            alignment: WrapAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _strokes.isEmpty || !widget.enabled
                    ? null
                    : () => _editInk(clear: false),
                icon: const Icon(Icons.undo),
                label: const Text('한 획 지우기'),
              ),
              TextButton.icon(
                onPressed: _strokes.isEmpty || !widget.enabled
                    ? null
                    : () => _editInk(clear: true),
                icon: const Icon(Icons.refresh),
                label: const Text('모두 지우기'),
              ),
            ],
          ),
      ],
    );
  }
}

Offset _scaled(Offset point, Size size) =>
    Offset(point.dx * size.width, point.dy * size.height);

void _scaleTextbookExample(Canvas canvas, Size size) {
  const inset = KatakanaTextbookExample.inset;
  const scale =
      KatakanaTextbookExample.fit / KatakanaTextbookExample.viewBoxSize;
  canvas
    ..translate(size.width * inset, size.height * inset)
    ..scale(size.width * scale, size.height * scale);
}

Path _inkPath(List<Offset> points, Size size) {
  final first = _scaled(points.first, size);
  final path = Path()..moveTo(first.dx, first.dy);
  for (final point in points.skip(1)) {
    final scaled = _scaled(point, size);
    path.lineTo(scaled.dx, scaled.dy);
  }
  return path;
}

Path _guidePath(List<Offset> points, Size size) {
  final start = _scaled(points.first, size);
  final path = Path()..moveTo(start.dx, start.dy);
  for (var index = 1; index < points.length - 1; index++) {
    final previous = points[index - 1];
    final point = points[index];
    final next = points[index + 1];
    final incoming = point - previous;
    final outgoing = next - point;
    final dot = incoming.dx * outgoing.dx + incoming.dy * outgoing.dy;
    final control = _scaled(point, size);

    // Round small changes of direction in sampled curves. Keep turns of
    // 60° or more as corners, such as the upper right bend of ア.
    if (dot <= incoming.distance * outgoing.distance * 0.5) {
      path.lineTo(control.dx, control.dy);
      continue;
    }

    final entry = _scaled((previous + point) / 2, size);
    final exit = _scaled((point + next) / 2, size);
    path
      ..lineTo(entry.dx, entry.dy)
      ..quadraticBezierTo(control.dx, control.dy, exit.dx, exit.dy);
  }
  final end = _scaled(points.last, size);
  return path..lineTo(end.dx, end.dy);
}

Paint _ink(Color color, double width) => Paint()
  ..color = color
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..strokeWidth = width
  ..style = PaintingStyle.stroke;

class _StrokeDiagramPainter extends CustomPainter {
  _StrokeDiagramPainter({
    required this.letter,
    required this.colors,
    required this.animation,
  })  : _textbook = kanaTextbookExample(letter.glyph),
        super(repaint: animation);

  final KanaPracticeLetter letter;
  final ColorScheme colors;
  final Animation<double> animation;
  final KatakanaTextbookExample? _textbook;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.shortestSide * 0.036;
    final textbook = _textbook;
    final practiceLetter = letter;
    final fallback =
        practiceLetter is KatakanaPilotLetter ? practiceLetter : null;
    if (textbook != null) {
      _paintTextbookStrokes(canvas, size, textbook);
    } else if (fallback != null) {
      final preview =
          _ink(colors.onSurface.withValues(alpha: 0.14), strokeWidth);
      final ink = _ink(colors.onSurface, strokeWidth);
      for (final (index, points) in fallback.strokes.indexed) {
        final path = _guidePath(points, size);
        final progress = _strokeProgress(index, fallback.strokes.length);
        if (progress < 1) canvas.drawPath(path, preview);
        if (progress == 1) {
          canvas.drawPath(path, ink);
        } else if (progress > 0) {
          final metric = path.computeMetrics().first;
          canvas.drawPath(metric.extractPath(0, metric.length * progress), ink);
        }
      }
    }

    final radius = (size.shortestSide * 0.048).clamp(4.5, 7.0);
    final leader = Paint()
      ..color = colors.onSurface.withValues(alpha: 0.36)
      ..strokeWidth = 1;
    final badgeFill = Paint()..color = colors.surfaceContainerLowest;
    final badgeOutline = Paint()
      ..color = colors.onSurface.withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final startInk = Paint()..color = colors.primary;
    final strokeCount =
        textbook?.strokes.length ?? fallback?.strokes.length ?? 0;
    for (var index = 0; index < strokeCount; index++) {
      final textbookStroke = textbook?.strokes[index];
      final start = _scaled(
        textbookStroke == null
            ? fallback!.strokes[index].first
            : KatakanaTextbookExample.unitPosition(textbookStroke.start),
        size,
      );
      final numberPosition = _scaled(
        textbookStroke == null
            ? fallback!.strokeNumberPositions[index]
            : KatakanaTextbookExample.unitPosition(
                textbookStroke.numberPosition),
        size,
      );
      canvas.drawLine(start, numberPosition, leader);
      canvas.drawCircle(start, (strokeWidth * 0.32).clamp(1.0, 1.8), startInk);
      canvas.drawCircle(numberPosition, radius, badgeFill);
      canvas.drawCircle(numberPosition, radius, badgeOutline);
      final number = TextPainter(
        text: TextSpan(
          text: '${index + 1}',
          style: TextStyle(
            color: colors.onSurface,
            fontSize: radius * 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      number.paint(
        canvas,
        numberPosition - Offset(number.width / 2, number.height / 2),
      );
      number.dispose();
    }
  }

  double _strokeProgress(int index, int strokeCount) =>
      (animation.value * strokeCount - index).clamp(0.0, 1.0);

  void _paintTextbookStrokes(
    Canvas canvas,
    Size size,
    KatakanaTextbookExample textbook,
  ) {
    final fill = Paint()..color = colors.onSurface;
    canvas.save();
    _scaleTextbookExample(canvas, size);
    if (animation.isCompleted) {
      canvas.drawPath(textbook.silhouette, fill);
      canvas.restore();
      return;
    }

    final preview = Paint()..color = colors.onSurface.withValues(alpha: 0.14);
    final brush =
        _ink(colors.onSurface, KatakanaTextbookExample.replayBrushWidth);
    canvas.drawPath(textbook.silhouette, preview);
    for (final (index, stroke) in textbook.strokes.indexed) {
      final progress = _strokeProgress(index, textbook.strokes.length);
      if (progress == 1) {
        canvas.drawPath(stroke.outline, fill);
      } else if (progress > 0) {
        for (final part in stroke.parts) {
          final replay = part.replay;
          canvas.save();
          canvas.clipPath(part.outline);
          canvas.drawPath(
              replay.extractPath(0, replay.length * progress), brush);
          canvas.restore();
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StrokeDiagramPainter oldDelegate) =>
      oldDelegate.letter != letter ||
      oldDelegate.colors != colors ||
      oldDelegate.animation != animation;
}

class _RecallPainter extends CustomPainter {
  _RecallPainter({
    required this.colors,
    required this.strokes,
    required this.activeStroke,
    required this.example,
    required this.redraw,
  })  : _textbookSilhouette = example == null
            ? null
            : kanaTextbookExample(example.glyph)?.silhouette,
        super(repaint: redraw);

  final ColorScheme colors;
  final List<List<Offset>> strokes;
  final List<Offset>? Function() activeStroke;
  final KanaPracticeLetter? example;
  final Listenable redraw;
  final Path? _textbookSilhouette;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final guide = Paint()..color = colors.outline.withValues(alpha: 0.65);
    canvas.drawLine(
        Offset(center.dx, 0), Offset(center.dx, size.height), guide);
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), guide);
    final width = size.shortestSide * 0.022;
    final sampleColor = colors.primary.withValues(alpha: 0.62);
    final silhouette = _textbookSilhouette;
    if (silhouette != null) {
      canvas.save();
      _scaleTextbookExample(canvas, size);
      canvas.drawPath(silhouette, Paint()..color = sampleColor);
      canvas.restore();
    } else if (example case final KatakanaPilotLetter letter) {
      final sampleInk = _ink(sampleColor, width * 1.25);
      for (final stroke in letter.strokes) {
        canvas.drawPath(_guidePath(stroke, size), sampleInk);
      }
    }
    final userInk = _ink(colors.onSurface, width);
    for (final stroke in strokes) {
      canvas.drawPath(_inkPath(stroke, size), userInk);
    }
    final active = activeStroke();
    if (active != null) canvas.drawPath(_inkPath(active, size), userInk);
  }

  @override
  bool shouldRepaint(_RecallPainter oldDelegate) =>
      oldDelegate.colors != colors ||
      oldDelegate.strokes != strokes ||
      oldDelegate.example != example;
}
