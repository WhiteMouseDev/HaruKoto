import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';

class LessonLevelEmptyState extends StatelessWidget {
  const LessonLevelEmptyState({
    super.key,
    required this.jlptLevel,
    this.compact = false,
    this.onSwitchToN5,
  });

  final String jlptLevel;
  final bool compact;
  final Future<void> Function()? onSwitchToN5;

  bool get _isN5 => jlptLevel == 'N5';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final cardColor =
        isLight ? AppColors.cardWarm : theme.colorScheme.surfaceContainerLow;
    final borderColor =
        isLight ? AppColors.lightBorder : theme.colorScheme.outline;
    final horizontalPadding = compact ? 16.0 : 20.0;
    final verticalPadding = compact ? 18.0 : 22.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: compact ? 36 : 42,
                height: compact ? 36 : 42,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: const Icon(
                  LucideIcons.bookOpen,
                  size: 20,
                  color: AppColors.primaryStrong,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isN5 ? '레슨을 준비하고 있어요' : '$jlptLevel 레슨 준비 중',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _isN5
                          ? '레슨 데이터가 준비되면 여기에 학습 경로가 표시돼요.'
                          : '검토가 끝난 레슨부터 순서대로 열릴 예정이에요. 지금은 N5 레슨으로 학습 흐름을 이어갈 수 있어요.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.lightSubtext,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!_isN5 && onSwitchToN5 != null) ...[
            SizedBox(height: compact ? 14 : 16),
            FilledButton.icon(
              onPressed: () async {
                await onSwitchToN5!();
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryStrong,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              icon: const Icon(LucideIcons.arrowLeft, size: 16),
              label: const Text('N5 레슨 보기'),
            ),
          ],
        ],
      ),
    );
  }
}
