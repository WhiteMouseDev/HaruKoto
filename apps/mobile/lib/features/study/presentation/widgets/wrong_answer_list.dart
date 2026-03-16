import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../data/models/quiz_result_model.dart';

class WrongAnswerList extends StatefulWidget {
  final List<WrongAnswerModel> wrongAnswers;
  final String quizType;
  final void Function(WrongAnswerModel item)? onSaveToWordbook;
  final void Function()? onSaveAll;
  final Set<String> savedWords;

  const WrongAnswerList({
    super.key,
    required this.wrongAnswers,
    required this.quizType,
    this.onSaveToWordbook,
    this.onSaveAll,
    this.savedWords = const {},
  });

  @override
  State<WrongAnswerList> createState() => _WrongAnswerListState();
}

class _WrongAnswerListState extends State<WrongAnswerList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.wrongAnswers.isEmpty) return const SizedBox.shrink();

    final allSaved = widget.wrongAnswers
        .every((w) => widget.savedWords.contains(w.questionId));

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(LucideIcons.trophy,
                      size: 16, color: AppColors.error(theme.brightness)),
                  const SizedBox(width: 8),
                  Text(
                    '틀린 ${widget.quizType == 'VOCABULARY' ? '단어' : '문법'} ${widget.wrongAnswers.length}개',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      LucideIcons.chevronDown,
                      size: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // List
          if (_expanded) ...[
            ...widget.wrongAnswers.map((item) {
              final isSaved = widget.savedWords.contains(item.questionId);
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Text(
                                  item.word,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (item.reading != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    item.reading!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (widget.quizType == 'VOCABULARY')
                            IconButton(
                              icon: Icon(
                                isSaved
                                    ? LucideIcons.check
                                    : LucideIcons.bookmarkPlus,
                                size: 16,
                                color: isSaved
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                              ),
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(4),
                              onPressed: isSaved
                                  ? null
                                  : () => widget.onSaveToWordbook?.call(item),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.meaningKo,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      if (item.exampleSentence != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.exampleSentence!,
                                  style: theme.textTheme.bodySmall),
                              if (item.exampleTranslation != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  item.exampleTranslation!,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),

            // Save all button
            if (widget.quizType == 'VOCABULARY')
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: allSaved ? null : widget.onSaveAll,
                    icon: Icon(
                      allSaved ? LucideIcons.check : LucideIcons.bookmarkPlus,
                      size: 14,
                    ),
                    label: Text(allSaved ? '모두 저장됨' : '모두 단어장에 저장'),
                  ),
                ),
              )
            else
              const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}
