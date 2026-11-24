import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/theme/text_theme.dart';
import '../../../../shared/widgets/tts_play_button.dart';
import '../../../../core/services/tts_service.dart';
import '../../data/models/lesson_models.dart';

final _kanaTtsTextPattern =
    RegExp(r'^[\u3040-\u309F\u30A0-\u30FF\u3000-\u303F\uFF66-\uFF9F]+$');
final _kanjiPattern = RegExp(r'[\u4E00-\u9FFF]');

class LessonDialogueBubble extends StatelessWidget {
  final TtsService? ttsService;
  final ScriptLineModel line;
  final String? lessonId;
  final int? scriptLineIndex;
  final bool showTranslation;
  final bool isRightAligned;
  final bool audioBelow;
  final List<String> highlights;

  const LessonDialogueBubble({
    super.key,
    this.ttsService,
    required this.line,
    this.lessonId,
    this.scriptLineIndex,
    this.showTranslation = true,
    this.isRightAligned = false,
    this.audioBelow = false,
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

  bool _canUseKanaTts(String text) {
    final normalized = text.trim();
    return normalized.isNotEmpty &&
        normalized.length <= 10 &&
        !_kanjiPattern.hasMatch(normalized) &&
        _kanaTtsTextPattern.hasMatch(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final light = theme.brightness == Brightness.light;
    final crossAxisAlignment =
        isRightAligned ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final hasLessonScriptTarget = lessonId != null && scriptLineIndex != null;
    final translation = line.translation?.trim();
    final translated = showTranslation &&
        translation != null &&
        (!audioBelow || translation.isNotEmpty);

    final reviewRadius = isRightAligned
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

    final baseTextStyle = theme.textTheme.bodyLarge?.copyWith(
          fontFamily: audioBelow ? redesignFontFamily : null,
          fontSize: audioBelow ? 15 : 18,
          fontWeight: FontWeight.w500,
          height: 1.5,
          color: light ? AppColors.redesignForeground : colors.onSurface,
        ) ??
        const TextStyle();
    final originalText = RichText(
      textScaler: MediaQuery.textScalerOf(context),
      text:
          TextSpan(children: _buildHighlightedSpans(line.text, baseTextStyle)),
    );
    final audio = hasLessonScriptTarget
        ? TtsPlayButton(
            lessonId: lessonId,
            ttsService: ttsService,
            scriptLineIndex: scriptLineIndex,
            iconSize: AppSizes.iconSm,
            iconColor: audioBelow ? AppColors.brandPink : null,
          )
        : _canUseKanaTts(line.text)
            ? TtsPlayButton(
                text: line.text.trim(),
                iconSize: AppSizes.iconSm,
                iconColor: audioBelow ? AppColors.brandPink : null,
                ttsService: ttsService,
              )
            : null;
    final textContent = Column(
      crossAxisAlignment:
          audioBelow ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
      children: [
        if (audioBelow)
          originalText
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(child: originalText), if (audio != null) audio],
          ),
        if (translated) ...[
          if (audioBelow)
            Divider(
              height: AppSizes.md,
              thickness: 1,
              color: light ? AppColors.redesignOutline : colors.outlineVariant,
            )
          else
            const SizedBox(height: AppSizes.xs),
          Text(
            audioBelow ? translation : line.translation!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontFamily: audioBelow ? redesignFontFamily : null,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.gap),
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          Text(
            line.speaker,
            style: theme.textTheme.labelSmall?.copyWith(
              fontFamily: audioBelow ? redesignFontFamily : null,
              color: audioBelow ? colors.onSurface : AppColors.primaryStrong,
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
            ),
            child: Container(
              padding: const EdgeInsets.all(AppSizes.gap),
              decoration: BoxDecoration(
                color: isRightAligned
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : audioBelow && light
                        ? AppColors.redesignControl
                        : colors.surfaceContainerLow,
                borderRadius:
                    audioBelow ? BorderRadius.circular(12) : reviewRadius,
                border: isRightAligned || audioBelow
                    ? null
                    : Border.all(
                        color: AppColors.primary.withValues(alpha: 0.12)),
              ),
              child:
                  audioBelow ? IntrinsicWidth(child: textContent) : textContent,
            ),
          ),
          if (audioBelow && audio != null)
            SizedBox.square(
              dimension: AppSizes.buttonHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerLowest,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: light
                              ? AppColors.redesignOutline
                              : colors.outlineVariant,
                        ),
                      ),
                    ),
                  ),
                  audio,
                ],
              ),
            ),
        ],
      ),
    );
  }
}
