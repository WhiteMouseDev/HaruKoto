import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../data/models/lesson_models.dart';
import '../study_map_colors.dart';

/// Flexible lesson row for stations; the legacy LessonTile stays unchanged.
class LessonStationTile extends StatelessWidget {
  const LessonStationTile({
    super.key,
    required this.lesson,
    required this.isRecommended,
  });

  final LessonSummaryModel lesson;
  final bool isRecommended;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final complete = lesson.status == 'COMPLETED';
    final inProgress = lesson.status == 'IN_PROGRESS';
    final accent = StudyMapColors.accent(theme.brightness);
    final doneColor = isLight ? AppColors.mintOn : AppColors.mintContainer;
    final subtext = isLight ? AppColors.lightSubtext : AppColors.darkSubtext;
    final action = complete
        ? '다시 학습'
        : inProgress
            ? '이어하기'
            : '학습 시작';

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: isRecommended
            ? StudyMapColors.panel(theme.brightness)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: ValueKey('station-lesson-${lesson.id}'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push('/study/lessons/${lesson.id}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lesson.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight:
                              isRecommended ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${lesson.estimatedMinutes}분 · ${lesson.topic}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: subtext,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (complete && lesson.scoreTotal > 0)
                            Text(
                              '${lesson.scoreCorrect}/${lesson.scoreTotal} 정답',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: doneColor,
                              ),
                            ),
                          Container(
                            padding: isRecommended
                                ? const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  )
                                : EdgeInsets.zero,
                            decoration: isRecommended
                                ? BoxDecoration(
                                    color:
                                        StudyMapColors.button(theme.brightness),
                                    borderRadius: BorderRadius.circular(8),
                                  )
                                : null,
                            child: Text(
                              action,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: isRecommended
                                    ? StudyMapColors.onButton(theme.brightness)
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
                  ),
                ),
                const SizedBox(width: 4),
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
    );
  }
}
