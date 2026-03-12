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
  GoalOption(
      value: 'JLPT_N5',
      icon: LucideIcons.target,
      label: 'JLPT N5 합격'),
  GoalOption(
      value: 'JLPT_N4',
      icon: LucideIcons.target,
      label: 'JLPT N4 합격'),
  GoalOption(
      value: 'JLPT_N3',
      icon: LucideIcons.target,
      label: 'JLPT N3 합격'),
  GoalOption(
      value: 'JLPT_N2',
      icon: LucideIcons.target,
      label: 'JLPT N2 합격'),
  GoalOption(
      value: 'JLPT_N1',
      icon: LucideIcons.target,
      label: 'JLPT N1 합격'),
  GoalOption(
      value: 'TRAVEL',
      icon: LucideIcons.plane,
      label: '여행 일본어'),
  GoalOption(
      value: 'BUSINESS',
      icon: LucideIcons.briefcase,
      label: '비즈니스 일본어'),
  GoalOption(
      value: 'HOBBY',
      icon: LucideIcons.heart,
      label: '취미/문화'),
];

class GoalStep extends StatelessWidget {
  final String? selectedGoal;
  final ValueChanged<String> onGoalSelected;
  final VoidCallback onBack;
  final VoidCallback onComplete;
  final bool loading;
  final String? error;

  const GoalStep({
    super.key,
    required this.selectedGoal,
    required this.onGoalSelected,
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
          borderRadius:
              BorderRadius.circular(AppSizes.cardRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '목표를 정해볼까요?',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics:
                    const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.5,
                children: goals.map((goal) {
                  final isSelected =
                      selectedGoal == goal.value;
                  return GestureDetector(
                    onTap: () =>
                        onGoalSelected(goal.value),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme
                                  .colorScheme.onSurface
                                  .withValues(
                                      alpha: 0.15),
                          width: 2,
                        ),
                        color: isSelected
                            ? theme.colorScheme.primary
                                .withValues(alpha: 0.1)
                            : null,
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: theme
                                  .colorScheme.primary
                                  .withValues(
                                      alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              goal.icon,
                              size: 20,
                              color: theme
                                  .colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            goal.label,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
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
                      color: AppColors.error(
                          Theme.of(context).brightness)),
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
                        onPressed:
                            loading ? null : onBack,
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12),
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
                        onPressed:
                            selectedGoal != null &&
                                    !loading
                                ? onComplete
                                : null,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(loading
                            ? '설정 중...'
                            : '시작하기'),
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
