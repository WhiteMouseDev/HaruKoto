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
      child: FilledButton(
        onPressed: onStart,
        child: Text(
          totalCount > 0
              ? '학습 시작 ($totalCount문제)'
              : '학습할 ${isGrammar ? '문법' : '단어'}이 없습니다',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
