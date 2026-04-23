import 'package:flutter/material.dart';

import 'quiz_header.dart';

class QuizSpecialModeContent extends StatelessWidget {
  const QuizSpecialModeContent({
    super.key,
    required this.title,
    required this.count,
    required this.onBack,
    required this.child,
  });

  final String title;
  final String count;
  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            QuizHeader(
              title: title,
              count: count,
              onBack: onBack,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
