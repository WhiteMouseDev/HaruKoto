import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/theme/text_theme.dart';

class LessonStepProgressBar extends StatelessWidget {
  const LessonStepProgressBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final light = Theme.of(context).brightness == Brightness.light;
    final labelStyle = TextStyle(
      fontFamily: redesignFontFamily,
      fontSize: 12,
      height: 1.4,
      letterSpacing: -0.3,
      color:
          light ? AppColors.redesignMutedForeground : colors.onSurfaceVariant,
    );
    final stepNumber = currentStep + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          value: stepNumber / totalSteps,
          minHeight: AppSizes.sm,
          color: AppColors.primaryStrong,
          backgroundColor: light
              ? AppColors.redesignDetailTrack
              : colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          trackGap: 0,
          semanticsLabel: '전체 $totalSteps단계 중 $stepNumber단계',
        ),
        const SizedBox(height: AppSizes.xs),
        ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$stepNumber단계', style: labelStyle),
              Text('$totalSteps단계', style: labelStyle),
            ],
          ),
        ),
      ],
    );
  }
}
