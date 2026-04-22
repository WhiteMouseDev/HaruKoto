import 'package:flutter/material.dart';

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
    final isGrammar = category == 'GRAMMAR';

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: onStart,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          totalCount > 0
              ? '학습 시작 ($totalCount문제)'
              : '학습할 ${isGrammar ? '문법' : '단어'}이 없습니다',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
