import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../../../shared/widgets/app_error_retry.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../data/models/feedback_model.dart';
import '../data/models/chat_message_model.dart';
import '../providers/chat_provider.dart';
import 'widgets/feedback_score_card.dart';
import 'widgets/feedback_transcript.dart';

class ConversationFeedbackPage extends ConsumerStatefulWidget {
  final String conversationId;
  final FeedbackSummary? initialFeedback;
  final List<VocabularyItem>? vocabulary;

  const ConversationFeedbackPage({
    super.key,
    required this.conversationId,
    this.initialFeedback,
    this.vocabulary,
  });

  @override
  ConsumerState<ConversationFeedbackPage> createState() =>
      _ConversationFeedbackPageState();
}

class _ConversationFeedbackPageState
    extends ConsumerState<ConversationFeedbackPage> {
  FeedbackSummary? _feedback;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialFeedback != null) {
      _feedback = widget.initialFeedback;
      _loading = false;
    } else {
      _fetchFromServer();
    }
  }

  Future<void> _fetchFromServer() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final repo = ref.read(chatRepositoryProvider);
      final detail = await repo.fetchConversation(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _feedback = detail.feedbackSummary;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[ConversationFeedbackPage] Failed to fetch feedback: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(LucideIcons.arrowLeft),
        ),
        title: Text(
          '회화 리포트',
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const AppSkeleton(
              itemCount: 3,
              itemHeights: [160, 120, 96],
            )
          : _hasError
              ? AppErrorRetry(onRetry: _fetchFromServer)
              : _feedback == null
                  ? const _FeedbackNoData()
                  : _FeedbackContent(
                      feedback: _feedback!,
                      vocabulary: widget.vocabulary,
                    ),
    );
  }
}

class _FeedbackNoData extends StatelessWidget {
  const _FeedbackNoData();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🦊', style: TextStyle(fontSize: 48)),
          const SizedBox(height: AppSizes.sm),
          Text(
            '피드백 데이터를 불러올 수 없습니다.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: AppSizes.md),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('대화 목록으로'),
          ),
        ],
      ),
    );
  }
}

class _FeedbackContent extends StatelessWidget {
  final FeedbackSummary feedback;
  final List<VocabularyItem>? vocabulary;

  const _FeedbackContent({
    required this.feedback,
    this.vocabulary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;
    final fb = feedback;

    return ListView(
      padding: const EdgeInsets.all(AppSizes.md),
      children: [
        // Score card
        FeedbackScoreCard(
          overallScore: fb.overallScore,
          fluency: fb.fluency,
          accuracy: fb.accuracy,
          vocabularyDiversity: fb.vocabularyDiversity,
          naturalness: fb.naturalness,
        ),
        const SizedBox(height: AppSizes.md),

        // Transcript
        if (fb.translatedTranscript.isNotEmpty) ...[
          FeedbackTranscriptWidget(
            translatedTranscript: fb.translatedTranscript,
            corrections: fb.corrections,
          ),
          const SizedBox(height: AppSizes.md),
        ],

        // Strengths
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

        // Improvements
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

        // Recommended expressions
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
                      Icon(LucideIcons.bookOpen,
                          size: 16, color: AppColors.hkBlueLight),
                      const SizedBox(width: AppSizes.sm),
                      Text('추천 표현',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: AppSizes.sm),
                  ...fb.recommendedExpressions.map((expr) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer
                              .withValues(alpha: 0.5),
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusSm),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                expr.ja,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w500),
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
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSizes.md),
        ],

        // Vocabulary
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
                          color:
                              colorScheme.onSurface.withValues(alpha: 0.6)),
                      const SizedBox(width: AppSizes.sm),
                      Text('새로 배운 표현',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: AppSizes.sm),
                  ...vocabulary!.map((v) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer
                              .withValues(alpha: 0.5),
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusSm),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(v.word,
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.w500)),
                                const SizedBox(width: 6),
                                Text(
                                  '(${v.reading})',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                            Text(v.meaningKo,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                )),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSizes.md),
        ],

        // Action buttons
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
  final IconData icon;
  final Color iconColor;
  final String title;
  final List<String> items;
  final IconData itemIcon;
  final Color itemColor;

  const _FeedbackListCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.items,
    required this.itemIcon,
    required this.itemColor,
  });

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
                Text(title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: AppSizes.sm),
            ...items.map((item) => Padding(
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
                        child: Text(item, style: theme.textTheme.bodySmall),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
