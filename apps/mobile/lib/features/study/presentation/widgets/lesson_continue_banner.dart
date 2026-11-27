import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/theme/haru_typography.dart';
import '../../../../core/theme/text_theme.dart';
import '../../../../shared/widgets/haru_button_styles.dart';
import '../../domain/lesson_recommendation.dart';
import '../../providers/study_map_config.dart';
import '../study_map_colors.dart';

class LessonContinueBanner extends ConsumerWidget {
  const LessonContinueBanner({
    super.key,
    required this.target,
    this.compact = false,
    this.redesigned = false,
    this.onTap,
  });

  final RecommendedLessonTarget target;
  final bool compact;
  final bool redesigned;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (redesigned) return _buildRecommendation(context, theme);
    if (ref.watch(studyMapEnabledProvider)) {
      return _buildMapBanner(context, theme);
    }
    final lesson = target.lesson;
    final isInProgress = lesson.status == 'IN_PROGRESS';
    final ctaLabel = isInProgress ? '이어하기' : '바로 시작';

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap ?? () => context.push('/study/lessons/${lesson.id}'),
        child: Container(
          padding: EdgeInsets.all(compact ? 14 : 16),
          decoration: BoxDecoration(
            color: AppColors.sakuraTrack.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primaryStrong.withValues(alpha: 0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryStrong.withValues(alpha: 0.08),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 42 : 46,
                height: compact ? 42 : 46,
                decoration: BoxDecoration(
                  color: AppColors.primaryStrong,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryStrong.withValues(alpha: 0.24),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  isInProgress ? LucideIcons.playCircle : LucideIcons.sparkles,
                  color: Colors.white,
                  size: compact ? 21 : 22,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${target.reason} · Ch.${target.chapter.chapterNo} · '
                      '${lesson.chapterLessonNo}/${target.chapter.totalLessons}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.sakuraOn,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      lesson.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColors.lightText,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${lesson.estimatedMinutes}분 · ${lesson.topic}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.lightSubtext,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.76),
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                  border: Border.all(
                    color: AppColors.primaryStrong.withValues(alpha: 0.14),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ctaLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.primaryPressed,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      LucideIcons.arrowRight,
                      size: 14,
                      color: AppColors.primaryPressed,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendation(BuildContext context, ThemeData theme) {
    final lesson = target.lesson;
    final chapter = target.chapter;
    final (heading, action) = switch (lesson.status) {
      'IN_PROGRESS' => ('이어할 레슨', '이어하기'),
      'COMPLETED' => ('다시 볼 레슨', '다시 학습'),
      _ => ('추천 레슨', '학습 시작'),
    };
    final light = theme.brightness == Brightness.light;
    final colors = theme.colorScheme;
    final foreground = light ? AppColors.redesignForeground : colors.onSurface;
    final muted = light ? const Color(0xFF505050) : colors.onSurfaceVariant;
    final metadataStyle = HaruTypography.krBody3.copyWith(color: muted);
    final location = [
      if (chapter.partNo > 1) '${chapter.partNo}부',
      '${chapter.chapterNo}번 역',
      '${lesson.chapterLessonNo}번째 레슨',
    ].join(' · ');
    final topic = lesson.topic.trim();
    final minutes = lesson.estimatedMinutes;
    final open = onTap ??
        () {
          context.push('/study/lessons/${lesson.id}');
        };

    return Column(
      key: const ValueKey('recommended-lesson'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(heading,
            style: TextStyle(
              fontFamily: redesignFontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.4,
              letterSpacing: -0.4,
              color: foreground,
            )),
        const SizedBox(height: 12),
        Material(
          color: light ? AppColors.lightCard : colors.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: light ? AppColors.redesignOutline : colors.outline,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: open,
            excludeFromSemantics: true,
            canRequestFocus: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                17,
                17,
                17,
                17 - HaruButtonStyles.compactHitInset,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 21,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: light
                                    ? AppColors.redesignVocabulary
                                    : colors.primaryContainer,
                                borderRadius:
                                    BorderRadius.circular(AppSizes.radiusFull),
                              ),
                              child: Center(
                                widthFactor: 1,
                                heightFactor: 1,
                                child: Text(
                                  chapter.jlptLevel,
                                  style: TextStyle(
                                    fontFamily: redesignFontFamily,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                    letterSpacing: -0.3,
                                    color: light
                                        ? Colors.white
                                        : colors.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ),
                            Text(location, style: metadataStyle),
                          ],
                        ),
                      ),
                      if (minutes > 0) ...[
                        const SizedBox(width: 8),
                        Image.asset(
                          'assets/icons/figma-study-recommendation-clock.png',
                          width: 14,
                          height: 14,
                          color: light ? null : muted,
                          excludeFromSemantics: true,
                        ),
                        const SizedBox(width: 3),
                        Text('$minutes분', style: metadataStyle),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(lesson.title,
                      style: HaruTypography.krTitle3.copyWith(
                        color: foreground,
                      )),
                  if (topic.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(minHeight: 33),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13.5,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: light
                            ? const Color(0xFFFEF0F2)
                            : colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Image.asset(
                            'assets/icons/home-nav-study.png',
                            width: 17,
                            color: light ? AppColors.brandPink : colors.primary,
                            excludeFromSemantics: true,
                          ),
                          const SizedBox(width: 5.5),
                          Expanded(
                            child: Text(
                              topic,
                              style: metadataStyle.copyWith(color: foreground),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12 - HaruButtonStyles.compactHitInset),
                  FilledButton(
                    key: const ValueKey('lesson-continue-action'),
                    style: HaruButtonStyles.primary(context),
                    onPressed: open,
                    child: Text(action),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapBanner(BuildContext context, ThemeData theme) {
    final lesson = target.lesson;
    final isLight = theme.brightness == Brightness.light;
    final subtext = isLight ? AppColors.lightSubtext : AppColors.darkSubtext;
    final isInProgress = lesson.status == 'IN_PROGRESS';
    final isComplete = lesson.status == 'COMPLETED';
    final label = isInProgress
        ? '이어할 레슨'
        : isComplete
            ? '다시 볼 레슨'
            : '추천 레슨';
    final action = isInProgress
        ? '이어하기'
        : isComplete
            ? '다시 학습'
            : '시작하기';
    final part = target.chapter.partNo > 1 ? '${target.chapter.partNo}부 ' : '';
    final location = '$part${target.chapter.chapterNo}번 역 · '
        '${lesson.chapterLessonNo}번째 레슨';
    void openLesson() {
      if (onTap != null) {
        onTap!();
      } else {
        context.push('/study/lessons/${lesson.id}');
      }
    }

    final actionLabel = Container(
      key: const ValueKey('lesson-continue-action'),
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: StudyMapColors.button(theme.brightness),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            action,
            style: theme.textTheme.labelLarge?.copyWith(
              color: StudyMapColors.onButton(theme.brightness),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Icon(LucideIcons.arrowRight,
              size: 18, color: StudyMapColors.onButton(theme.brightness)),
        ],
      ),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          lesson.title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${lesson.estimatedMinutes}분 · ${lesson.topic}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: subtext,
            fontSize: 13,
          ),
        ),
      ],
    );

    return Semantics(
      key: const ValueKey('lesson-continue-semantics'),
      button: true,
      onTap: openLesson,
      label: '$label, ${lesson.title}, $location, '
          '${lesson.estimatedMinutes}분, ${lesson.topic}, $action',
      child: Material(
        color: isLight ? AppColors.cardWarm : AppColors.darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: theme.colorScheme.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: openLesson,
          excludeFromSemantics: true,
          child: ExcludeSemantics(
            child: Padding(
              padding: EdgeInsets.all(compact ? 14 : 16),
              child: LayoutBuilder(builder: (context, constraints) {
                final stackAction = constraints.maxWidth < 260 ||
                    MediaQuery.textScalerOf(context).scale(14) > 18;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isComplete
                                  ? LucideIcons.rotateCcw
                                  : LucideIcons.playCircle,
                              size: 16,
                              color: StudyMapColors.icon(theme.brightness),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              label,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: StudyMapColors.accent(theme.brightness),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          location,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: subtext,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (stackAction) ...[
                      details,
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: actionLabel,
                      ),
                    ] else
                      Row(
                        children: [
                          Expanded(child: details),
                          const SizedBox(width: 14),
                          actionLabel,
                        ],
                      ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
