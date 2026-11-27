import 'package:flutter/material.dart';

import '../../../../core/constants/sizes.dart';
import 'quiz_header.dart';

class QuizSpecialModeContent extends StatelessWidget {
  const QuizSpecialModeContent({
    super.key,
    required this.title,
    required this.count,
    required this.onBack,
    required this.child,
    this.redesignedHeader = false,
  });

  final String title;
  final String count;
  final VoidCallback onBack;
  final Widget child;
  final bool redesignedHeader;

  @override
  Widget build(BuildContext context) {
    final header = QuizHeader(
      title: title,
      count: redesignedHeader ? null : count,
      onBack: onBack,
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (redesignedHeader)
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: AppSizes.sm),
                child: Semantics(value: count, child: header),
              )
            else
              header,
            Expanded(
              child: redesignedHeader
                  ? child
                  : Padding(padding: const EdgeInsets.all(16), child: child),
            ),
          ],
        ),
      ),
    );
  }
}
