import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/theme/text_theme.dart';

class LessonStageActions extends StatelessWidget {
  const LessonStageActions({
    super.key,
    required this.nextLabel,
    required this.onNext,
    this.onPrevious,
  });

  final String nextLabel;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final light = theme.brightness == Brightness.light;
    final back = onPrevious;
    final bottomGap = MediaQuery.sizeOf(context).height < 700
        ? AppSizes.md
        : AppSizes.xl + AppSizes.sm;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
    );
    const textStyle = TextStyle(
      fontFamily: redesignFontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.4,
    );
    const padding = EdgeInsets.symmetric(
      horizontal: AppSizes.gap,
      vertical: AppSizes.sm,
    );
    const minimumSize = Size(0, AppSizes.buttonHeight);
    final next = FilledButton(
      onPressed: onNext,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryStrong,
        foregroundColor: Colors.white,
        disabledBackgroundColor:
            light ? AppColors.redesignControl : colors.surfaceContainerHigh,
        disabledForegroundColor: colors.onSurfaceVariant,
        minimumSize: minimumSize,
        padding: padding,
        shape: shape,
        textStyle: textStyle,
      ),
      child: back == null
          ? Text(nextLabel, textAlign: TextAlign.center)
          : _ActionLabel(nextLabel, trailing: LucideIcons.chevronRight),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSizes.pageHorizontal,
          AppSizes.sm,
          AppSizes.pageHorizontal,
          bottomGap,
        ),
        child: Row(
          children: [
            if (back != null) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: back,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: colors.surfaceContainerLowest,
                    foregroundColor:
                        light ? AppColors.redesignForeground : colors.onSurface,
                    side: BorderSide(
                        color:
                            light ? AppColors.redesignOutline : colors.outline),
                    minimumSize: minimumSize,
                    padding: padding,
                    shape: shape,
                    textStyle: textStyle,
                  ),
                  child: const _ActionLabel('이전',
                      leading: LucideIcons.chevronLeft),
                ),
              ),
              const SizedBox(width: AppSizes.sm),
            ],
            Expanded(child: next),
          ],
        ),
      ),
    );
  }
}

class _ActionLabel extends StatelessWidget {
  const _ActionLabel(this.text, {this.leading, this.trailing});

  final String text;
  final IconData? leading;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading != null) ...[
          Icon(leading, size: AppSizes.iconSm),
          const SizedBox(width: AppSizes.xs),
        ],
        Flexible(child: Text(text, textAlign: TextAlign.center)),
        if (trailing != null) ...[
          const SizedBox(width: AppSizes.xs),
          Icon(trailing, size: AppSizes.iconSm),
        ],
      ],
    );
  }
}
