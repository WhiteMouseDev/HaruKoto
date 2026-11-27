import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/theme/text_theme.dart';
import '../../data/models/word_entry_model.dart';
import 'wrong_answers_mini_stat.dart';

class WrongAnswerCard extends StatelessWidget {
  const WrongAnswerCard({
    super.key,
    required this.entry,
    required this.expanded,
    required this.saved,
    required this.onTap,
    required this.onSaveToWordbook,
  });

  final WrongEntryModel entry;
  final bool expanded;
  final bool saved;
  final VoidCallback onTap;
  final Future<void> Function() onSaveToWordbook;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final light = colors.brightness == Brightness.light;
    final border = light ? AppColors.redesignOutline : colors.outlineVariant;
    const radius = BorderRadius.all(Radius.circular(12));

    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: border),
        borderRadius: radius,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Semantics(
            expanded: expanded,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, expanded ? 7 : 16),
                child: _WrongAnswerCardHeader(entry: entry, expanded: expanded),
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _WrongAnswerCardDetail(
                entry: entry,
                saved: saved,
                onSaveToWordbook: onSaveToWordbook,
              ),
            ),
        ],
      ),
    );
  }
}

class _WrongAnswerCardHeader extends StatelessWidget {
  const _WrongAnswerCardHeader({
    required this.entry,
    required this.expanded,
  });

  final WrongEntryModel entry;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final light = colors.brightness == Brightness.light;
    final foreground = light ? AppColors.redesignForeground : colors.onSurface;
    final secondary = light ? const Color(0xFF505050) : colors.onSurfaceVariant;

    return Row(
      crossAxisAlignment:
          expanded ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Semantics(
                  label: entry.mastered ? '학습 완료' : '학습 중',
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: entry.mastered
                          ? AppColors.redesignSentence
                          : AppColors.redesignGrammar,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const SizedBox.square(dimension: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          entry.word,
                          style: TextStyle(
                            fontFamily: redesignJapaneseFontFamily,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                            color: foreground,
                          ),
                        ),
                        if (entry.reading.isNotEmpty)
                          Text(
                            entry.reading,
                            style: TextStyle(
                              fontFamily: redesignJapaneseFontFamily,
                              fontSize: 12,
                              height: 1.5,
                              color: secondary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3.5),
                    Text(
                      entry.meaningKo,
                      maxLines: expanded ? null : 1,
                      overflow: expanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: redesignFontFamily,
                        fontSize: 14,
                        height: 1.5,
                        color: foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (!expanded) ...[
          Semantics(
            label: '오답 ${entry.incorrectCount}회',
            excludeSemantics: true,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: light
                    ? const Color(0xFFFAE6E6)
                    : colors.error.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  child: Text(
                    '${entry.incorrectCount}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: redesignFontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                      color: light ? const Color(0xFFD32F2F) : colors.error,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Icon(
          expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
          size: 16,
          color: secondary,
        ),
      ],
    );
  }
}

class _WrongAnswerCardDetail extends StatelessWidget {
  const _WrongAnswerCardDetail({
    required this.entry,
    required this.saved,
    required this.onSaveToWordbook,
  });

  final WrongEntryModel entry;
  final bool saved;
  final Future<void> Function() onSaveToWordbook;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final light = colors.brightness == Brightness.light;
    final foreground = light ? AppColors.redesignForeground : colors.onSurface;
    final secondary =
        light ? AppColors.redesignMutedForeground : colors.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color:
                light ? AppColors.redesignSurface : colors.surfaceContainerHigh,
            border: Border.all(
              color: light ? AppColors.redesignOutline : colors.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WrongAnswersMiniStat(
                  label: '오답',
                  value: entry.incorrectCount,
                  unit: '회',
                  isError: true,
                ),
                WrongAnswersMiniStat(
                  label: '정답률',
                  value: entry.accuracy,
                  unit: '%',
                ),
                WrongAnswersMiniStat(
                  label: '총 풀이',
                  value: entry.totalAttempts,
                  unit: '회',
                ),
              ],
            ),
          ),
        ),
        if (entry.exampleSentence case final example?) ...[
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: _highlightedExample(
                example,
                entry.word,
                light ? AppColors.sakura : colors.primary,
              ),
            ),
            style: TextStyle(
              fontFamily: redesignJapaneseFontFamily,
              fontSize: 14,
              height: 1.5,
              color: foreground,
            ),
          ),
          if (entry.exampleTranslation case final translation?)
            Text(
              translation,
              style: TextStyle(
                fontFamily: redesignFontFamily,
                fontSize: 12,
                height: 1.5,
                color: secondary,
              ),
            ),
        ],
        const SizedBox(height: 4),
        Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: light
                    ? AppColors.redesignVocabulary
                    : colors.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  entry.jlptLevel,
                  style: TextStyle(
                    fontFamily: redesignFontFamily,
                    fontSize: 11,
                    color: light ? Colors.white : colors.onPrimaryContainer,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: _SaveToWordbookButton(
                  saved: saved,
                  onSave: onSaveToWordbook,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SaveToWordbookButton extends StatefulWidget {
  const _SaveToWordbookButton({required this.saved, required this.onSave});

  final bool saved;
  final Future<void> Function() onSave;

  @override
  State<_SaveToWordbookButton> createState() => _SaveToWordbookButtonState();
}

class _SaveToWordbookButtonState extends State<_SaveToWordbookButton> {
  bool _saving = false;

  Future<void> _save() async {
    if (_saving || widget.saved) return;
    setState(() => _saving = true);
    try {
      await widget.onSave();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final light = colors.brightness == Brightness.light;
    final secondary =
        light ? AppColors.redesignMutedForeground : colors.onSurfaceVariant;
    final border = light ? AppColors.redesignOutline : colors.outlineVariant;

    return OutlinedButton.icon(
      onPressed: _saving || widget.saved ? null : _save,
      icon: Icon(
        widget.saved ? LucideIcons.check : LucideIcons.bookmark,
        size: 14,
      ),
      label: Text(
        widget.saved
            ? '단어장에 추가됨'
            : _saving
                ? '저장 중'
                : '단어장에 추가',
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor:
            light ? AppColors.redesignForeground : colors.onSurface,
        disabledForegroundColor: secondary,
        side: BorderSide(color: border),
        shape: const StadiumBorder(),
        minimumSize: const Size(0, 28),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        visualDensity: VisualDensity.standard,
        tapTargetSize: MaterialTapTargetSize.padded,
        textStyle:
            const TextStyle(fontFamily: redesignFontFamily, fontSize: 12),
      ),
    );
  }
}

List<InlineSpan> _highlightedExample(String example, String word, Color color) {
  if (word.isEmpty) return [TextSpan(text: example)];
  final parts = example.split(word);
  return [
    TextSpan(text: parts.first),
    for (final part in parts.skip(1)) ...[
      TextSpan(text: word, style: TextStyle(color: color)),
      TextSpan(text: part),
    ],
  ];
}
