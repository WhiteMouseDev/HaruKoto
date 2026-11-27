import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';

class MySettingsToggleTile extends StatelessWidget {
  const MySettingsToggleTile({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final Widget leading;
  final Widget title;
  final Widget? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final light = colors.brightness == Brightness.light;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    final selectedTrack = light ? AppColors.redesignVocabulary : colors.primary;
    final subtitle = this.subtitle;

    return MergeSemantics(
      child: ListTile(
        leading: leading,
        // Keep both labels in one slot so ListTile centers the group and
        // honors the settings row height even with a second line.
        title: subtitle == null
            ? title
            : Transform.translate(
                // Align the Pretendard glyphs with the switch center.
                offset: const Offset(0, -1.5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: 2),
                    DefaultTextStyle.merge(
                      style: ListTileTheme.of(context).subtitleTextStyle ??
                          theme.textTheme.bodyMedium,
                      child: subtitle,
                    ),
                  ],
                ),
              ),
        onTap: () => onChanged(!value),
        trailing: Stack(
          alignment: AlignmentDirectional.centerEnd,
          children: [
            // Keep the platform switch's drag, hit area and toggled semantics.
            // The ListTile owns keyboard focus, as it does in SwitchListTile.
            ExcludeFocus(
              child: Opacity(
                opacity: 0,
                alwaysIncludeSemantics: true,
                child: Switch(
                  value: value,
                  onChanged: onChanged,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
            IgnorePointer(
              child: AnimatedContainer(
                duration: duration,
                width: 50,
                height: 28,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: value ? selectedTrack : colors.surfaceContainerHighest,
                ),
                child: AnimatedAlign(
                  duration: duration,
                  alignment: value
                      ? AlignmentDirectional.centerEnd
                      : AlignmentDirectional.centerStart,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: value
                          ? (light ? Colors.white : colors.onPrimary)
                          : colors.outline,
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox.square(dimension: 24),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
