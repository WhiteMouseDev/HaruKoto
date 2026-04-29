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
        title = '대화가 너무 짧아요';
        detail = '분석할 내용이 충분하지 않아 리포트를 만들 수 없었어요.\n다음에는 조금 더 길게 이야기해 보세요!';
        break;
      case 'generation_failed':
        title = '피드백 생성에 실패했어요';
        detail = '일시적인 문제로 리포트를 만들지 못했어요.\n잠시 후 다시 시도해 주세요.';
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
        FeedbackScoreCard(
          overallScore: fb.overallScore,
          fluency: fb.fluency,
          accuracy: fb.accuracy,
          vocabularyDiversity: fb.vocabularyDiversity,
          naturalness: fb.naturalness,
        ),
        const SizedBox(height: AppSizes.md),
        if (fb.translatedTranscript.isNotEmpty) ...[
          FeedbackTranscriptWidget(
            translatedTranscript: fb.translatedTranscript,
            corrections: fb.corrections,
          ),
          const SizedBox(height: AppSizes.md),
        ],
        if (fb.strengths.isNotEmpty) ...[
          _FeedbackListCard(
            icon: LucideIcons.checkCircle2,
            iconColor: AppColors.success(brightness),
            title: '잘한 표현',
            items: fb.strengths,
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
            items: fb.improvements,
            itemIcon: LucideIcons.lightbulb,
            itemColor: AppColors.hkYellowLight,
          ),
          const SizedBox(height: AppSizes.md),
        ],
        if (fb.recommendedExpressions.isNotEmpty) ...[
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
                      const Icon(
                        LucideIcons.bookOpen,
                        size: 16,
                        color: AppColors.hkBlueLight,
                      ),
                      const SizedBox(width: AppSizes.sm),
                      Text(
                        '추천 표현',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.sm),
                  ...fb.recommendedExpressions.map(
                    (expr) => Container(
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
                          Expanded(
                            child: Text(
                              expr.ja,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (expr.ko.isNotEmpty)
                            Text(
                              expr.ko,
                              style: theme.textTheme.labelSmall?.copyWith(
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
          label: const Text('다른 시나리오 도전하기'),
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
