import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/theme/text_theme.dart';
import '../../data/models/lesson_models.dart';
import '../study_map_colors.dart';

/// Flexible lesson row for stations; the legacy LessonTile stays unchanged.
class LessonStationTile extends StatelessWidget {
  const LessonStationTile({
    super.key,
    required this.lesson,
    required this.isRecommended,
    this.redesigned = false,
  });

  final LessonSummaryModel lesson;
  final bool isRecommended;
  final bool redesigned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final complete = lesson.status == 'COMPLETED';
    final inProgress = lesson.status == 'IN_PROGRESS';
    final accent = StudyMapColors.accent(theme.brightness);
    final doneColor = isLight ? AppColors.mintOn : AppColors.mintContainer;
    final subtext = isLight
        ? redesigned
            ? const Color(0xFF505050)
            : AppColors.lightSubtext
        : AppColors.darkSubtext;
    final showScore = complete && lesson.scoreTotal > 0;
    final action = complete
        ? '다시 학습'
        : inProgress
            ? '이어하기'
            : '학습 시작';

    return Padding(
      padding: EdgeInsets.only(top: redesigned ? 0 : 6),
      child: Material(
        color: redesigned
            ? isLight
                ? AppColors.redesignSurface
                : theme.colorScheme.surfaceContainerHigh
            : isRecommended
                ? StudyMapColors.panel(theme.brightness)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: ValueKey('station-lesson-${lesson.id}'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push('/study/lessons/${lesson.id}'),
          child: Semantics(
            hint: redesigned ? action : null,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: redesigned
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  if (!redesigned) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        complete
                            ? LucideIcons.checkCircle2
                            : inProgress
                                ? LucideIcons.playCircle
                                : LucideIcons.circle,
                        color: complete
                            ? doneColor
                            : isRecommended
                                ? accent
                                : subtext,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (redesigned)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 6,
                                height:
                                    MediaQuery.textScalerOf(context).scale(14) *
                                        1.5,
                                child: Center(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: inProgress || complete
                                          ? isLight
                                              ? AppColors.brandPink
                                              : accent
                                          : isLight
                                              ? const Color(0xFFA5A5AF)
                                              : subtext,
                                    ),
                                    child: const SizedBox.square(dimension: 6),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  lesson.title,
                                  style: TextStyle(
                                    color: isLight
                                        ? AppColors.redesignForeground
                                        : theme.colorScheme.onSurface,
                                    fontFamily: redesignFontFamily,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    height: 1.5,
                                    letterSpacing: -0.35,
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            lesson.title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: isRecommended
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                        SizedBox(height: redesigned ? 2 : 4),
                        Padding(
                          padding: EdgeInsets.only(left: redesigned ? 12 : 0),
                          child: Text(
                            redesigned
                                ? '${lesson.topic} · ${lesson.estimatedMinutes}분'
                                : '${lesson.estimatedMinutes}분 · ${lesson.topic}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: subtext,
                              fontFamily:
                                  redesigned ? redesignFontFamily : null,
                              fontSize: redesigned ? 12 : null,
                              fontWeight: redesigned ? FontWeight.w400 : null,
                              height: redesigned ? 1.5 : null,
                              letterSpacing: redesigned ? -0.3 : null,
                            ),
                          ),
                        ),
                        if (!redesigned || showScore) ...[
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (showScore)
                                Padding(
                                  padding: EdgeInsets.only(
                                      left: redesigned ? 12 : 0),
                                  child: Text(
                                    '${lesson.scoreCorrect}/${lesson.scoreTotal} 정답',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: doneColor,
                                    ),
                                  ),
                                ),
                              if (!redesigned)
                                Container(
                                  padding: isRecommended
                                      ? const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        )
                                      : EdgeInsets.zero,
                                  decoration: isRecommended
                                      ? BoxDecoration(
                                          color: StudyMapColors.button(
                                              theme.brightness),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        )
                                      : null,
                                  child: Text(
                                    action,
                                    style:
                                        theme.textTheme.labelMedium?.copyWith(
                                      color: isRecommended
                                          ? StudyMapColors.onButton(
                                              theme.brightness)
                                          : subtext,
                                      fontWeight: isRecommended
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (redesigned)
                    Image.asset(
                      'assets/icons/figma-home-arrow.png',
                      width: 6.25,
                      height: 11,
                      color: isLight ? const Color(0xFF545461) : subtext,
                      excludeFromSemantics: true,
                    )
                  else
                    Icon(
                      LucideIcons.chevronRight,
                      size: 16,
                      color: isRecommended ? accent : subtext,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
