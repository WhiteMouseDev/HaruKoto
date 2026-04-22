import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../data/models/word_entry_model.dart';
import 'wrong_answers_mini_stat.dart';

class WrongAnswerCard extends StatelessWidget {
  final WrongEntryModel entry;
  final bool expanded;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback onSaveToWordbook;

  const WrongAnswerCard({
    super.key,
    required this.entry,
    required this.expanded,
    required this.saved,
    required this.onTap,
    required this.onSaveToWordbook,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outline),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _WrongAnswerCardHeader(entry: entry, expanded: expanded),
              if (expanded)
                _WrongAnswerCardDetail(
                  entry: entry,
                  saved: saved,
                  onSaveToWordbook: onSaveToWordbook,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WrongAnswerCardHeader extends StatelessWidget {
  final WrongEntryModel entry;
  final bool expanded;

  const _WrongAnswerCardHeader({
    required this.entry,
    required this.expanded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.error(theme.brightness).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '${entry.incorrectCount}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.error(theme.brightness),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    entry.word,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    entry.reading,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
              Text(
                entry.meaningKo,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        _MasteryBadge(mastered: entry.mastered),
        const SizedBox(width: 4),
        AnimatedRotation(
          turns: expanded ? 0.5 : 0,
          duration: const Duration(milliseconds: 200),
          child: Icon(
            LucideIcons.chevronDown,
            size: 16,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

class _MasteryBadge extends StatelessWidget {
  final bool mastered;

  const _MasteryBadge({required this.mastered});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = mastered
        ? theme.colorScheme.primary
        : AppColors.error(theme.brightness);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        mastered ? '극복' : '학습중',
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _WrongAnswerCardDetail extends StatelessWidget {
  final WrongEntryModel entry;
  final bool saved;
  final VoidCallback onSaveToWordbook;

  const _WrongAnswerCardDetail({
    required this.entry,
    required this.saved,
    required this.onSaveToWordbook,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        const SizedBox(height: 12),
        Divider(color: theme.colorScheme.outline, height: 1),
        const SizedBox(height: 12),
        Row(
          children: [
            WrongAnswersMiniStat(
              label: '오답',
              value: '${entry.incorrectCount}회',
              isError: true,
            ),
            const SizedBox(width: 8),
            WrongAnswersMiniStat(label: '정답률', value: '${entry.accuracy}%'),
            const SizedBox(width: 8),
            WrongAnswersMiniStat(
                label: '총 풀이', value: '${entry.totalAttempts}회'),
          ],
        ),
        if (entry.exampleSentence != null) _ExampleSentence(entry: entry),
        const SizedBox(height: 8),
        Row(
          children: [
            _JlptLevelBadge(level: entry.jlptLevel),
            const Spacer(),
            _SaveToWordbookButton(
              saved: saved,
              onTap: onSaveToWordbook,
            ),
          ],
        ),
      ],
    );
  }
}

class _ExampleSentence extends StatelessWidget {
  final WrongEntryModel entry;

  const _ExampleSentence({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.exampleSentence!, style: theme.textTheme.bodySmall),
              if (entry.exampleTranslation != null) ...[
                const SizedBox(height: 4),
                Text(
                  entry.exampleTranslation!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _JlptLevelBadge extends StatelessWidget {
  final String level;

  const _JlptLevelBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(level, style: theme.textTheme.labelSmall),
    );
  }
}

class _SaveToWordbookButton extends StatelessWidget {
  final bool saved;
  final VoidCallback onTap;

  const _SaveToWordbookButton({
    required this.saved,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: saved
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              saved ? LucideIcons.check : LucideIcons.bookmarkPlus,
              size: 12,
              color: saved
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 4),
            Text(
              saved ? '저장됨' : '단어장에 추가',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
