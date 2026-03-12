import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';

class ChatInputBar extends StatefulWidget {
  final ValueChanged<String> onSend;
  final VoidCallback onHint;
  final String? hint;
  final bool disabled;

  const ChatInputBar({
    super.key,
    required this.onSend,
    required this.onHint,
    this.hint,
    this.disabled = false,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.disabled) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Hint display
        if (widget.hint != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.hkYellowLight.withValues(alpha: 0.1),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.hkYellowLight.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.lightbulb,
                    size: 14, color: AppColors.hkYellowLight),
                const SizedBox(width: 4),
                Text(
                  '힌트: ',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Expanded(
                  child: Text(
                    widget.hint!,
                    style: theme.textTheme.labelSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

        // Input bar
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.sm, vertical: AppSizes.sm),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.1),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                // Hint button
                IconButton(
                  onPressed: widget.disabled ? null : widget.onHint,
                  icon: Icon(LucideIcons.lightbulb,
                      size: 20, color: AppColors.hkYellowLight),
                ),

                // Text input
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    enabled: !widget.disabled,
                    maxLines: 3,
                    minLines: 1,
                    style: theme.textTheme.bodySmall,
                    decoration: InputDecoration(
                      hintText: '일본어로 입력하세요...',
                      hintStyle: theme.textTheme.bodySmall?.copyWith(
                        color:
                            colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      filled: true,
                      fillColor: colorScheme.secondaryContainer
                          .withValues(alpha: 0.3),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusMd),
                        borderSide: BorderSide(
                          color:
                              colorScheme.outline.withValues(alpha: 0.15),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusMd),
                        borderSide: BorderSide(
                          color:
                              colorScheme.outline.withValues(alpha: 0.15),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusMd),
                        borderSide: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),

                const SizedBox(width: 4),

                // Send button
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (_, value, __) {
                    final canSend =
                        value.text.trim().isNotEmpty && !widget.disabled;
                    return IconButton(
                      onPressed: canSend ? _handleSend : null,
                      style: IconButton.styleFrom(
                        backgroundColor: canSend
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.3),
                        shape: const CircleBorder(),
                      ),
                      icon: Icon(LucideIcons.send,
                          size: 16,
                          color: canSend ? AppColors.onGradient : AppColors.onGradient.withValues(alpha: 0.54)),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
