import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../data/models/feedback_model.dart';

class FeedbackTranscriptWidget extends StatefulWidget {
  final List<TranslatedMessage> translatedTranscript;
  final List<GrammarCorrection> corrections;

  const FeedbackTranscriptWidget({
    super.key,
    required this.translatedTranscript,
    required this.corrections,
  });

  @override
  State<FeedbackTranscriptWidget> createState() =>
      _FeedbackTranscriptWidgetState();
}

class _FeedbackTranscriptWidgetState extends State<FeedbackTranscriptWidget> {
  bool _showTranslation = false;

  GrammarCorrection? _findCorrection(String text) {
    try {
      return widget.corrections.firstWhere(
        (c) => text.contains(c.original) || c.original.contains(text),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.messageSquare,
                        size: 16, color: AppColors.hkBlueLight),
                    const SizedBox(width: AppSizes.sm),
                    Text(
                      '대화 내역',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _showTranslation = !_showTranslation),
                  icon: Icon(LucideIcons.languages,
                      size: 14, color: colorScheme.onSurface),
                  label: Text(
                    _showTranslation ? '원문만' : '번역 보기',
                    style: theme.textTheme.labelSmall,
                  ),
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sm),

            // Messages
            ...widget.translatedTranscript.map((msg) {
              final isUser = msg.role == 'user';
              final correction = isUser ? _findCorrection(msg.ja) : null;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    child: Column(
                      crossAxisAlignment: isUser
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        if (!isUser)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '하루',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isUser
                                ? AppColors.primary
                                : colorScheme.surface,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(isUser ? 16 : 4),
                              bottomRight: Radius.circular(isUser ? 4 : 16),
                            ),
                            border: isUser
                                ? null
                                : Border.all(
                                    color: colorScheme.outline
                                        .withValues(alpha: 0.1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg.ja,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isUser
                                      ? AppColors.onGradient
                                      : colorScheme.onSurface,
                                  height: 1.5,
                                ),
                              ),
                              if (_showTranslation && msg.ko.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  msg.ko,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: isUser
                                        ? AppColors.onGradient
                                            .withValues(alpha: 0.6)
                                        : colorScheme.onSurface
                                            .withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (correction != null)
                          _CorrectionToggle(correction: correction),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _CorrectionToggle extends StatefulWidget {
  final GrammarCorrection correction;

  const _CorrectionToggle({required this.correction});

  @override
  State<_CorrectionToggle> createState() => _CorrectionToggleState();
}

class _CorrectionToggleState extends State<_CorrectionToggle> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        GestureDetector(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.edit,
                    size: 12,
                    color: AppColors.warning(Theme.of(context).brightness)),
                const SizedBox(width: 4),
                Text(
                  '교정 있음',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.warning(Theme.of(context).brightness),
                  ),
                ),
                Icon(
                  _open ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  size: 12,
                  color: AppColors.warning(Theme.of(context).brightness),
                ),
              ],
            ),
          ),
        ),
        if (_open)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.overlay(0.05),
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.correction.original,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.hkRedLight,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                Text(
                  widget.correction.corrected,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.success(Theme.of(context).brightness),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.correction.explanation,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
