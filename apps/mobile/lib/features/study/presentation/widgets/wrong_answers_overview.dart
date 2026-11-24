import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/theme/text_theme.dart';
import '../../data/models/word_entry_model.dart';
import 'wrong_answers_summary_card.dart';

class WrongAnswersOverview extends StatelessWidget {
  const WrongAnswersOverview({
    super.key,
    required this.summary,
    required this.onStartReview,
  });

  final WrongAnswersSummary? summary;
  final VoidCallback? onStartReview;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final light = colors.brightness == Brightness.light;
    final foreground = light ? AppColors.redesignForeground : colors.onSurface;
    final snapshot = summary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '전체 통계',
          style: TextStyle(
            fontFamily: redesignFontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: foreground,
          ),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color:
                light ? AppColors.redesignSurface : colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WrongAnswersSummaryCard(
                  label: '전체',
                  count: snapshot?.totalWrong,
                  icon: LucideIcons.diamond,
                  iconColor: AppColors.redesignVocabulary,
                ),
                WrongAnswersSummaryCard(
                  label: '학습 중',
                  count: snapshot?.remaining,
                  icon: LucideIcons.barChart3,
                  iconColor: AppColors.redesignGrammar,
                ),
                WrongAnswersSummaryCard(
                  label: '학습 완료',
                  count: snapshot?.mastered,
                  icon: LucideIcons.checkCircle2,
                  iconColor: AppColors.redesignSentence,
                ),
              ],
            ),
          ),
        ),
        if (snapshot != null && snapshot.remaining > 0) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStartReview,
              icon: const Icon(LucideIcons.rotateCcw, size: 15),
              label: const Text('오답 복습 퀴즈 시작'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 46),
                shape: const StadiumBorder(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                backgroundColor: light ? AppColors.sakura : colors.primary,
                foregroundColor: light ? Colors.white : colors.onPrimary,
                textStyle: const TextStyle(
                  fontFamily: redesignFontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
