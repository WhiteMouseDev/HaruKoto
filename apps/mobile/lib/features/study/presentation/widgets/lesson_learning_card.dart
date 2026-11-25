import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/theme/text_theme.dart';

class LessonLearningCard extends StatelessWidget {
  const LessonLearningCard({
    super.key,
    required this.itemType,
    required this.itemIndex,
    required this.itemCount,
    required this.term,
    required this.meaning,
    this.partOfSpeech,
    this.reading,
    this.explanation,
    this.audio,
    this.onPrevious,
    this.onNext,
  });

  final String itemType;
  final int itemIndex;
  final int itemCount;
  final String term;
  final String meaning;
  final String? partOfSpeech;
  final String? reading;
  final String? explanation;
  final Widget? audio;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final light = theme.brightness == Brightness.light;
    final foreground = light ? AppColors.redesignForeground : colors.onSurface;
    final muted =
        light ? AppColors.redesignMutedForeground : colors.onSurfaceVariant;
    final outline = light ? AppColors.redesignOutline : colors.outlineVariant;
    final surface = light ? AppColors.lightCard : colors.surfaceContainerLowest;
    final detailStyle = TextStyle(
      fontFamily: redesignFontFamily,
      fontSize: 14,
      height: 1.45,
      color: muted,
    );
    final navigationStyle = OutlinedButton.styleFrom(
      backgroundColor: surface,
      disabledBackgroundColor:
          light ? AppColors.redesignControl : colors.surfaceContainerHigh,
      foregroundColor: foreground,
      disabledForegroundColor: muted,
      minimumSize: const Size(0, 36),
      shape: const StadiumBorder(),
      side: BorderSide(color: outline),
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm, vertical: 6),
      tapTargetSize: MaterialTapTargetSize.padded,
      textStyle: const TextStyle(
        fontFamily: redesignFontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.4,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) => AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 250),
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.center,
          children: [
            for (final child in previous)
              IgnorePointer(child: ExcludeSemantics(child: child)),
            if (current != null) current,
          ],
        ),
        child: SingleChildScrollView(
          key: ValueKey((itemType, itemIndex)),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.pageHorizontal,
            vertical: AppSizes.sm,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - AppSizes.md)
                  .clamp(0.0, double.infinity),
            ),
            child: Center(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, AppSizes.xl),
                decoration: BoxDecoration(
                  color: light
                      ? AppColors.redesignSurface
                      : colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 22),
                      child: Row(
                        children: [
                          if (partOfSpeech case final label?)
                            Flexible(
                              fit: FlexFit.tight,
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: DecoratedBox(
                                  decoration: const ShapeDecoration(
                                    color: AppColors.redesignVocabulary,
                                    shape: StadiumBorder(),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSizes.sm,
                                      vertical: 2,
                                    ),
                                    child: Text(
                                      label,
                                      style: detailStyle.copyWith(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else
                            const Spacer(),
                          const SizedBox(width: AppSizes.sm),
                          Expanded(
                            child: Text(
                              '$itemType ${itemIndex + 1} / $itemCount',
                              textAlign: TextAlign.end,
                              style: detailStyle.copyWith(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSizes.xl),
                    Text(
                      term,
                      textAlign: TextAlign.center,
                      style: detailStyle.copyWith(
                        color: foreground,
                        fontSize: 26,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (reading case final readingText?) ...[
                      const SizedBox(height: AppSizes.xs),
                      Text(
                        readingText,
                        textAlign: TextAlign.center,
                        style: detailStyle.copyWith(fontSize: 12),
                      ),
                    ],
                    if (meaning.trim().isNotEmpty) ...[
                      const SizedBox(height: AppSizes.md),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.gap,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: surface,
                          border: Border.all(color: outline),
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusSm),
                        ),
                        child: Text(
                          meaning,
                          textAlign: TextAlign.center,
                          style: detailStyle.copyWith(
                            color: foreground,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                    if (explanation case final explanationText?) ...[
                      const SizedBox(height: AppSizes.md),
                      Text(
                        explanationText,
                        textAlign: TextAlign.center,
                        style: detailStyle,
                      ),
                    ],
                    if (audio case final audioControl?) ...[
                      const SizedBox(height: AppSizes.xs),
                      audioControl,
                    ],
                    if (itemCount > 1) ...[
                      const SizedBox(height: AppSizes.md),
                      Row(
                        children: [
                          Expanded(
                            child: _LessonItemButton(
                              label: '이전 $itemType',
                              previous: true,
                              onPressed: onPrevious,
                              style: navigationStyle,
                            ),
                          ),
                          const SizedBox(width: AppSizes.sm),
                          Expanded(
                            child: _LessonItemButton(
                              label: '다음 $itemType',
                              previous: false,
                              onPressed: onNext,
                              style: navigationStyle,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LessonItemButton extends StatelessWidget {
  const _LessonItemButton({
    required this.label,
    required this.previous,
    required this.onPressed,
    required this.style,
  });

  final String label;
  final bool previous;
  final VoidCallback? onPressed;
  final ButtonStyle style;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: onPressed,
        style: style,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (previous) ...[
              const Icon(LucideIcons.chevronLeft, size: AppSizes.iconSm),
              const SizedBox(width: 2),
            ],
            Flexible(child: Text(label, textAlign: TextAlign.center)),
            if (!previous) ...[
              const SizedBox(width: 2),
              const Icon(LucideIcons.chevronRight, size: AppSizes.iconSm),
            ],
          ],
        ),
      );
}
