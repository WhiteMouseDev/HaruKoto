import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../shared/widgets/app_skeleton.dart';

class HomeStreakSkeleton extends StatelessWidget {
  const HomeStreakSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final labelSize = MediaQuery.textScalerOf(context).scale(11);
    final countWidth = math.max(87.0, labelSize * 5 + 16);
    final count = SizedBox(
      width: countWidth,
      child: AppSkeletonBlock(height: math.max(56.0, labelSize * 2.8 + 18)),
    );
    final week = Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(
        DateTime.daysPerWeek,
        (_) => const AppSkeletonBlock(width: 18, height: 24, radius: 12),
      ),
    );
    const arrow = AppSkeletonBlock(width: 6.25, height: 11);

    return Semantics(
      label: '연속 학습 기록을 불러오는 중',
      container: true,
      child: Padding(
        padding: AppSizes.pageHorizontalEdge,
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  light ? AppColors.redesignControl : theme.colorScheme.outline,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth <
                  countWidth +
                      AppSizes.gap +
                      7 * (labelSize + 8) +
                      AppSizes.iconSm) {
                return Column(
                  children: [
                    Row(children: [
                      Flexible(child: count),
                      const Spacer(),
                      arrow
                    ]),
                    const SizedBox(height: AppSizes.xs),
                    week,
                  ],
                );
              }
              return Row(
                children: [
                  count,
                  const SizedBox(width: AppSizes.gap),
                  Expanded(child: week),
                  const SizedBox(width: 4),
                  arrow,
                  const SizedBox(width: 5),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class HomeGreetingSkeleton extends StatelessWidget {
  const HomeGreetingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return Padding(
      padding: AppSizes.pageHorizontalEdge,
      child: Semantics(
        label: '인사말을 불러오는 중',
        container: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: scaler.scale(18) * 1.4,
              child: const Center(
                widthFactor: 1,
                child: AppSkeletonBlock(width: 86, height: 14),
              ),
            ),
            const SizedBox(height: 5),
            SizedBox(
              height: scaler.scale(24) * 1.4,
              child: const Center(
                widthFactor: 1,
                child: AppSkeletonBlock(width: 200, height: 21),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
