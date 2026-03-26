import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/constants/colors.dart';
import '../../core/services/haptic_service.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _tabs = [
    _TabData(svgPath: 'assets/icons/ic_home.svg', label: '홈'),
    _TabData(svgPath: 'assets/icons/ic_book.svg', label: '학습'),
    _TabData(svgPath: 'assets/icons/ic_note.svg', label: '퀴즈'),
    _TabData(
        svgPath: 'assets/icons/ic_messages.svg', label: '실전회화', isBeta: true),
    _TabData(svgPath: 'assets/icons/ic_user.svg', label: 'MY'),
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
                        onTap: () {
                          HapticService().selection();
                          onTap(i);
                        },
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
  final String svgPath;
  final String label;
  final bool isBeta;

  const _TabData({
    required this.svgPath,
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
              child: SvgPicture.asset(
                tab.svgPath,
                width: 22,
                height: 22,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
            ),
            if (tab.isBeta)
              const Positioned(
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
