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
    final emptyLabel = category == 'GRAMMAR' ? '학습할 문법이 없습니다' : '학습할 단어가 없습니다';

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onStart,
        child: Text(
          totalCount > 0 ? '학습 시작 ($totalCount문제)' : emptyLabel,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
