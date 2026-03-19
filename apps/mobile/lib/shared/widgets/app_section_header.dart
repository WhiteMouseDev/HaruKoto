import 'package:flutter/material.dart';

/// Reusable section header label (e.g. "학습 설정", "앱 설정", "구독").
class AppSectionHeader extends StatelessWidget {
  final String label;

  const AppSectionHeader({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
