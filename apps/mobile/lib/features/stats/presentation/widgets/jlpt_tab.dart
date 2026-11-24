import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/theme/text_theme.dart';
import '../../../../shared/widgets/app_skeleton.dart';
import '../../data/models/level_progress_model.dart';
import '../../providers/stats_provider.dart';

const _levels = ['N5', 'N4', 'N3', 'N2', 'N1'];
const _levelDescriptions = [
  '기초 일본어',
  '기본적인 일본어',
  '일상적인 일본어',
  '일반적인 일본어',
  '고급 일본어',
];

double _masteryRatio(int mastered, int total) =>
    total > 0 ? (mastered / total).clamp(0.0, 1.0) : 0;

TextStyle _text(double size, {FontWeight weight = FontWeight.w400}) =>
    TextStyle(
      fontFamily: redesignFontFamily,
      fontSize: size,
      fontWeight: weight,
      height: 1.4,
      letterSpacing: size * -0.025,
    );

class JlptTab extends ConsumerStatefulWidget {
  const JlptTab({super.key, required this.currentLevel});

  final String currentLevel;

  @override
  ConsumerState<JlptTab> createState() => _JlptTabState();
}

class _JlptTabState extends ConsumerState<JlptTab> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = math.max(0, _levels.indexOf(widget.currentLevel));
  }

  @override
  void didUpdateWidget(covariant JlptTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentLevel != oldWidget.currentLevel) {
      _selectedIndex = math.max(0, _levels.indexOf(widget.currentLevel));
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(jlptProgressProvider);
    final level = _levels[_selectedIndex];
    final nextLevelIndex = _levels.indexOf(widget.currentLevel) + 1;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final light = theme.brightness == Brightness.light;
    final foreground = light ? AppColors.redesignForeground : colors.onSurface;
    final surface =
        light ? AppColors.redesignSurface : colors.surfaceContainerHigh;

    return DefaultTextStyle.merge(
      style: _text(13).copyWith(color: foreground),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('학습 진도 요약', style: _text(16, weight: FontWeight.w600)),
          const SizedBox(height: AppSizes.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 301),
              child: Row(
                children: [
                  for (var index = 0; index < _levels.length; index++) ...[
                    if (index > 0) const SizedBox(width: AppSizes.xs),
                    Expanded(
                      child: _LevelTab(
                        level: _levels[index],
                        selected: index == _selectedIndex,
                        onPressed: () => setState(() => _selectedIndex = index),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          progress.when(
            data: (response) {
              final selected = response.levels
                  .where((entry) => entry.level == level)
                  .firstOrNull;
              return selected == null
                  ? _StatusCard(
                      color: surface,
                      child: Text('$level 진도 정보가 아직 없어요'),
                    )
                  : _LevelProgress(
                      progress: selected,
                      level: level,
                      description: _levelDescriptions[_selectedIndex],
                    );
            },
            loading: () => Semantics(
              label: '급수별 진도를 불러오는 중',
              container: true,
              child: _LevelProgress(
                level: level,
                description: _levelDescriptions[_selectedIndex],
              ),
            ),
            error: (_, __) => _StatusCard(
              color: surface,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('급수별 진도를 불러오지 못했어요'),
                  TextButton(
                    onPressed: () => ref.invalidate(jlptProgressProvider),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
          ),
          if (nextLevelIndex > 0 && nextLevelIndex < _levels.length) ...[
            SizedBox(
              height:
                  MediaQuery.sizeOf(context).height < 830 ? AppSizes.xl : 40,
            ),
            _NextGoal(
              level: _levels[nextLevelIndex],
              description: _levelDescriptions[nextLevelIndex],
              onPressed: () => context.go('/study'),
            ),
          ],
        ],
      ),
    );
  }
}

class _LevelTab extends StatelessWidget {
  const _LevelTab({
    required this.level,
    required this.selected,
    required this.onPressed,
  });

  final String level;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allowed = theme.colorScheme;
    final light = theme.brightness == Brightness.light;
    final foreground = selected
        ? light
            ? Colors.white
            : AppColors.sakuraOn
        : light
            ? AppColors.redesignForeground
            : allowed.onSurface;
    final background = selected
        ? light
            ? AppColors.redesignStrong
            : allowed.primaryContainer
        : light
            ? AppColors.redesignControl
            : allowed.surfaceContainerHigh;

    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: TextButton(
        key: ValueKey('jlpt-progress-tab-$level'),
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: foreground,
          minimumSize: const Size(0, kMinInteractiveDimension),
          padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
          visualDensity: VisualDensity.standard,
          shape: const StadiumBorder(),
          textStyle: _text(13, weight: FontWeight.w500),
        ),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration:
              ShapeDecoration(color: background, shape: const StadiumBorder()),
          child: Text(level, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 140),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppSizes.gap),
      ),
      padding: const EdgeInsets.all(AppSizes.md),
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _LevelProgress extends StatelessWidget {
  const _LevelProgress({
    this.progress,
    required this.level,
    required this.description,
  });

  final JlptLevelProgress? progress;
  final String level;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final light = theme.brightness == Brightness.light;
    final muted =
        light ? AppColors.redesignMutedForeground : colors.onSurfaceVariant;
    final formatCount = MaterialLocalizations.of(context).formatDecimal;
    final brand = colors.primary;
    final progress = this.progress;
    final vocabulary = progress?.vocabulary;
    final grammar = progress?.grammar;
    final total = (vocabulary?.total ?? 0) + (grammar?.total ?? 0);
    final mastered = (vocabulary?.mastered ?? 0) + (grammar?.mastered ?? 0);
    final textScale = MediaQuery.textScalerOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          key: const ValueKey('jlpt-progress-summary'),
          decoration: BoxDecoration(
            color:
                light ? AppColors.redesignSurface : colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppSizes.gap),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSizes.xs,
                  children: [
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: level, style: TextStyle(color: brand)),
                        const TextSpan(text: ' 난이도'),
                      ]),
                      style: _text(18, weight: FontWeight.w700),
                    ),
                    Text(description, style: TextStyle(color: muted)),
                  ],
                ),
                const SizedBox(height: AppSizes.sm),
                _OverallProgress(
                  ratio:
                      progress == null ? null : _masteryRatio(mastered, total),
                  color: brand,
                  track: light
                      ? AppColors.redesignProgressTrack
                      : colors.surfaceContainerLowest,
                ),
                const SizedBox(height: AppSizes.xs),
                if (progress == null)
                  SizedBox(
                    height: textScale.scale(13) * 1.4,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AppSkeletonBlock(width: 26, height: 11),
                        AppSkeletonBlock(width: 30, height: 11),
                      ],
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(child: Text('${formatCount(mastered)}개')),
                      const SizedBox(width: AppSizes.sm),
                      Flexible(
                        child: Text(
                          '${formatCount(total)}개',
                          textAlign: TextAlign.end,
                          style: TextStyle(color: muted),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSizes.gap),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
          child: Column(
            children: [
              _CategoryProgress(
                title: '단어',
                category: vocabulary,
                color: AppColors.redesignVocabulary,
              ),
              const SizedBox(height: AppSizes.gap),
              _CategoryProgress(
                title: '문법',
                category: grammar,
                color: AppColors.redesignGrammar,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.md),
        Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.gap, vertical: AppSizes.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.gap),
            border: Border.all(
              color: light ? AppColors.redesignOutline : colors.outline,
            ),
          ),
          child: progress == null
              ? SizedBox(
                  height: textScale.scale(13) * 1.4,
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: AppSkeletonBlock(width: 172, height: 11),
                  ),
                )
              : Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '• ', style: TextStyle(color: brand)),
                    TextSpan(
                      text: '$level 마스터까지 ',
                      style: TextStyle(color: muted),
                    ),
                    TextSpan(
                      text:
                          '단어 ${formatCount(_remaining(progress.vocabulary))}개, '
                          '문법 ${formatCount(_remaining(progress.grammar))}개',
                    ),
                    TextSpan(text: ' 남았어요', style: TextStyle(color: muted)),
                    TextSpan(text: ' •', style: TextStyle(color: brand)),
                  ]),
                  textAlign: TextAlign.center,
                  style: _text(12),
                ),
        ),
      ],
    );
  }
}

int _remaining(ProgressCategory value) =>
    (value.total - value.mastered).clamp(0, value.total);

class _OverallProgress extends StatelessWidget {
  const _OverallProgress({
    required this.ratio,
    required this.color,
    required this.track,
  });

  final double? ratio;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final badge =
        light ? AppColors.redesignStrong : theme.colorScheme.onSurface;
    final onBadge = light ? Colors.white : theme.colorScheme.surface;
    final ratio = this.ratio;
    if (ratio == null) {
      final height = MediaQuery.textScalerOf(context).scale(10) * 1.4;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: AppSkeletonBlock(width: 38, height: height + 17),
          ),
          const SizedBox(height: 5),
          const AppSkeletonBlock(height: AppSizes.gap),
        ],
      );
    }
    final label = '${(ratio * 100).round()}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const padding = EdgeInsets.fromLTRB(7, 5, 7, 5);
            final badgeStyle = _text(10).copyWith(color: onBadge);
            final painter = TextPainter(
              text: TextSpan(text: label, style: badgeStyle),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout();
            final width = math.max(38.0, painter.width + padding.horizontal);
            painter.dispose();
            final edge = math.max(0.0, constraints.maxWidth - width);
            final left =
                (constraints.maxWidth * ratio - width / 2).clamp(0.0, edge);

            return Padding(
              padding: EdgeInsets.only(left: left),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: width,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Transform.rotate(
                          angle: math.pi / 4,
                          child: ColoredBox(
                            color: badge,
                            child: const SizedBox.square(dimension: 8),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Container(
                          width: double.infinity,
                          padding: padding,
                          decoration: BoxDecoration(
                            color: badge,
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusSm),
                          ),
                          child: Text(label,
                              textAlign: TextAlign.center, style: badgeStyle),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 5),
        _Bar(
          ratio: ratio,
          color: color,
          track: track,
          height: AppSizes.gap,
          semanticLabel: '통합 마스터율',
        ),
      ],
    );
  }
}

class _CategoryProgress extends StatelessWidget {
  const _CategoryProgress({
    required this.title,
    required this.category,
    required this.color,
  });

  final String title;
  final ProgressCategory? category;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final formatCount = MaterialLocalizations.of(context).formatDecimal;
    final category = this.category;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title),
            const SizedBox(width: AppSizes.sm),
            if (category == null)
              const AppSkeletonBlock(width: 49, height: 11)
            else
              Flexible(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: formatCount(category.mastered)),
                    TextSpan(
                      text: ' / ${formatCount(category.total)}',
                      style: TextStyle(
                        color: light
                            ? AppColors.redesignMutedForeground
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ]),
                  textAlign: TextAlign.end,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (category == null)
          const AppSkeletonBlock(
            width: double.infinity,
            height: AppSizes.progressHeight,
          )
        else
          _Bar(
            ratio: _masteryRatio(category.mastered, category.total),
            color: color,
            track: light
                ? AppColors.redesignDetailTrack
                : theme.colorScheme.surfaceContainerHigh,
            height: AppSizes.progressHeight,
            semanticLabel: '$title 진도',
          ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.ratio,
    required this.color,
    required this.track,
    required this.height,
    required this.semanticLabel,
  });

  final double ratio;
  final Color color;
  final Color track;
  final double height;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: ratio,
      minHeight: height,
      color: color,
      backgroundColor: track,
      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      trackGap: 0,
      stopIndicatorRadius: 0,
      semanticsLabel: semanticLabel,
    );
  }
}

class _NextGoal extends StatelessWidget {
  const _NextGoal({
    required this.level,
    required this.description,
    required this.onPressed,
  });

  final String level;
  final String description;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final light = theme.brightness == Brightness.light;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('다음 목표', style: _text(16, weight: FontWeight.w600)),
        const SizedBox(height: AppSizes.gap),
        Container(
          constraints: const BoxConstraints(minHeight: 79),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(AppSizes.gap),
          decoration: BoxDecoration(
            color:
                light ? AppColors.redesignSurface : colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppSizes.gap),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: '다음 목표는 '),
                  TextSpan(
                      text: level, style: TextStyle(color: colors.primary)),
                ]),
                textAlign: TextAlign.center,
                style: _text(18, weight: FontWeight.w700),
              ),
              const SizedBox(height: AppSizes.xs),
              Text(
                description,
                style: TextStyle(
                  color: light
                      ? AppColors.redesignMutedForeground
                      : colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: colors.onPrimary,
            minimumSize: const Size(0, kMinInteractiveDimension),
            visualDensity: VisualDensity.standard,
            padding: const EdgeInsets.symmetric(vertical: 6),
            textStyle: _text(13, weight: FontWeight.w500),
            shape: const StadiumBorder(),
          ),
          child: Ink(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.gap, vertical: 9),
            decoration: ShapeDecoration(
              color: light ? colors.primary : AppColors.primaryButton,
              shape: const StadiumBorder(),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Flexible(child: Text('다음 진도 학습하러 가기')),
                const SizedBox(width: AppSizes.xs),
                Icon(LucideIcons.chevronRight,
                    size: 14, color: colors.onPrimary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
