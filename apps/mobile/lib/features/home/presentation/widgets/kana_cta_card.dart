import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/services/haptic_service.dart';
import '../../data/models/dashboard_model.dart';

class KanaCtaCard extends StatelessWidget {
  final KanaProgressData kanaProgress;

  const KanaCtaCard({super.key, required this.kanaProgress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalLearned =
        kanaProgress.hiragana.learned + kanaProgress.katakana.learned;
    final totalChars =
        kanaProgress.hiragana.total + kanaProgress.katakana.total;
    final progress = totalChars > 0 ? totalLearned / totalChars : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.pageHorizontal),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            onTap: () {
              HapticService().selection();
              context.go('/study/kana');
            },
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      LucideIcons.languages,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '가나 문자 학습',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$totalLearned/$totalChars 학습 완료',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: theme.colorScheme.secondary,
                            valueColor: AlwaysStoppedAnimation(
                              theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    LucideIcons.chevronRight,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
