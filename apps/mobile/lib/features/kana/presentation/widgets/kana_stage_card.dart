import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';

class KanaStageCard extends StatelessWidget {
  final int stageNumber;
  final String title;
  final String description;
  final List<String> characters;
  final bool isUnlocked;
  final bool isCompleted;
  final int? quizScore;
  final VoidCallback? onTap;

  const KanaStageCard({
    super.key,
    required this.stageNumber,
    required this.title,
    required this.description,
    required this.characters,
    required this.isUnlocked,
    required this.isCompleted,
    this.quizScore,
    this.onTap,
  });

  bool get _isLocked => !isUnlocked;
  bool get _isInProgress => isUnlocked && !isCompleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final successColor = AppColors.success(theme.brightness);

    Color? borderColor;
    Color? bgColor;
    if (_isLocked) {
      bgColor = theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.5);
    } else if (isCompleted) {
      borderColor = successColor;
      bgColor = successColor.withValues(alpha: 0.05);
    } else if (_isInProgress) {
      borderColor = theme.colorScheme.primary;
    }

    return Opacity(
      opacity: _isLocked ? 0.6 : 1.0,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          side: borderColor != null
              ? BorderSide(color: borderColor)
              : BorderSide.none,
        ),
        color: bgColor,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          onTap: _isLocked ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Stage number badge
                _StageBadge(
                  stageNumber: stageNumber,
                  isCompleted: isCompleted,
                  isLocked: _isLocked,
                ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (quizScore != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: successColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$quizScore점',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: successColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Character preview
                      Wrap(
                        spacing: 6,
                        children: [
                          ...characters.take(5).map((char) {
                            return Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isCompleted
                                    ? successColor.withValues(alpha: 0.1)
                                    : theme.colorScheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                char,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isCompleted
                                      ? successColor
                                      : theme.colorScheme.onSurface
                                          .withValues(alpha: 0.5),
                                ),
                              ),
                            );
                          }),
                          if (characters.length > 5)
                            Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '+${characters.length - 5}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Chevron
                if (!_isLocked)
                  Icon(
                    LucideIcons.chevronRight,
                    size: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StageBadge extends StatelessWidget {
  final int stageNumber;
  final bool isCompleted;
  final bool isLocked;

  const _StageBadge({
    required this.stageNumber,
    required this.isCompleted,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final successColor = AppColors.success(theme.brightness);

    if (isCompleted) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: successColor,
          shape: BoxShape.circle,
        ),
        child: const Icon(LucideIcons.check,
            size: 20, color: AppColors.onGradient),
      );
    }

    if (isLocked) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          LucideIcons.lock,
          size: 16,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      );
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$stageNumber',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }
}
