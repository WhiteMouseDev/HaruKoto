import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/theme/text_theme.dart';
import 'quiz_result_wrong_icon.dart';

class ResultScoreDisplay extends StatefulWidget {
  final int accuracy;
  final int correct;
  final int total;
  final int xpEarned;
  final int currentXp;
  final int xpForNext;
  final bool rewardConfirmed;
  final bool redesigned;

  const ResultScoreDisplay({
    super.key,
    required this.accuracy,
    required this.correct,
    required this.total,
    required this.xpEarned,
    required this.currentXp,
    required this.xpForNext,
    this.rewardConfirmed = true,
    this.redesigned = false,
  });

  @override
  State<ResultScoreDisplay> createState() => _ResultScoreDisplayState();
}

class _ResultScoreDisplayState extends State<ResultScoreDisplay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (!_started) {
      _controller.forward();
    }
    _started = true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.redesigned) {
      return _RedesignedScore(result: widget, animation: _controller);
    }
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final subtext = isLight ? AppColors.lightSubtext : AppColors.darkSubtext;
    final scaler = MediaQuery.textScalerOf(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isLight
            ? AppColors.cardWarm
            : theme.colorScheme.surfaceContainerLow,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(24),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final values = [
          '${widget.correct}/${widget.total}',
          if (widget.rewardConfirmed) '+${widget.xpEarned}' else '확인됨',
          '${widget.total - widget.correct}',
        ];
        final valueStyle = theme.textTheme.titleLarge
            ?.copyWith(fontSize: 22, height: 1.2, fontWeight: FontWeight.w700);
        final availableTileWidth = (constraints.maxWidth - 16) / 3 - 16;
        final valuesFit = values.every((value) {
          final painter = TextPainter(
            text: TextSpan(text: value, style: valueStyle),
            textDirection: Directionality.of(context),
            textScaler: scaler,
          )..layout();
          final fits = painter.width <= availableTileWidth;
          painter.dispose();
          return fits;
        });
        final stacked =
            constraints.maxWidth < 260 || scaler.scale(1) > 1.35 || !valuesFit;
        var stackedTileHeight = 0.0;
        if (stacked) {
          for (var index = 0; index < values.length; index++) {
            final valuePainter = TextPainter(
              text: TextSpan(text: values[index], style: valueStyle),
              textDirection: Directionality.of(context),
              textScaler: scaler,
            )..layout(maxWidth: max(1, constraints.maxWidth - 64));
            final labelPainter = TextPainter(
              text: TextSpan(
                text: [
                  '정답',
                  if (widget.rewardConfirmed) '획득 XP' else '결과 저장',
                  '오답'
                ][index],
                style: theme.textTheme.labelMedium
                    ?.copyWith(fontSize: 12, height: 1.3),
              ),
              textDirection: Directionality.of(context),
              textScaler: scaler,
            )..layout(maxWidth: max(1, constraints.maxWidth - 64));
            stackedTileHeight = max(stackedTileHeight,
                valuePainter.height + labelPainter.height + 36);
            valuePainter.dispose();
            labelPainter.dispose();
          }
        }
        final circleSize =
            min(constraints.maxWidth, max(120.0, scaler.scale(80)));
        final tiles = [
          _StatTile(
            key: const ValueKey('result-stat-correct'),
            icon: LucideIcons.target,
            iconColor: AppColors.primary,
            value: values[0],
            label: '정답',
            horizontal: stacked,
            minimumHeight: stackedTileHeight,
          ),
          _StatTile(
            key: const ValueKey('result-stat-xp'),
            icon: LucideIcons.zap,
            iconColor: AppColors.primary,
            value: values[1],
            label: widget.rewardConfirmed ? '획득 XP' : '결과 저장',
            horizontal: stacked,
            minimumHeight: stackedTileHeight,
          ),
          _StatTile(
            key: const ValueKey('result-stat-wrong'),
            icon: LucideIcons.xCircle,
            iconColor: widget.total == widget.correct
                ? subtext
                : AppColors.error(theme.brightness),
            value: values[2],
            label: '오답',
            horizontal: stacked,
            minimumHeight: stackedTileHeight,
          ),
        ];

        return Column(
          children: [
            Semantics(
              label: '정답률 ${widget.accuracy}퍼센트',
              excludeSemantics: true,
              child: SizedBox(
                width: circleSize,
                height: circleSize,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => CustomPaint(
                    painter: _AccuracyCirclePainter(
                      progress: _controller.value * widget.accuracy / 100,
                      bgColor: theme.colorScheme.surfaceContainerHigh,
                      fgColor: AppColors.primary,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(_controller.value * widget.accuracy).round()}%',
                            style: theme.textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text('정답률',
                              style: theme.textTheme.labelMedium
                                  ?.copyWith(color: subtext)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (stacked)
              Column(children: [
                for (var index = 0; index < tiles.length; index++) ...[
                  if (index > 0) const SizedBox(height: 8),
                  tiles[index],
                ],
              ])
            else
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < tiles.length; index++) ...[
                      if (index > 0) const SizedBox(width: 8),
                      Expanded(child: tiles[index]),
                    ],
                  ],
                ),
              ),
            if (widget.xpForNext > 0) ...[
              const SizedBox(height: 20),
              Divider(height: 1, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '다음 레벨까지 ${max(0, widget.xpForNext - widget.currentXp)} XP',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontSize: 13, height: 1.4, color: subtext),
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (widget.currentXp / widget.xpForNext).clamp(0, 1),
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.surfaceContainerHigh,
                  color: AppColors.primary,
                  semanticsLabel:
                      '레벨 경험치 ${widget.currentXp} / ${widget.xpForNext} XP',
                ),
              ),
            ],
          ],
        );
      }),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.horizontal,
    required this.minimumHeight,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final bool horizontal;
  final double minimumHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtext = theme.brightness == Brightness.light
        ? AppColors.lightSubtext
        : AppColors.darkSubtext;
    final valueText = Text(value,
        style: theme.textTheme.titleLarge
            ?.copyWith(fontSize: 22, height: 1.2, fontWeight: FontWeight.w700));
    final labelText = Text(label,
        style: theme.textTheme.labelMedium
            ?.copyWith(fontSize: 12, height: 1.3, color: subtext));

    return Semantics(
      label: '$label $value',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: minimumHeight),
        padding:
            EdgeInsets.symmetric(horizontal: horizontal ? 16 : 8, vertical: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: horizontal
            ? Row(
                children: [
                  Icon(icon, size: 20, color: iconColor),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [labelText, const SizedBox(height: 4), valueText],
                  )),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: iconColor),
                  const SizedBox(height: 10),
                  valueText,
                  const SizedBox(height: 6),
                  labelText,
                ],
              ),
      ),
    );
  }
}

class _AccuracyCirclePainter extends CustomPainter {
  final double progress;
  final Color bgColor;
  final Color fgColor;
  final double inset;

  _AccuracyCirclePainter(
      {required this.progress,
      required this.bgColor,
      required this.fgColor,
      this.inset = 8});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = max(0.0, size.width / 2 - inset);
    const strokeWidth = 8.0;
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = bgColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth);
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * progress,
        false,
        Paint()
          ..color = fgColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_AccuracyCirclePainter old) =>
      old.progress != progress ||
      old.bgColor != bgColor ||
      old.fgColor != fgColor ||
      old.inset != inset;
}

class _RedesignedScore extends StatelessWidget {
  const _RedesignedScore({required this.result, required this.animation});

  final ResultScoreDisplay result;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final foreground =
        light ? AppColors.redesignForeground : theme.colorScheme.onSurface;
    final muted = light
        ? AppColors.redesignMutedForeground
        : theme.colorScheme.onSurfaceVariant;
    final pink = light ? AppColors.brandPink : theme.colorScheme.primary;
    final accentTrack = light
        ? AppColors.redesignControl
        : theme.colorScheme.surfaceContainerHighest;
    final outline =
        light ? AppColors.redesignOutline : theme.colorScheme.outline;
    final labelStyle = TextStyle(
      fontFamily: redesignFontFamily,
      fontSize: 12,
      height: 1.4,
      color: muted,
    );
    final valueStyle = labelStyle.copyWith(
      fontSize: 18,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: foreground,
    );
    final format = MaterialLocalizations.of(context).formatDecimal;
    final expectedAccuracy = result.accuracy.clamp(0, 100);
    final percentageStyle = valueStyle.copyWith(fontSize: 32, height: 1.25);
    final tiles = [
      (
        'correct',
        '${format(result.correct)}개',
        '정답',
        Icons.check_circle,
        AppColors.quizCorrectButton,
      ),
      (
        'wrong',
        '${format(result.total - result.correct)}개',
        '오답',
        Icons.cancel,
        AppColors.brandPink,
      ),
      (
        'xp',
        result.rewardConfirmed ? format(result.xpEarned) : '확인됨',
        result.rewardConfirmed ? '획득 XP' : '결과 저장',
        Icons.bolt,
        AppColors.amber,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final fontScale = MediaQuery.textScalerOf(context);
        final percentagePainter = TextPainter(
          text: TextSpan(text: '$expectedAccuracy%', style: percentageStyle),
          textDirection: Directionality.of(context),
          textScaler: fontScale,
          maxLines: 1,
        )..layout();
        final circleSize = min(
          constraints.maxWidth,
          max(128.0, percentagePainter.width + 24),
        );
        percentagePainter.dispose();
        final tileWidth = (constraints.maxWidth - 2) / 3 - 12;
        final stackTiles = tiles.any((tile) {
          final painter = TextPainter(
            text: TextSpan(text: tile.$2, style: valueStyle),
            textDirection: Directionality.of(context),
            textScaler: fontScale,
            maxLines: 1,
          )..layout();
          final fits = painter.width <= tileWidth;
          painter.dispose();
          return !fits;
        });
        final cells = [
          for (final (name, value, label, fallbackIcon, fallbackColor) in tiles)
            Semantics(
              key: ValueKey('result-stat-$name'),
              excludeSemantics: true,
              label: '$label $value',
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox.square(
                      dimension: 24,
                      child: name == 'wrong'
                          ? const QuizResultWrongIcon(size: 24)
                          : Center(
                              child: Image.asset(
                                'assets/icons/figma-quiz-result-$name.png',
                                width: name == 'xp' ? 13 : 24,
                                height: name == 'xp' ? 18 : 24,
                                excludeFromSemantics: true,
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(
                                  fallbackIcon,
                                  color: fallbackColor,
                                  size: 24,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 6),
                    Text(value, style: valueStyle, textAlign: TextAlign.center),
                    Text(label, style: labelStyle, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
        ];

        return Column(
          children: [
            Semantics(
              label: '정답률 $expectedAccuracy퍼센트',
              excludeSemantics: true,
              child: SizedBox.square(
                dimension: circleSize,
                child: AnimatedBuilder(
                  animation: animation,
                  builder: (context, _) => CustomPaint(
                    painter: _AccuracyCirclePainter(
                      progress: animation.value * expectedAccuracy / 100,
                      bgColor: accentTrack,
                      fgColor: light ? AppColors.redesignVocabulary : pink,
                      inset: 4,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '정답률',
                              style: labelStyle.copyWith(
                                  color: pink, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${(animation.value * expectedAccuracy).round()}%',
                              style: percentageStyle,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            DecoratedBox(
              decoration: BoxDecoration(
                color: light
                    ? AppColors.redesignSurface
                    : theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: stackTiles
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var index = 0; index < cells.length; index++) ...[
                          if (index > 0) Divider(height: 1, color: outline),
                          cells[index],
                        ],
                      ],
                    )
                  : IntrinsicHeight(
                      child: Row(
                        children: [
                          for (var index = 0;
                              index < cells.length;
                              index++) ...[
                            if (index > 0)
                              VerticalDivider(
                                  width: 1,
                                  indent: 12,
                                  endIndent: 12,
                                  color: outline),
                            Expanded(child: cells[index]),
                          ],
                        ],
                      ),
                    ),
            ),
            if (result.xpForNext > 0) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LinearProgressIndicator(
                      value: (result.currentXp / result.xpForNext).clamp(0, 1),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                      backgroundColor: accentTrack,
                      color: pink,
                      semanticsLabel:
                          '레벨 경험치 ${result.currentXp} / ${result.xpForNext} XP',
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          '다음 레벨까지 ${format(max(0, result.xpForNext - result.currentXp))}XP',
                          style: labelStyle,
                        ),
                        Text(
                          '${format(result.currentXp)}/${format(result.xpForNext)} XP',
                          style: labelStyle,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
