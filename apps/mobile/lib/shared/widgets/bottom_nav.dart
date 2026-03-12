import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/constants/colors.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _tabs = [
    _TabData(icon: LucideIcons.home, label: '홈'),
    _TabData(icon: LucideIcons.barChart3, label: '학습통계'),
    _TabData(icon: LucideIcons.bookOpen, label: '학습'),
    _TabData(icon: LucideIcons.messageCircle, label: '회화', isBeta: true),
    _TabData(icon: LucideIcons.user, label: 'MY'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = (isDark ? AppColors.darkCard : AppColors.lightBackground)
        .withValues(alpha: 0.95);
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final inactiveColor =
        isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(top: BorderSide(color: borderColor, width: 1)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(
                children: List.generate(_tabs.length, (i) {
                  final tab = _tabs[i];
                  final isActive = i == currentIndex;
                  return Expanded(
                    child: Semantics(
                      label: '${tab.label} 탭',
                      button: true,
                      selected: isActive,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onTap(i),
                        child: _TabItem(
                          tab: tab,
                          isActive: isActive,
                          inactiveColor: inactiveColor,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabData {
  final IconData icon;
  final String label;
  final bool isBeta;

  const _TabData({
    required this.icon,
    required this.label,
    this.isBeta = false,
  });
}

class _TabItem extends StatelessWidget {
  final _TabData tab;
  final bool isActive;
  final Color inactiveColor;

  const _TabItem({
    required this.tab,
    required this.isActive,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.primary : inactiveColor;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Active indicator bar
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          height: 2,
          width: isActive ? 32 : 0,
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        // Icon
        Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedScale(
              scale: isActive ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: Icon(
                tab.icon,
                size: 20,
                color: color,
                weight: isActive ? 2.5 : 2.0,
              ),
            ),
            if (tab.isBeta)
              Positioned(
                top: -4,
                right: -8,
                child: Icon(
                  LucideIcons.flaskConical,
                  size: 10,
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        // Label
        Text(
          tab.label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}
