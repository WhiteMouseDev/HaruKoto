import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../../../shared/widgets/app_error_retry.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../providers/kana_provider.dart';
import 'widgets/kana_type_card.dart';

class KanaHubPage extends ConsumerWidget {
  const KanaHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(kanaProgressProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: progressAsync.when(
          loading: () => const AppSkeleton(
            itemCount: 3,
            itemHeights: [28, 120, 120],
          ),
          error: (error, _) => AppErrorRetry(
            onRetry: () => ref.invalidate(kanaProgressProvider),
          ),
          data: (progress) {
            return ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.md,
                vertical: AppSizes.md,
              ),
              children: [
                const SizedBox(height: AppSizes.sm),
                Text(
                  '가나 학습',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSizes.xs),
                Text(
                  '일본어의 기본! 히라가나와 가타카나를 배워보세요.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: AppSizes.lg),

                // Hiragana card
                KanaTypeCard(
                  character: 'あ',
                  title: '히라가나 배우기',
                  subtitle:
                      '${progress.hiragana.learned}/${progress.hiragana.total}자 학습',
                  progressPct: progress.hiragana.pct,
                  onTap: () => context.push('/study/kana/hiragana'),
                ),
                const SizedBox(height: AppSizes.md),

                // Katakana card
                KanaTypeCard(
                  character: 'ア',
                  title: '가타카나 배우기',
                  subtitle:
                      '${progress.katakana.learned}/${progress.katakana.total}자 학습',
                  progressPct: progress.katakana.pct,
                  onTap: () => context.push('/study/kana/katakana'),
                ),
                const SizedBox(height: AppSizes.md),

                // 50-sound chart link
                Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                    onTap: () => context.push('/study/kana/chart'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.grid,
                            size: 20,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '50음도 차트 보기',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Icon(
                            LucideIcons.chevronRight,
                            size: 16,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // N5 lesson transition CTA
                Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                    onTap: () => context.go('/study'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.bookOpen,
                            size: 20,
                            color: AppColors.primaryStrong,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'N5 레슨 시작하기',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryStrong,
                                  ),
                                ),
                                Text(
                                  '가나를 배웠다면 단어와 문법을 시작해보세요',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            LucideIcons.arrowRight,
                            size: 16,
                            color: AppColors.primaryStrong,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
