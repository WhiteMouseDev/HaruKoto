import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/sizes.dart';

class KanaMasterResult {
  final int correct;
  final int total;
  final int accuracy;
  final int xpEarned;
  final bool passed;

  KanaMasterResult({
    required this.correct,
    required this.total,
    required this.accuracy,
    required this.xpEarned,
    required this.passed,
  });
}

class KanaQuizMasterResultView extends StatelessWidget {
  final String label;
  final KanaMasterResult result;
  final VoidCallback onRetry;

  const KanaQuizMasterResultView({
    super.key,
    required this.label,
    required this.result,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.arrowLeft, size: 20),
                    onPressed: () => context.pop(),
                    visualDensity: VisualDensity.compact,
                  ),
                  Text(
                    '$label 마스터 퀴즈 결과',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.trophy,
                        size: 64,
                        color: result.passed
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: AppSizes.md),
                      Text(
                        result.passed ? '$label 마스터!' : '아쉽게 불합격...',
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        result.passed
                            ? '축하해요! $label 46자를 완벽하게 마스터했어요!'
                            : '90% 이상 정답이면 통과예요. 다시 도전해보세요!',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSizes.lg),
                      Card(
                        shape: result.passed
                            ? RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppSizes.cardRadius),
                                side: BorderSide(
                                    color: theme.colorScheme.primary),
                              )
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Text(
                                '${result.accuracy}%',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${result.correct}/${result.total} 정답 · +${result.xpEarned} XP',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSizes.xl),
                      SizedBox(
                        width: 280,
                        child: Column(
                          children: [
                            if (!result.passed)
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: FilledButton(
                                  onPressed: onRetry,
                                  style: FilledButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppSizes.buttonRadius,
                                      ),
                                    ),
                                  ),
                                  child: const Text('다시 도전하기'),
                                ),
                              ),
                            if (!result.passed) const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: result.passed
                                  ? FilledButton(
                                      onPressed: () => context.pop(),
                                      style: FilledButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppSizes.buttonRadius,
                                          ),
                                        ),
                                      ),
                                      child: const Text('돌아가기'),
                                    )
                                  : TextButton(
                                      onPressed: () => context.pop(),
                                      child: const Text('돌아가기'),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
