import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../data/models/recommendation_model.dart';
import 'recommendation_card.dart';
import 'recommendation_empty_state.dart';

class RecommendationContent extends StatelessWidget {
  final RecommendationModel data;
  final VoidCallback onStartReviewQuiz;
  final VoidCallback onStartNewWordsQuiz;
  final VoidCallback onOpenWrongAnswers;

  const RecommendationContent({
    super.key,
    required this.data,
    required this.onStartReviewQuiz,
    required this.onStartNewWordsQuiz,
    required this.onOpenWrongAnswers,
  });

  @override
  Widget build(BuildContext context) {
    final hasContent = data.reviewDueCount > 0 ||
        data.newWordsCount > 0 ||
        data.wrongCount > 0;

    if (!hasContent) {
      return const RecommendationEmptyState();
    }

    return Column(
      children: [
        if (data.reviewDueCount > 0)
          RecommendationCard(
            icon: LucideIcons.refreshCw,
            title: '복습할 단어',
            subtitle: '오늘 복습이 필요한 단어 ${data.reviewDueCount}개가 있어요',
            trailing: data.lastReviewText != null
                ? '마지막 복습: ${data.lastReviewText}'
                : null,
            actionText: '지금 복습하기 →',
            isPrimary: true,
            onTap: onStartReviewQuiz,
          ),
        if (data.newWordsCount > 0) ...[
          const SizedBox(height: 12),
          RecommendationCard(
            icon: LucideIcons.bookOpen,
            title: '새로운 N5 단어',
            subtitle: '아직 안 본 단어 ${data.newWordsCount}개',
            actionText: '학습 시작 →',
            onTap: onStartNewWordsQuiz,
          ),
        ],
        if (data.wrongCount > 0) ...[
          const SizedBox(height: 12),
          RecommendationCard(
            icon: LucideIcons.fileX,
            title: '오답 노트',
            subtitle: '최근 틀린 단어 ${data.wrongCount}개',
            actionText: '오답 복습 →',
            onTap: onOpenWrongAnswers,
          ),
        ],
      ],
    );
  }
}
