import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../data/models/scenario_model.dart';

final _difficultyStyles = {
  'BEGINNER': const _DiffStyle('초급', AppColors.difficultyBeginner),
  'INTERMEDIATE': const _DiffStyle('중급', AppColors.difficultyIntermediate),
  'ADVANCED': const _DiffStyle('고급', AppColors.difficultyAdvanced),
};

class _DiffStyle {
  final String label;
  final Color color;
  const _DiffStyle(this.label, this.color);
}

class ScenarioCard extends StatelessWidget {
  final ScenarioModel scenario;
  final VoidCallback onSelect;
  final bool showCallButton;
  final VoidCallback? onCall;

  const ScenarioCard({
    super.key,
    required this.scenario,
    required this.onSelect,
    this.showCallButton = false,
    this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final diff = _difficultyStyles[scenario.difficulty] ??
        _DiffStyle(scenario.difficulty, AppColors.overlay(0.5));

    return GestureDetector(
      onTap: onSelect,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(color: Colors.transparent),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          scenario.title,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: diff.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          diff.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: diff.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(LucideIcons.clock,
                          size: 12,
                          color: colorScheme.onSurface.withValues(alpha: 0.5)),
                      const SizedBox(width: 4),
                      Text(
                        '예상 ${scenario.estimatedMinutes}분',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                  if (scenario.keyExpressions.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '핵심표현: ${scenario.keyExpressions.take(2).join(', ')}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (showCallButton && onCall != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onCall,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.scenarioPurple.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.phone,
                      size: 16, color: AppColors.scenarioPurple),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(LucideIcons.chevronRight,
                size: 16, color: colorScheme.onSurface.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }
}
