import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../data/models/chat_message_model.dart';

class ChatBubble extends StatefulWidget {
  final String role;
  final String messageJa;
  final String? messageKo;
  final List<MessageFeedback>? feedback;
  final bool showTranslation;

  const ChatBubble({
    super.key,
    required this.role,
    required this.messageJa,
    this.messageKo,
    this.feedback,
    this.showTranslation = true,
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  bool _showFeedback = false;

  bool get _isAI => widget.role == 'ai';
  bool get _hasFeedback =>
      widget.feedback != null && widget.feedback!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;

    return Align(
      alignment: _isAI ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        child: Column(
          crossAxisAlignment:
              _isAI ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            if (_isAI)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'AI',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _isAI ? colorScheme.surface : AppColors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(_isAI ? 4 : 16),
                  bottomRight: Radius.circular(_isAI ? 16 : 4),
                ),
                border: _isAI
                    ? Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.1))
                    : null,
                boxShadow: _isAI
                    ? [
                        BoxShadow(
                          color: AppColors.overlay(0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.messageJa,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          _isAI ? colorScheme.onSurface : AppColors.onGradient,
                      height: 1.5,
                    ),
                  ),
                  if (widget.showTranslation &&
                      widget.messageKo != null &&
                      widget.messageKo!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: _isAI
                                ? colorScheme.outline.withValues(alpha: 0.15)
                                : AppColors.onGradient.withValues(alpha: 0.3),
                            style: BorderStyle.solid,
                          ),
                        ),
                      ),
                      child: Text(
                        widget.messageKo!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: _isAI
                              ? colorScheme.onSurface.withValues(alpha: 0.5)
                              : AppColors.onGradient.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Feedback for user messages
            if (!_isAI && _hasFeedback) ...[
              const SizedBox(height: 6),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _showFeedback = !_showFeedback),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.alertCircle,
                        size: 12, color: AppColors.hkBlueLight),
                    const SizedBox(width: 4),
                    Text(
                      '교정 ${widget.feedback!.length}건',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.hkBlueLight,
                      ),
                    ),
                    Icon(
                      _showFeedback
                          ? LucideIcons.chevronUp
                          : LucideIcons.chevronDown,
                      size: 12,
                      color: AppColors.hkBlueLight,
                    ),
                  ],
                ),
              ),
              if (_showFeedback)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.hkBlueLight.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: widget.feedback!
                        .map((fb) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fb.original,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: AppColors.hkRedLight,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                  Text(
                                    '-> ${fb.correction}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: AppColors.success(brightness),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    fb.explanationKo,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
