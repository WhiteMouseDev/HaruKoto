import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/theme/text_theme.dart';

class StudyListStatus extends StatelessWidget {
  const StudyListStatus({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final Widget icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final light = colors.brightness == Brightness.light;
    final foreground = light ? AppColors.redesignForeground : colors.onSurface;
    final secondary =
        light ? AppColors.redesignMutedForeground : colors.onSurfaceVariant;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.pageHorizontal,
          vertical: AppSizes.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTheme(
              data: IconThemeData(
                color: light
                    ? AppColors.redesignStrong.withValues(alpha: 0.48)
                    : secondary,
              ),
              child: icon,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: redesignFontFamily,
                fontSize: 14,
                height: 1.4,
                color: foreground,
              ),
            ),
            if (subtitle case final text?)
              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: redesignFontFamily,
                  fontSize: 12,
                  height: 1.4,
                  color: secondary,
                ),
              ),
            if (action case final button?) ...[
              const SizedBox(height: 12),
              button,
            ],
          ],
        ),
      ),
    );
  }
}

class StudyListStatusAction extends StatelessWidget {
  const StudyListStatusAction({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(label),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        tapTargetSize: MaterialTapTargetSize.padded,
        visualDensity: VisualDensity.standard,
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: redesignFontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
      ),
    );
  }
}
