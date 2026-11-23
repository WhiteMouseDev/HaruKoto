import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/theme/text_theme.dart';

class TodayStudyStartButton extends StatelessWidget {
  final int totalCount;
  final String category;
  final VoidCallback? onStart;

  const TodayStudyStartButton({
    super.key,
    required this.totalCount,
    required this.category,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final emptyLabel = category == 'GRAMMAR' ? '학습할 문법이 없습니다' : '학습할 단어가 없습니다';
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: isLight ? AppColors.brandPink : null,
          foregroundColor: isLight ? Colors.white : null,
          textStyle: theme.textTheme.labelLarge?.copyWith(
            fontFamily: redesignFontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.4,
            letterSpacing: -0.35,
          ),
        ),
        onPressed: onStart,
        child: Text(
          totalCount > 0 ? '학습 시작 ($totalCount문제)' : emptyLabel,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
