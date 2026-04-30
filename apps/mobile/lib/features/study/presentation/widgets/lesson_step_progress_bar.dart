import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';

class LessonStepProgressBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const LessonStepProgressBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (index) {
        final isCompleted = index < currentStep;
        final isCurrent = index == currentStep;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index < totalSteps - 1 ? 3 : 0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: isCompleted || isCurrent
                    ? AppColors.sakura
                    : AppColors.sakuraTrack,
              ),
            ),
          ),
        );
      }),
    );
  }
}
