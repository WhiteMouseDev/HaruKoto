import 'package:flutter/material.dart';
import '../../core/constants/sizes.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget card = Container(
      margin: margin ?? AppSizes.pageHorizontalEdge,
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      padding: padding ?? AppSizes.cardPaddingEdge,
      child: child,
    );

    if (onTap != null) {
      card = GestureDetector(onTap: onTap, child: card);
    }

    return card;
  }
}
