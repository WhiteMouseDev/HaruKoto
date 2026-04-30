import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../data/models/word_entry_model.dart';
import 'wrong_answers_summary_card.dart';

class WrongAnswersOverview extends StatelessWidget {
  final WrongAnswersSummary summary;
  final VoidCallback onStartReview;

  const WrongAnswersOverview({
    super.key,
    required this.summary,
    required this.onStartReview,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return Column(
      children: [
        _WrongAnswersSummaryRow(summary: summary),
        if (summary.remaining > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton.icon(
                onPressed: onStartReview,
                icon: const Icon(LucideIcons.rotateCcw, size: 16),
                label: const Text('오답 복습 퀴즈 시작'),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      isLight ? AppColors.sakura : theme.colorScheme.primary,
                  foregroundColor:
                      isLight ? Colors.white : theme.colorScheme.onPrimary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _WrongAnswersSummaryRow extends StatelessWidget {
  final WrongAnswersSummary summary;

  const _WrongAnswersSummaryRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          WrongAnswersSummaryCard(
            label: '전체',
            value: '${summary.totalWrong}',
          ),
          const SizedBox(width: 8),
          WrongAnswersSummaryCard(
            label: '아직 학습중',
            value: '${summary.remaining}',
            valueColor: AppColors.error(theme.brightness),
          ),
          const SizedBox(width: 8),
          WrongAnswersSummaryCard(
            label: '극복 완료',
            value: '${summary.mastered}',
            valueColor: AppColors.mintPressed,
          ),
        ],
      ),
    );
  }
}
