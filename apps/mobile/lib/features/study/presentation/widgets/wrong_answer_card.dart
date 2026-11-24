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
    const radius = BorderRadius.all(Radius.circular(8));

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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: _WrongAnswerCardHeader(entry: entry, expanded: expanded),
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
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
    final secondary =
        light ? AppColors.redesignMutedForeground : colors.onSurfaceVariant;

    return Row(
      children: [
        Semantics(
          label: entry.mastered ? '학습 완료' : '학습 중',
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: entry.mastered
                  ? AppColors.redesignSentence
                  : AppColors.redesignGrammar,
              shape: BoxShape.circle,
            ),
            child: const SizedBox.square(dimension: 7),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 5,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    entry.word,
                    style: TextStyle(
                      fontFamily: redesignFontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: foreground,
                    ),
                  ),
                  if (entry.reading.isNotEmpty)
                    Text(
                      entry.reading,
                      style: TextStyle(
                        fontFamily: redesignFontFamily,
                        fontSize: 11,
                        color: secondary,
                      ),
                    ),
                ],
              ),
              Text(
                entry.meaningKo,
                style: TextStyle(
                  fontFamily: redesignFontFamily,
                  fontSize: 12,
                  color: secondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Semantics(
          label: '오답 ${entry.incorrectCount}회',
          excludeSemantics: true,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: light
                  ? AppColors.sakuraTrack
                  : colors.error.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              child: Text(
                '${entry.incorrectCount}',
                style: TextStyle(
                  fontFamily: redesignFontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: light ? AppColors.sakuraOn : colors.error,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
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
        DecoratedBox(
          decoration: BoxDecoration(
            color:
                light ? AppColors.redesignSurface : colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WrongAnswersMiniStat(
                  label: '오답',
                  value: '${entry.incorrectCount}회',
                  isError: true,
                ),
                WrongAnswersMiniStat(label: '정답률', value: '${entry.accuracy}%'),
                WrongAnswersMiniStat(
                  label: '총 풀이',
                  value: '${entry.totalAttempts}회',
                ),
              ],
            ),
          ),
        ),
        if (entry.exampleSentence case final example?) ...[
          const SizedBox(height: 8),
          Text(
            example,
            style: TextStyle(
              fontFamily: redesignFontFamily,
              fontSize: 13,
              color: foreground,
            ),
          ),
          if (entry.exampleTranslation case final translation?)
            Text(
              translation,
              style: TextStyle(
                fontFamily: redesignFontFamily,
                fontSize: 11,
                color: secondary,
              ),
            ),
        ],
        const SizedBox(height: 6),
        Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: light ? AppColors.sakuraTrack : colors.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  entry.jlptLevel,
                  style: TextStyle(
                    fontFamily: redesignFontFamily,
                    fontSize: 11,
                    color:
                        light ? AppColors.sakuraOn : colors.onPrimaryContainer,
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
        widget.saved ? LucideIcons.check : LucideIcons.bookmarkPlus,
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
        foregroundColor: secondary,
        disabledForegroundColor: secondary,
        side: BorderSide(color: border),
        shape: const StadiumBorder(),
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        visualDensity: VisualDensity.standard,
        tapTargetSize: MaterialTapTargetSize.padded,
        textStyle:
            const TextStyle(fontFamily: redesignFontFamily, fontSize: 12),
      ),
    );
  }
}
