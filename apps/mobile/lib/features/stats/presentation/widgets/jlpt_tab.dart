import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../data/models/level_progress_model.dart';

const _jlptInfo = <String, (String, String)>{
  'N5': ('N5', '기초 일본어'),
  'N4': ('N4', '기본적인 일본어'),
  'N3': ('N3', '일상적인 일본어'),
  'N2': ('N2', '일반적인 일본어'),
  'N1': ('N1', '고급 일본어'),
};

const _nextLevel = <String, String?>{
  'N5': 'N4',
  'N4': 'N3',
  'N3': 'N2',
  'N2': 'N1',
  'N1': null,
};

class JlptTab extends StatelessWidget {
  final LevelProgressData levelProgress;
  final String currentLevel;

  const JlptTab({
    super.key,
    required this.levelProgress,
    required this.currentLevel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final vocab = levelProgress.vocabulary;
    final grammar = levelProgress.grammar;

    final vocabPct =
        vocab.total > 0 ? (vocab.mastered / vocab.total * 100).round() : 0;
    final grammarPct =
        grammar.total > 0 ? (grammar.mastered / grammar.total * 100).round() : 0;

    final totalItems = vocab.total + grammar.total;
    final totalMastered = vocab.mastered + grammar.mastered;
    final overallPct =
        totalItems > 0 ? (totalMastered / totalItems * 100).round() : 0;

    final vocabRemaining = (vocab.total - vocab.mastered).clamp(0, vocab.total);
    final grammarRemaining =
        (grammar.total - grammar.mastered).clamp(0, grammar.total);

    final nextLevel = _nextLevel[currentLevel];
    final currentInfo = _jlptInfo[currentLevel] ?? ('N5', '기초 일본어');

    return Column(
      children: [
        // Current Level Progress
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Level badge + overall
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          currentLevel,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                currentInfo.$2,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '$overallPct%',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: overallPct / 100,
                              minHeight: 10,
                              backgroundColor: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.1),
                              valueColor: AlwaysStoppedAnimation(
                                theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '마스터 $totalMastered / $totalItems개',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Vocab breakdown
                _BreakdownRow(
                  icon: LucideIcons.bookOpen,
                  iconColor: theme.colorScheme.primary,
                  title: '단어',
                  mastered: vocab.mastered,
                  total: vocab.total,
                  percentage: vocabPct,
                  primaryColor: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),

                // Grammar breakdown
                _BreakdownRow(
                  icon: LucideIcons.bookMarked,
                  iconColor: AppColors.success(brightness),
                  title: '문법',
                  mastered: grammar.mastered,
                  total: grammar.total,
                  percentage: grammarPct,
                  primaryColor: theme.colorScheme.primary,
                ),

                // Remaining summary
                if (vocabRemaining > 0 || grammarRemaining > 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text.rich(
                      TextSpan(
                        text: '$currentLevel 마스터까지 ',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        children: [
                          if (vocabRemaining > 0)
                            TextSpan(
                              text: '단어 $vocabRemaining개',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          if (vocabRemaining > 0 && grammarRemaining > 0)
                            const TextSpan(text: ', '),
                          if (grammarRemaining > 0)
                            TextSpan(
                              text: '문법 $grammarRemaining개',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          const TextSpan(text: ' 남았어요'),
                        ],
                      ),
                    ),
                  ),
                ],

                if (overallPct >= 100) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success(brightness).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$currentLevel 완전 마스터!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success(brightness),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Next Level Teaser
        if (nextLevel != null) ...[
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        nextLevel,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '다음 목표: ${_jlptInfo[nextLevel]?.$2 ?? ''}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '학습 탭에서 $nextLevel 콘텐츠를 바로 시작할 수 있어요',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    LucideIcons.arrowRight,
                    size: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final int mastered;
  final int total;
  final int percentage;
  final Color primaryColor;

  const _BreakdownRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.mastered,
    required this.total,
    required this.percentage,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$mastered',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  TextSpan(text: '/$total'),
                ],
              ),
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 8,
            backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation(primaryColor),
          ),
        ),
      ],
    );
  }
}
