import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../../../shared/widgets/app_error_retry.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../data/models/chat_message_model.dart';
import '../data/models/feedback_model.dart';
import '../providers/conversation_feedback_provider.dart';
import 'widgets/conversation_status_mark.dart';
import 'widgets/feedback_score_card.dart';
import 'widgets/feedback_transcript.dart';
import 'widgets/expression_practice_card.dart';

const Size _feedbackNoDataActionSize = Size(220, 56);

class ConversationFeedbackPage extends ConsumerWidget {
  const ConversationFeedbackPage({
    super.key,
    required this.conversationId,
    this.initialFeedback,
    this.initialFeedbackError,
    this.onRetryVoiceCall,
    this.vocabulary,
  });

  final String conversationId;
  final FeedbackSummary? initialFeedback;
  final String? initialFeedbackError;
  final VoidCallback? onRetryVoiceCall;
  final List<VocabularyItem>? vocabulary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasInitialAnalysisResult =
        initialFeedback != null || initialFeedbackError != null;
    final feedbackAsync = hasInitialAnalysisResult
        ? AsyncValue.data(initialFeedback)
        : ref.watch(conversationFeedbackProvider(conversationId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(LucideIcons.arrowLeft),
        ),
        title: Text(
          '회화 리포트',
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: feedbackAsync.when(
        loading: () => const AppSkeleton(
          itemCount: 3,
          itemHeights: [160, 120, 96],
        ),
        error: (error, stackTrace) => AppErrorRetry(
          onRetry: () {
            ref.invalidate(conversationFeedbackProvider(conversationId));
          },
        ),
        data: (feedback) {
          if (feedback == null) {
            return _FeedbackNoData(
              errorCode: initialFeedbackError,
              onRetryVoiceCall: onRetryVoiceCall,
            );
          }
          return _FeedbackContent(
            feedback: feedback,
            vocabulary: vocabulary,
          );
        },
      ),
    );
  }
}

class _FeedbackNoData extends StatelessWidget {
  const _FeedbackNoData({
    this.errorCode,
    this.onRetryVoiceCall,
  });

  final String? errorCode;
  final VoidCallback? onRetryVoiceCall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final String title;
    final String detail;
    switch (errorCode) {
      case 'no_transcript':
        title = '분석할 발화를 확인하지 못했어요';
        detail =
            '음성 인식으로 남은 내용이 충분하지 않아 피드백을 만들지 못했어요.\n실제 말한 내용과 기록이 다를 수 있어요.';
        break;
      case 'analysis_skipped':
        title = '대화 기록을 저장했어요';
        detail = '이번 대화는 피드백 없이 기록만 남겼어요.\n다음 연습도 편하게 이어가 보세요.';
        break;
      case 'generation_failed':
        title = '지금은 피드백을 준비하지 못했어요';
        detail = '저장된 대화 기록에서 피드백을 다시 요청할 수 있어요.';
        break;
      default:
        title = '피드백 데이터를 불러올 수 없어요';
        detail = '';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ConversationStatusMark(
              icon: LucideIcons.micOff,
              size: 64,
            ),
            const SizedBox(height: AppSizes.sm),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (detail.isNotEmpty) ...[
              const SizedBox(height: AppSizes.xs),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
            const SizedBox(height: AppSizes.md),
            if (onRetryVoiceCall != null) ...[
              FilledButton(
                onPressed: onRetryVoiceCall,
                style: _feedbackNoDataActionStyle(),
                child: const Text('다시 통화하기'),
              ),
              const SizedBox(height: AppSizes.xs),
            ],
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: _feedbackNoDataActionStyle(
                foregroundColor: AppColors.primary,
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.22),
                ),
              ),
              child: const Text('대화 목록으로'),
            ),
          ],
        ),
      ),
    );
  }
}

ButtonStyle _feedbackNoDataActionStyle({
  Color? foregroundColor,
  BorderSide? side,
}) {
  return ButtonStyle(
    foregroundColor: foregroundColor == null
        ? null
        : WidgetStatePropertyAll(foregroundColor),
    side: side == null ? null : WidgetStatePropertyAll(side),
    minimumSize: const WidgetStatePropertyAll(_feedbackNoDataActionSize),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    ),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
      ),
    ),
    textStyle: const WidgetStatePropertyAll(
      TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  );
}

class _FeedbackContent extends StatelessWidget {
  const _FeedbackContent({
    required this.feedback,
    this.vocabulary,
  });

  final FeedbackSummary feedback;
  final List<VocabularyItem>? vocabulary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;
    final fb = feedback;

    return ListView(
      padding: const EdgeInsets.all(AppSizes.md),
      children: [
        Text('오늘의 대화를 돌아봐요', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSizes.sm),
        const Text('아래 내용은 대화 전사문을 바탕으로 한 AI 제안이에요.'),
        if (fb.recommendedExpressions.isNotEmpty) ...[
          const SizedBox(height: AppSizes.md),
          ExpressionPracticeCard(
            expression: fb.recommendedExpressions.first.ja,
            meaning: fb.recommendedExpressions.first.ko,
          ),
        ],
        ExpansionTile(
          title: const Text('상세 점수 보기'),
          children: [
            FeedbackScoreCard(
              overallScore: fb.overallScore,
              fluency: fb.fluency,
              accuracy: fb.accuracy,
              vocabularyDiversity: fb.vocabularyDiversity,
              naturalness: fb.naturalness,
            )
          ],
        ),
        const SizedBox(height: AppSizes.md),
        if (fb.strengths.isNotEmpty) ...[
          _FeedbackListCard(
            icon: LucideIcons.checkCircle2,
            iconColor: AppColors.success(brightness),
            title: '잘한 표현',
            items: fb.strengths.take(1).toList(),
            itemIcon: LucideIcons.check,
            itemColor: AppColors.success(brightness),
          ),
          const SizedBox(height: AppSizes.md),
        ],
        if (fb.improvements.isNotEmpty) ...[
          _FeedbackListCard(
            icon: LucideIcons.lightbulb,
            iconColor: AppColors.hkYellowLight,
            title: '개선 포인트',
            items: fb.improvements.take(1).toList(),
            itemIcon: LucideIcons.lightbulb,
            itemColor: AppColors.hkYellowLight,
          ),
          const SizedBox(height: AppSizes.md),
        ],
        if (fb.translatedTranscript.isNotEmpty) ...[
          ExpansionTile(
            title: const Text('대화 내용과 교정 자세히 보기'),
            children: [
              FeedbackTranscriptWidget(
                translatedTranscript: fb.translatedTranscript,
                corrections: fb.corrections,
              )
            ],
          ),
          const SizedBox(height: AppSizes.md),
        ],
        if (fb.recommendedExpressions.length > 1) ...[
          ExpansionTile(
            title: const Text('다른 추천 표현'),
            children: fb.recommendedExpressions
                .skip(1)
                .map(
                  (expression) => ListTile(
                      title: Text(expression.ja),
                      subtitle: Text(expression.ko)),
                )
                .toList(),
          ),
          const SizedBox(height: AppSizes.md),
        ],
        if (vocabulary != null && vocabulary!.isNotEmpty) ...[
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.edit,
                          size: 16,
                          color: colorScheme.onSurface.withValues(alpha: 0.6)),
                      const SizedBox(width: AppSizes.sm),
                      Text(
                        '새로 배운 표현',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.sm),
                  ...vocabulary!.map(
                    (item) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                      ),
                      child: Row(
                        children: [
                          Row(
                            children: [
                              Text(
                                item.word,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '(${item.reading})',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                          if (item.meaningKo.isNotEmpty)
                            Text(
                              item.meaningKo,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSizes.md),
        ],
        const SizedBox(height: AppSizes.sm),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(LucideIcons.shuffle, size: 16),
          label: const Text('마치기'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
            ),
          ),
        ),
        const SizedBox(height: AppSizes.lg),
      ],
    );
  }
}

class _FeedbackListCard extends StatelessWidget {
  const _FeedbackListCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.items,
    required this.itemIcon,
    required this.itemColor,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final List<String> items;
  final IconData itemIcon;
  final Color itemColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: AppSizes.sm),
                Text(
                  title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sm),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(itemIcon, size: 16, color: itemColor),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: Text(
                        item,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
