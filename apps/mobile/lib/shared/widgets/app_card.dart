import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/sizes.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = AppSizes.cardPaddingEdge,
    this.onTap,
  }) : _compactDarkSurface = null;

  /// The filled surface used behind the Study review and Quiz actions.
  const AppCard.compactSurface({
    super.key,
    required this.child,
    required Color darkSurface,
    this.padding = const EdgeInsets.all(AppSizes.md),
  })  : _compactDarkSurface = darkSurface,
        onTap = null;

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? _compactDarkSurface;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    final darkSurface = _compactDarkSurface;
    if (darkSurface != null) {
      final light = Theme.of(context).brightness == Brightness.light;
      return DecoratedBox(
        decoration: BoxDecoration(
          color: light ? AppColors.redesignSurface : darkSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: content,
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : Semantics(
              button: true, child: InkWell(onTap: onTap, child: content)),
    );
  }
}
