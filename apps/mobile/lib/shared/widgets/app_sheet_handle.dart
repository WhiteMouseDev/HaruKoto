import 'package:flutter/material.dart';
import '../../core/constants/sizes.dart';

/// Standard drag handle for bottom sheets.
class AppSheetHandle extends StatelessWidget {
  const AppSheetHandle({super.key}) : _todayStudy = false;

  const AppSheetHandle.todayStudy({super.key}) : _todayStudy = true;

  final bool _todayStudy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        width: _todayStudy ? 36 : AppSizes.handleWidth,
        height: _todayStudy ? 3 : AppSizes.handleHeight,
        decoration: BoxDecoration(
          color: _todayStudy && colors.brightness == Brightness.light
              ? const Color(0xFFC9C9CF)
              : colors.onSurface.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(
            _todayStudy ? 500 : AppSizes.handleHeight / 2,
          ),
        ),
      ),
    );
  }
}
