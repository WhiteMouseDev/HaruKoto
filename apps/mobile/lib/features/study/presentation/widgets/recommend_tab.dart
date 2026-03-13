import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../data/models/recommendation_model.dart';
import '../quiz_page.dart';
import '../wrong_answers_page.dart';
import 'recommendation_card.dart';

class RecommendTab extends ConsumerWidget {
  final AsyncValue<RecommendationModel> recs;
  final VoidCallback onInvalidate;

  const RecommendTab({
    super.key,
    required this.recs,
    required this.onInvalidate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return recs.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => Center(
        child: Column(
          children: [
            const SizedBox(height: 32),
            Text(
              '추천을 불러올 수 없습니다',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface
                    .withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onInvalidate,
              icon:
                  const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
      data: (data) => _buildContent(context, data),
    );
  }

  Widget _buildContent(BuildContext context, RecommendationModel data) {
    final theme = Theme.of(context);

    final hasContent = data.reviewDueCount > 0 ||
        data.newWordsCount > 0 ||
        data.wrongCount > 0;

    if (!hasContent) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              Icon(
                LucideIcons.flower2,
                size: 32,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                '추천 학습이 없어요',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '자율 탭에서 원하는 학습을 시작해보세요',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        if (data.reviewDueCount > 0)
          RecommendationCard(
            icon: LucideIcons.refreshCw,
            title: '복습할 단어',
            subtitle:
                '오늘 복습이 필요한 단어 ${data.reviewDueCount}개가 있어요',
            trailing: data.lastReviewText != null
                ? '마지막 복습: ${data.lastReviewText}'
                : null,
            actionText: '지금 복습하기 →',
            isPrimary: true,
            onTap: () {
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) => const QuizPage(
                    quizType: 'VOCABULARY',
                    jlptLevel: 'N5',
                    count: 10,
                    mode: 'review',
                  ),
                ),
              );
            },
          ),
        if (data.newWordsCount > 0) ...[
          const SizedBox(height: 12),
          RecommendationCard(
            icon: LucideIcons.bookOpen,
            title: '새로운 N5 단어',
            subtitle:
                '아직 안 본 단어 ${data.newWordsCount}개',
            actionText: '학습 시작 →',
            onTap: () {
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) => const QuizPage(
                    quizType: 'VOCABULARY',
                    jlptLevel: 'N5',
                    count: 10,
                  ),
                ),
              );
            },
          ),
        ],
        if (data.wrongCount > 0) ...[
          const SizedBox(height: 12),
          RecommendationCard(
            icon: LucideIcons.fileX,
            title: '오답 노트',
            subtitle:
                '최근 틀린 단어 ${data.wrongCount}개',
            actionText: '오답 복습 →',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const WrongAnswersPage(),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
