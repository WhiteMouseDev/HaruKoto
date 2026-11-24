import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/theme/text_theme.dart';
import '../../../../shared/widgets/tts_play_button.dart';
import '../../data/models/quiz_result_model.dart';
import 'quiz_result_wrong_icon.dart';

class WrongAnswerList extends StatefulWidget {
  final List<WrongAnswerModel> wrongAnswers;
  final String quizType;
  final void Function(WrongAnswerModel item)? onSaveToWordbook;
  final void Function()? onSaveAll;
  final Set<String> savedWords;
  final bool redesigned;

  const WrongAnswerList({
    super.key,
    required this.wrongAnswers,
    required this.quizType,
    this.onSaveToWordbook,
    this.onSaveAll,
    this.savedWords = const {},
    this.redesigned = false,
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
    final light = theme.brightness == Brightness.light;
    final redesigned = widget.redesigned;
    final foreground = redesigned && light
        ? AppColors.redesignForeground
        : theme.colorScheme.onSurface;
    final muted = redesigned && light
        ? AppColors.redesignMutedForeground
        : theme.colorScheme.onSurfaceVariant;
    final outline = redesigned && light
        ? AppColors.redesignOutline
        : theme.colorScheme.outline;
    final audioColor = redesigned
        ? (light ? AppColors.brandPink : theme.colorScheme.primary)
        : null;
    final corners = BorderRadius.circular(redesigned ? 12 : 24);
    final answerLabel =
        redesigned ? '문제' : (widget.quizType == 'GRAMMAR' ? '문법' : '단어');

    final allSaved = widget.wrongAnswers
        .every((w) => widget.savedWords.contains(w.questionId));

    return Container(
      decoration: BoxDecoration(
        color: redesigned && light ? Colors.white : theme.colorScheme.surface,
        border: Border.all(color: outline),
        borderRadius: corners,
      ),
      child: Column(
        children: [
          // Header
          Material(
            type: MaterialType.transparency,
            child: Semantics(
              expanded: _expanded,
              child: InkWell(
                borderRadius: corners,
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      if (redesigned)
                        const QuizResultWrongIcon(size: 20)
                      else
                        Icon(LucideIcons.trophy,
                            size: 16, color: AppColors.error(theme.brightness)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '틀린 $answerLabel ${widget.wrongAnswers.length}개',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontFamily: redesigned ? redesignFontFamily : null,
                            color: foreground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 200),
                        child: Icon(LucideIcons.chevronDown,
                            size: 16, color: muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // List
          if (_expanded) ...[
            ...widget.wrongAnswers.map((item) {
              final isSaved = widget.savedWords.contains(item.questionId);
              return Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 16, vertical: redesigned ? 0 : 4),
                child: Container(
                  padding: redesigned
                      ? const EdgeInsets.symmetric(vertical: 10)
                      : const EdgeInsets.all(12),
                  decoration: redesigned
                      ? BoxDecoration(
                          border: Border(top: BorderSide(color: outline)),
                        )
                      : BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                        ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      item.word,
                                      style:
                                          theme.textTheme.bodyLarge?.copyWith(
                                        color: foreground,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (item.reading case final reading?)
                                      Text(
                                        reading,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(color: muted),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.meaningKo,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: muted,
                                    fontFamily:
                                        redesigned ? redesignFontFamily : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TtsPlayButton(
                            vocabId: item.questionId,
                            iconSize: redesigned ? 24 : 16,
                            iconColor: audioColor,
                          ),
                          if (widget.quizType == 'VOCABULARY')
                            IconButton(
                              tooltip: isSaved ? '단어장에 저장됨' : '단어장에 저장',
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
