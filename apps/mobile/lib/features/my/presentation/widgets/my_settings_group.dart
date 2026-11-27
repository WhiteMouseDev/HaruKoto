import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/theme/text_theme.dart';

class MySettingsGroup extends StatelessWidget {
  const MySettingsGroup({super.key, required this.label, required this.rows});

  final String label;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final foreground =
        light ? AppColors.redesignForeground : theme.colorScheme.onSurface;
    final outline =
        light ? AppColors.redesignOutline : theme.colorScheme.outline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontFamily: redesignFontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.4,
              letterSpacing: -0.4,
              color: foreground,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: theme.colorScheme.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: outline),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: ListTileTheme(
              data: ListTileTheme.of(context).copyWith(
                contentPadding: const EdgeInsets.symmetric(horizontal: 17),
                minLeadingWidth: 24,
                horizontalTitleGap: 8,
                minTileHeight: 56,
                titleTextStyle: TextStyle(
                  fontFamily: redesignFontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: foreground,
                  height: 1.5,
                  letterSpacing: -0.35,
                ),
                subtitleTextStyle: TextStyle(
                  fontFamily: redesignFontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: light
                      ? AppColors.redesignMutedForeground
                      : theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                  letterSpacing: -0.3,
                ),
              ),
              child: Column(children: rows),
            ),
          ),
        ),
      ],
    );
  }
}

class MySettingsIcon extends StatelessWidget {
  const MySettingsIcon(this.name, {super.key, this.size = 24});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 24,
      child: Center(
        child: Image.asset(
          'assets/icons/figma-my-$name.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}

class MySettingsChevron extends StatelessWidget {
  const MySettingsChevron({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Image.asset(
      'assets/icons/figma-my-settings-chevron.png',
      width: 16,
      height: 16,
      color:
          colors.brightness == Brightness.dark ? colors.onSurfaceVariant : null,
      excludeFromSemantics: true,
      matchTextDirection: true,
    );
  }
}
