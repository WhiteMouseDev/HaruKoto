import 'package:flutter/material.dart';
import '../../core/constants/sizes.dart';

/// Standard drag handle for bottom sheets.
class AppSheetHandle extends StatelessWidget {
  const AppSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: AppSizes.handleWidth,
        height: AppSizes.handleHeight,
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .onSurface
              .withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(AppSizes.handleHeight / 2),
        ),
      ),
    );
  }
}
