import 'package:flutter/material.dart';

import '../../core/constants/sizes.dart';

class AppSegmentedTabs extends StatelessWidget {
  const AppSegmentedTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  })  : assert(labels.length > 1),
        assert(selectedIndex >= 0 && selectedIndex < labels.length);

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final radius = BorderRadius.circular(AppSizes.radiusFull);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: radius,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xs),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < labels.length; index++)
                Expanded(
                  child: TextButton(
                    onPressed: () => onChanged(index),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, kMinInteractiveDimension),
                      visualDensity: VisualDensity.standard,
                      padding: const EdgeInsets.all(AppSizes.sm),
                      shape: const StadiumBorder(),
                      backgroundColor: index == selectedIndex
                          ? colors.surfaceContainerLowest
                          : Colors.transparent,
                      foregroundColor: index == selectedIndex
                          ? colors.onSurface
                          : colors.onSurfaceVariant,
                      textStyle: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: index == selectedIndex
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    child: Semantics(
                      selected: index == selectedIndex,
                      inMutuallyExclusiveGroup: true,
                      child: Text(labels[index], textAlign: TextAlign.center),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
