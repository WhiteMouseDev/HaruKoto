import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../data/models/lesson_models.dart';

class LessonResultStep extends StatefulWidget {
  final LessonSubmitResultModel result;
  final LessonDetailModel detail;
  final VoidCallback onRetry;
  final VoidCallback onDone;

  const LessonResultStep({
    super.key,
    required this.result,
    required this.detail,
    required this.onRetry,
    required this.onDone,
  });

  @override
  State<LessonResultStep> createState() => _LessonResultStepState();
}

class _LessonResultStepState extends State<LessonResultStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _staggerController.forward();
    });
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  Widget _staggered(int index, Widget child) {
    final start = (index * 0.1).clamp(0.0, 0.7);
    final end = (start + 0.35).clamp(0.0, 1.0);
    final animation = CurvedAnimation(
      parent: _staggerController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - animation.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }

  IconData _srsTransitionIcon(String before, String after) {
    if (before == 'UNSEEN') return LucideIcons.sparkles;
    if (after == 'REVIEW' || after == 'MASTERED') return LucideIcons.trendingUp;
    if (after == 'RELEARNING') return LucideIcons.refreshCw;
    return LucideIcons.arrowLeftRight;
  }

  Color _srsTransitionColor(
    Brightness brightness,
    String before,
    String after,
  ) {
    if (after == 'MASTERED') return AppColors.success(brightness);
    if (after == 'REVIEW') return AppColors.info(brightness);
    if (after == 'LEARNING') return AppColors.warning(brightness);
    if (after == 'RELEARNING') return AppColors.error(brightness);
    if (after == 'PROVISIONAL') return AppColors.warning(brightness);
    return AppColors.lightSubtext;
  }

  String _formatReviewDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final now = DateTime.now();
      final diff = date.difference(now);
      if (diff.inMinutes < 60) return '${diff.inMinutes}분 후';
      if (diff.inHours < 24) return '${diff.inHours}시간 후';
      if (diff.inDays < 7) return '${diff.inDays}일 후';
      return '${date.month}/${date.day}';
    } catch (_) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final detail = widget.detail;
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final score = result.scoreTotal > 0
        ? (result.scoreCorrect / result.scoreTotal * 100).round()
        : 0;
    final isPerfect = result.scoreCorrect == result.scoreTotal;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSizes.md),
            children: [
              const SizedBox(height: AppSizes.lg),
              _staggered(
                0,
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isPerfect
                          ? AppColors.success(brightness)
                              .withValues(alpha: 0.12)
                          : AppColors.primary.withValues(alpha: 0.12),
                    ),
                    child: Icon(
                      isPerfect
                          ? LucideIcons.trophy
                          : LucideIcons.clipboardCheck,
                      size: 36,
                      color: isPerfect
                          ? AppColors.success(brightness)
                          : AppColors.primaryStrong,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.md),
              _staggered(
                1,
                Center(
                  child: TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: score),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => Text(
                      '$value%',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              _staggered(
                1,
                Center(
                  child: Text(
                    '${result.scoreCorrect}/${result.scoreTotal} 정답',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.lightSubtext,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.md),
              if (result.srsItemsRegistered > 0)
                _staggered(
                  2,
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSizes.md),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.md,
                      vertical: AppSizes.gap,
                    ),
                    decoration: BoxDecoration(
                      color:
                          AppColors.success(brightness).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                      border: Border.all(
                        color: AppColors.success(brightness)
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.checkCircle2,
                          color: AppColors.success(brightness),
                          size: AppSizes.iconMd,
                        ),
                        const SizedBox(width: AppSizes.sm),
                        Expanded(
                          child: Text(
                            '${result.srsItemsRegistered}개 항목이 복습 예약되었습니다',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: AppSizes.sm),
              ...result.results.asMap().entries.map((entry) {
                final lessonResult = entry.value;
                final question = detail.content.questions.firstWhere(
                  (candidate) => candidate.order == lessonResult.order,
                  orElse: () => detail.content.questions.first,
                );
                return _staggered(
                  entry.key + 3,
                  Card(
                    margin: const EdgeInsets.only(bottom: AppSizes.sm),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSizes.gap),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                lessonResult.isCorrect
                                    ? LucideIcons.checkCircle2
                                    : LucideIcons.xCircle,
                                color: lessonResult.isCorrect
                                    ? AppColors.success(brightness)
                                    : AppColors.error(brightness),
                                size: AppSizes.iconMd,
                              ),
                              const SizedBox(width: AppSizes.sm),
                              Expanded(
                                child: Text(
                                  question.prompt,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                          if (lessonResult.explanation != null) ...[
                            const SizedBox(height: AppSizes.xs),
                            Padding(
                              padding: const EdgeInsets.only(left: 28),
                              child: Text(
                                lessonResult.explanation!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.lightSubtext,
                                ),
                              ),
                            ),
                          ],
                          if (lessonResult.stateBefore != null &&
                              lessonResult.stateAfter != null) ...[
                            const SizedBox(height: AppSizes.sm),
                            Padding(
                              padding: const EdgeInsets.only(left: 28),
                              child: Row(
                                children: [
                                  Icon(
                                    _srsTransitionIcon(
                                      lessonResult.stateBefore!,
                                      lessonResult.stateAfter!,
                                    ),
                                    size: 14,
                                    color: _srsTransitionColor(
                                      brightness,
                                      lessonResult.stateBefore!,
                                      lessonResult.stateAfter!,
                                    ),
                                  ),
                                  const SizedBox(width: AppSizes.xs),
                                  Text(
                                    '${lessonResult.stateBefore} → ${lessonResult.stateAfter}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: _srsTransitionColor(
                                        brightness,
                                        lessonResult.stateBefore!,
                                        lessonResult.stateAfter!,
                                      ),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (lessonResult.isProvisionalPhase) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.warning(brightness)
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'SRS 등록됨',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: AppColors.warning(brightness),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                          if (lessonResult.nextReviewAt != null) ...[
                            const SizedBox(height: AppSizes.xs),
                            Padding(
                              padding: const EdgeInsets.only(left: 28),
                              child: Text(
                                '다음 복습: ${_formatReviewDate(lessonResult.nextReviewAt!)}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColors.lightSubtext,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: widget.onDone,
                    icon: const Icon(LucideIcons.bookOpen, size: 18),
                    label: const Text('학습으로 돌아가기'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryStrong,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: widget.onRetry,
                        child: const Text('다시 풀기'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
