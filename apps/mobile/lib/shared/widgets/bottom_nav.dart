import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/services/haptic_service.dart';

class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _tabs = [
    (icon: 'home', label: '홈'),
    (icon: 'study', label: '학습'),
    (icon: 'quiz', label: '퀴즈'),
    (icon: 'conversation', label: '실전회화'),
    (icon: 'profile', label: '마이페이지'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surfaceContainerLowest;
    final active = isDark ? AppColors.darkText : const Color(0xFF2A2A37);
    final inactive = isDark ? AppColors.darkSubtext : const Color(0xFFA5A5AF);
    final inactiveText =
        isDark ? AppColors.darkSubtext : const Color(0xFF767676);

    return Material(
      color: surface,
      elevation: 3,
      shadowColor: Colors.black12,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Row(
            children: [
              for (final (index, tab) in _tabs.indexed)
                Expanded(
                  child: Semantics(
                    label: '${tab.label} 탭',
                    button: true,
                    selected: index == currentIndex,
                    excludeSemantics: true,
                    onTap: () => _select(index),
                    child: InkWell(
                      onTap: () => _select(index),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 56),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10, bottom: 6),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox.square(
                                dimension: 20,
                                child: Image.asset(
                                  'assets/icons/home-nav-${tab.icon}.png',
                                  fit: BoxFit.contain,
                                  color:
                                      index == currentIndex ? active : inactive,
                                  excludeFromSemantics: true,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                tab.label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 11,
                                  height: 1.3,
                                  letterSpacing: -0.275,
                                  fontWeight: index == currentIndex
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: index == currentIndex
                                      ? active
                                      : inactiveText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _select(int index) {
    HapticService().selection();
    onTap(index);
  }
}
