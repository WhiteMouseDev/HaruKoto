import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../shared/widgets/tts_play_button.dart';
import '../../data/models/lesson_models.dart';

class LessonDialogueBubble extends StatelessWidget {
  final ScriptLineModel line;
  final bool showTranslation;
  final bool isRightAligned;
  final List<String> highlights;

  const LessonDialogueBubble({
    super.key,
    required this.line,
    this.showTranslation = true,
    this.isRightAligned = false,
    this.highlights = const [],
  });

  List<TextSpan> _buildHighlightedSpans(String text, TextStyle baseStyle) {
    if (highlights.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    final pattern = highlights.map(RegExp.escape).join('|');
    final regex = RegExp(pattern);
    final spans = <TextSpan>[];
    var lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: baseStyle,
        ));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: baseStyle.copyWith(
          backgroundColor: AppColors.primary.withValues(alpha: 0.18),
          fontWeight: FontWeight.w700,
        ),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: baseStyle,
      ));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crossAxisAlignment =
        isRightAligned ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    final bubbleRadius = isRightAligned
        ? const BorderRadius.only(
            topLeft: Radius.circular(AppSizes.radiusMd),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(AppSizes.radiusMd),
            bottomRight: Radius.circular(AppSizes.radiusMd),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(AppSizes.radiusMd),
            bottomLeft: Radius.circular(AppSizes.radiusMd),
            bottomRight: Radius.circular(AppSizes.radiusMd),
          );

    final bubbleColor = isRightAligned
        ? AppColors.primary.withValues(alpha: 0.08)
        : theme.colorScheme.surfaceContainerLow;

    final bubbleBorder = isRightAligned
        ? null
        : Border.all(
            color: AppColors.primary.withValues(alpha: 0.12),
          );

    final baseTextStyle = theme.textTheme.bodyLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          height: 1.5,
          color: AppColors.lightText,
        ) ??
        const TextStyle();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.gap),
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          Text(
            line.speaker,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.primaryStrong,
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            child: Container(
              padding: const EdgeInsets.all(AppSizes.gap),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: bubbleRadius,
                border: bubbleBorder,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            children: _buildHighlightedSpans(
                              line.text,
                              baseTextStyle,
                            ),
                          ),
                        ),
                      ),
                      TtsPlayButton(text: line.text, iconSize: 16),
                    ],
                  ),
                  if (showTranslation && line.translation != null) ...[
                    const SizedBox(height: AppSizes.xs),
                    Text(
                      line.translation!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.55,
                        ),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
