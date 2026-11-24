import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/theme/text_theme.dart';

class WrongAnswersSummaryCard extends StatelessWidget {
  const WrongAnswersSummaryCard({
    super.key,
    required this.label,
    required this.count,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final int? count;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final light = colors.brightness == Brightness.light;
    final foreground = light ? AppColors.redesignForeground : colors.onSurface;
    final secondary =
        light ? AppColors.redesignMutedForeground : colors.onSurfaceVariant;
    final value = count;

    return Expanded(
      child: Semantics(
        excludeSemantics: true,
        label: value == null ? '$label 불러오는 중' : '$label $value개',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(height: 4),
              if (value == null)
                Center(
                  child: Container(
                    width: 38,
                    height: MediaQuery.textScalerOf(context).scale(15) * 1.4,
                    decoration: BoxDecoration(
                      color: light
                          ? AppColors.redesignOutline
                          : colors.outlineVariant,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                )
              else
                Text(
                  '$value개',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: redesignFontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: foreground,
                  ),
                ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: redesignFontFamily,
                  fontSize: 11,
                  height: 1.4,
                  color: secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
