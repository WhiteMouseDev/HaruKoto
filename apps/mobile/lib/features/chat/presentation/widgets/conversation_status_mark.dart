import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';

class ConversationStatusMark extends StatelessWidget {
  const ConversationStatusMark({
    super.key,
    this.icon = LucideIcons.messageCircle,
    this.size = 56,
    this.iconSize,
  });

  final IconData icon;
  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveIconSize = iconSize ?? size * 0.42;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryStrong.withValues(alpha: 0.18),
            AppColors.primary.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.22),
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          size: effectiveIconSize,
          color: colorScheme.primary,
        ),
      ),
    );
  }
}
