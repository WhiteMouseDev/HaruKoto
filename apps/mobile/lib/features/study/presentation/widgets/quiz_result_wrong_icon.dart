import 'package:flutter/material.dart';

class QuizResultWrongIcon extends StatelessWidget {
  const QuizResultWrongIcon({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    const fill = Color(0xFFD32F2F);
    return Stack(
      alignment: Alignment.center,
      children: [
        // The Figma vector keeps the red fill behind a transparent ring.
        SizedBox.square(
          dimension: size * 5 / 6,
          child: const DecoratedBox(
            decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
          ),
        ),
        Image.asset(
          'assets/icons/figma-quiz-result-wrong.png',
          width: size,
          height: size,
          excludeFromSemantics: true,
          errorBuilder: (context, error, stackTrace) =>
              Icon(Icons.cancel, color: fill, size: size),
        ),
      ],
    );
  }
}
