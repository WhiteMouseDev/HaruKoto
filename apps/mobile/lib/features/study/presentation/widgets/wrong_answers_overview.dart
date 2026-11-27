import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
            fontSize: 16,
            height: 1.4,
            color: foreground,
          ),
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color:
                light ? AppColors.redesignSurface : colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WrongAnswersSummaryCard(
                  label: '전체',
                  count: snapshot?.totalWrong,
                  iconAsset: 'assets/icons/figma-wrong-answers-total.svg',
                ),
                _SummarySeparator(light: light),
                WrongAnswersSummaryCard(
                  label: '학습중',
                  count: snapshot?.remaining,
                  iconAsset: 'assets/icons/figma-wrong-answers-learning.svg',
                ),
                _SummarySeparator(light: light),
                WrongAnswersSummaryCard(
                  label: '학습 완료',
                  count: snapshot?.mastered,
                  iconAsset: 'assets/icons/figma-wrong-answers-mastered.svg',
                ),
              ],
            ),
          ),
        ),
        if (snapshot != null && snapshot.remaining > 0) ...[
          const SizedBox(height: 9),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStartReview,
              icon: SvgPicture.asset(
                'assets/icons/figma-wrong-answers-review.svg',
                width: 16,
                height: 16,
                colorFilter: ColorFilter.mode(
                  light ? Colors.white : colors.onPrimary,
                  BlendMode.srcIn,
                ),
              ),
              label: const Text('오답 복습 퀴즈 시작'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 42),
                visualDensity: VisualDensity.standard,
                tapTargetSize: MaterialTapTargetSize.padded,
                shape: const StadiumBorder(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                backgroundColor: light ? AppColors.sakura : colors.primary,
                foregroundColor: light ? Colors.white : colors.onPrimary,
                textStyle: const TextStyle(
                  fontFamily: redesignFontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SummarySeparator extends StatelessWidget {
  const _SummarySeparator({required this.light});

  final bool light;

  @override
  Widget build(BuildContext context) {
    return VerticalDivider(
      width: 1,
      thickness: 1,
      indent: 8,
      endIndent: 8,
      color: light
          ? AppColors.redesignOutline
          : Theme.of(context).colorScheme.outlineVariant,
    );
  }
}
