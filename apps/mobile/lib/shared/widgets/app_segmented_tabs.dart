import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/sizes.dart';
import '../../core/theme/text_theme.dart';

class AppSegmentedTabs extends StatelessWidget {
  const AppSegmentedTabs({
    super.key,
    required this.labels,
    this.tabKeys,
    this.compact = false,
    this.labelFontWeight,
    required this.selectedIndex,
    required this.onChanged,
  })  : assert(labels.length > 1),
        assert(tabKeys == null || tabKeys.length == labels.length),
        assert(selectedIndex >= 0 && selectedIndex < labels.length);

  final List<String> labels;
  final List<Key>? tabKeys;
  final bool compact;
  final FontWeight? labelFontWeight;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final radius = BorderRadius.circular(AppSizes.radiusFull);

    final isLight = theme.brightness == Brightness.light;
    final track = BoxDecoration(
      color: compact && isLight
          ? AppColors.redesignControl
          : colors.surfaceContainerHigh,
      borderRadius: radius,
    );
    final buttons = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < labels.length; index++)
            Expanded(
              child: _tab(theme, radius, index),
            ),
        ],
      ),
    );
    if (!compact) {
      return DecoratedBox(
        decoration: track,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.xs),
          child: buttons,
        ),
      );
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        const SizedBox(height: kMinInteractiveDimension),
        Positioned.fill(
          top: AppSizes.xs,
          bottom: AppSizes.xs,
          child: DecoratedBox(decoration: track),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.xs),
          child: buttons,
        ),
      ],
    );
  }

  Widget _tab(ThemeData theme, BorderRadius radius, int index) {
    final colors = theme.colorScheme;
    final selected = index == selectedIndex;
    final label = Text(labels[index], textAlign: TextAlign.center);
    return TextButton(
      key: tabKeys?[index],
      onPressed: () => onChanged(index),
      style: TextButton.styleFrom(
        minimumSize: const Size(0, kMinInteractiveDimension),
        visualDensity: VisualDensity.standard,
        padding: compact ? EdgeInsets.zero : const EdgeInsets.all(AppSizes.sm),
        shape: const StadiumBorder(),
        backgroundColor: selected && !compact
            ? colors.surfaceContainerLowest
            : Colors.transparent,
        foregroundColor: compact && theme.brightness == Brightness.light
            ? AppColors.redesignForeground
            : selected
                ? colors.onSurface
                : colors.onSurfaceVariant,
        textStyle: compact
            ? TextStyle(
                fontFamily: redesignFontFamily,
                fontSize: 13,
                fontWeight: labelFontWeight ?? FontWeight.w400,
                height: 1.4,
                letterSpacing: -0.325,
              )
            : theme.textTheme.labelLarge?.copyWith(
                fontWeight: labelFontWeight ??
                    (selected ? FontWeight.w700 : FontWeight.w500),
              ),
      ),
      child: Semantics(
        selected: selected,
        inMutuallyExclusiveGroup: true,
        child: compact
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
                decoration: BoxDecoration(
                  borderRadius: radius,
                  color: selected ? colors.surfaceContainerLowest : null,
                ),
                child: label,
              )
            : label,
      ),
    );
  }
}
