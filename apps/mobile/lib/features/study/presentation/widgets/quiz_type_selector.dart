import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';

class QuizTypeSelector extends StatelessWidget {
  final List<(String, String)> quizTypes;
  final String selectedType;
  final ValueChanged<String> onTypeChanged;

  const QuizTypeSelector({
    super.key,
    required this.quizTypes,
    required this.selectedType,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius:
            BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Row(
        children: quizTypes.map((t) {
          final isActive = selectedType == t.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTypeChanged(t.$1),
              child: AnimatedContainer(
                duration:
                    const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isActive
                      ? theme.colorScheme.surface
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: AppColors.overlay(0.05),
                            blurRadius: 4,
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    t.$2,
                    style:
                        theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
