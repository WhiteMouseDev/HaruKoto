import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';

class GoalOption {
  final String value;
  final IconData icon;
  final String label;

  const GoalOption({
    required this.value,
    required this.icon,
    required this.label,
  });
}

const goals = [
  GoalOption(value: 'TRAVEL', icon: LucideIcons.plane, label: '일본 여행'),
  GoalOption(value: 'CONTENT', icon: LucideIcons.tv, label: '콘텐츠 감상'),
  GoalOption(value: 'JLPT', icon: LucideIcons.fileText, label: 'JLPT 자격증'),
  GoalOption(value: 'WORK', icon: LucideIcons.briefcase, label: '취업·이직'),
  GoalOption(
      value: 'STUDY_ABROAD', icon: LucideIcons.graduationCap, label: '유학·교환학생'),
  GoalOption(value: 'LIVING', icon: LucideIcons.home, label: '일본 거주·생활'),
  GoalOption(value: 'HOBBY', icon: LucideIcons.sparkles, label: '취미·교양'),
];

class GoalStep extends StatelessWidget {
  final List<String> selectedGoals;
  final ValueChanged<String> onGoalToggled;
  final VoidCallback onBack;
  final VoidCallback onComplete;
  final bool loading;
  final String? error;

  const GoalStep({
    super.key,
    required this.selectedGoals,
    required this.onGoalToggled,
    required this.onBack,
    required this.onComplete,
    required this.loading,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '일본어를 배우는 이유는?',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '최대 3개까지 선택할 수 있어요',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.6,
                children: goals.map((goal) {
                  final isSelected = selectedGoals.contains(goal.value);
                  final isDisabled = !isSelected && selectedGoals.length >= 3;
                  return GestureDetector(
                    onTap: isDisabled ? null : () => onGoalToggled(goal.value),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: isDisabled ? 0.08 : 0.15),
                          width: 2,
                        ),
                        color: isSelected
                            ? theme.colorScheme.primary.withValues(alpha: 0.1)
                            : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Opacity(
                        opacity: isDisabled ? 0.4 : 1.0,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                goal.icon,
                                size: 20,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              goal.label,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error!,
                  style: TextStyle(
                      fontSize: 14,
                      color: AppColors.error(Theme.of(context).brightness)),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: loading ? null : onBack,
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('이전'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: selectedGoals.isNotEmpty && !loading
                            ? onComplete
                            : null,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(loading ? '설정 중...' : '시작하기'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
