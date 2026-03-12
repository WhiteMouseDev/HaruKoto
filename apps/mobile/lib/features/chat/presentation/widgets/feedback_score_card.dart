import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';

class FeedbackScoreCard extends StatelessWidget {
  final int overallScore;
  final int fluency;
  final int accuracy;
  final int vocabularyDiversity;
  final int naturalness;

  const FeedbackScoreCard({
    super.key,
    required this.overallScore,
    required this.fluency,
    required this.accuracy,
    required this.vocabularyDiversity,
    required this.naturalness,
  });

  double get _starRating => (overallScore / 100 * 5 * 10).roundToDouble() / 10;

  String _getScoreLabel(int score) {
    if (score >= 80) return '훌륭해요';
    if (score >= 60) return '좋아요';
    if (score >= 40) return '조금 더 연습해봐요';
    return '기초부터 다져봐요';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final fullStars = _starRating.floor();

    final scores = [
      _ScoreItem(LucideIcons.messageSquare, '유창성', fluency),
      _ScoreItem(LucideIcons.target, '정확성', accuracy),
      _ScoreItem(LucideIcons.library, '어휘 다양성', vocabularyDiversity),
      _ScoreItem(LucideIcons.leaf, '자연스러움', naturalness),
    ];

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Mascot & message
            const Text('🦊', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            Text(
              _starRating >= 4
                  ? '일본어 실력이 훌륭해요!'
                  : _starRating >= 3
                      ? '일본어 실력이 늘고 있어요!'
                      : '조금 더 연습해봐요!',
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),

            // Star rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                Color starColor;
                if (i < fullStars) {
                  starColor = AppColors.hkYellowLight;
                } else if (i < _starRating.ceil()) {
                  starColor = AppColors.hkYellowLight.withValues(alpha: 0.4);
                } else {
                  starColor = colorScheme.onSurface.withValues(alpha: 0.15);
                }
                return Icon(LucideIcons.star, size: 28, color: starColor);
              }),
            ),
            const SizedBox(height: 4),
            Text(
              '${_starRating.toStringAsFixed(1)} / 5',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Detail scores
            ...scores.asMap().entries.map((entry) {
              final item = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(item.icon, size: 16,
                                color: colorScheme.onSurface),
                            const SizedBox(width: 6),
                            Text(item.label,
                                style: theme.textTheme.bodySmall),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              _getScoreLabel(item.score),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${item.score}%',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: item.score / 100,
                        minHeight: 10,
                        backgroundColor:
                            colorScheme.secondaryContainer.withValues(alpha: 0.5),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ScoreItem {
  final IconData icon;
  final String label;
  final int score;
  const _ScoreItem(this.icon, this.label, this.score);
}
