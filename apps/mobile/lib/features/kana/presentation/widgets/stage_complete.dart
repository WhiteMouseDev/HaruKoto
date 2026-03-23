import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';

class StageComplete extends StatelessWidget {
  final String stageTitle;
  final int quizCorrect;
  final int quizTotal;
  final int xpEarned;
  final String kanaType;

  const StageComplete({
    super.key,
    required this.stageTitle,
    required this.quizCorrect,
    required this.quizTotal,
    required this.xpEarned,
    required this.kanaType,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.partyPopper,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: AppSizes.md),
          Text(
            '단계 완료!',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$stageTitle을(를) 학습했어요!',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          if (quizTotal > 0) ...[
            const SizedBox(height: AppSizes.lg),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.zap,
                          size: 20,
                          color: AppColors.hkYellowLight,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '+$xpEarned XP',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '퀴즈 결과: $quizCorrect/$quizTotal 정답',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSizes.xl),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () => context.go('/study/kana/$kanaType'),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.buttonRadius),
                      ),
                    ),
                    child: const Text('다음 단계로'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton(
                    onPressed: () => context.go('/study/kana'),
                    child: const Text('가나 학습 홈으로'),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton(
                    onPressed: () => context.go('/study'),
                    child: const Text(
                      'N5 레슨 시작하기',
                      style: TextStyle(
                        color: AppColors.primaryStrong,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
