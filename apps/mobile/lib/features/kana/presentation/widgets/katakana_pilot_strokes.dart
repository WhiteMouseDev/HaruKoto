import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/sizes.dart';
import '../../domain/katakana_pilot.dart';

class KatakanaStrokeComparison extends StatefulWidget {
  const KatakanaStrokeComparison({super.key, required this.letter});

  final KatakanaPilotLetter letter;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _diagram(widget.letter, theme)),
            const SizedBox(width: AppSizes.sm),
            Expanded(child: _diagram(widget.letter.contrast, theme)),
          ],
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

  Widget _diagram(KatakanaPilotLetter letter, ThemeData theme) {
    final colors = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.gap),
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
                      paths: letter.strokes,
                      colors: colors,
                      animation: _animation,
                    ),
                  ),
                ),
              ),
            ),
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
  });

  final ValueChanged<bool> onInkChanged;
  final List<List<Offset>>? example;

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
    WidgetsBinding.instance.addObserver(this);
  }

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
    if (_pointer != null || widget.example != null) return;
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
    // A tap or slight jitter should not count as a written stroke.
    if (_travel >= 0.025 && _strokes.length < 32) {
      setState(() => _strokes.add(_active!));
    }
    _cancelStroke();
    if (wasEmpty && _strokes.isNotEmpty) widget.onInkChanged(true);
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
                onPressed:
                    _strokes.isEmpty ? null : () => _editInk(clear: false),
                icon: const Icon(Icons.undo),
                label: const Text('한 획 지우기'),
              ),
              TextButton.icon(
                onPressed:
                    _strokes.isEmpty ? null : () => _editInk(clear: true),
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

Path _path(List<Offset> points, Size size) {
  final first = _scaled(points.first, size);
  final path = Path()..moveTo(first.dx, first.dy);
  for (final point in points.skip(1)) {
    final scaled = _scaled(point, size);
    path.lineTo(scaled.dx, scaled.dy);
  }
  return path;
}

Paint _ink(Color color, double width) => Paint()
  ..color = color
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..strokeWidth = width
  ..style = PaintingStyle.stroke;

class _StrokeDiagramPainter extends CustomPainter {
  _StrokeDiagramPainter({
    required this.paths,
    required this.colors,
    required this.animation,
  }) : super(repaint: animation);

  final List<List<Offset>> paths;
  final ColorScheme colors;
  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.shortestSide * 0.047;
    final preview = _ink(colors.onSurface.withValues(alpha: 0.14), strokeWidth);
    final ink = _ink(colors.onSurface, strokeWidth);
    for (final (index, points) in paths.indexed) {
      final path = _path(points, size);
      final progress = (animation.value * paths.length - index).clamp(0.0, 1.0);
      if (progress < 1) canvas.drawPath(path, preview);
      if (progress == 1) {
        canvas.drawPath(path, ink);
      } else if (progress > 0) {
        final metric = path.computeMetrics().first;
        canvas.drawPath(metric.extractPath(0, metric.length * progress), ink);
      }
    }

    final radius = (size.shortestSide * 0.059).clamp(4.0, 9.0);
    for (final (index, points) in paths.indexed) {
      final start = _scaled(points.first, size);
      canvas.drawCircle(start, radius, Paint()..color = colors.onSurface);
      final number = TextPainter(
        text: TextSpan(
          text: '${index + 1}',
          style: TextStyle(
            color: colors.surface,
            fontSize: radius * 1.45,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      number.paint(
        canvas,
        start - Offset(number.width / 2, number.height / 2),
      );
      number.dispose();
    }
  }

  @override
  bool shouldRepaint(_StrokeDiagramPainter oldDelegate) =>
      oldDelegate.paths != paths ||
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
  }) : super(repaint: redraw);

  final ColorScheme colors;
  final List<List<Offset>> strokes;
  final List<Offset>? Function() activeStroke;
  final List<List<Offset>>? example;
  final Listenable redraw;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final guide = Paint()..color = colors.outline;
    canvas.drawLine(
        Offset(center.dx, 0), Offset(center.dx, size.height), guide);
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), guide);
    final width = size.shortestSide * 0.022;
    final sampleInk = _ink(colors.primary.withValues(alpha: 0.66), width * 1.8);
    for (final stroke in example ?? const <List<Offset>>[]) {
      canvas.drawPath(_path(stroke, size), sampleInk);
    }
    final userInk = _ink(colors.onSurface, width);
    for (final stroke in strokes) {
      canvas.drawPath(_path(stroke, size), userInk);
    }
    final active = activeStroke();
    if (active != null) canvas.drawPath(_path(active, size), userInk);
  }

  @override
  bool shouldRepaint(_RecallPainter oldDelegate) =>
      oldDelegate.colors != colors ||
      oldDelegate.strokes != strokes ||
      oldDelegate.example != example;
}
