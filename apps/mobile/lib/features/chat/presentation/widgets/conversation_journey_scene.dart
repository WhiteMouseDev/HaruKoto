import 'package:flutter/material.dart';

class ConversationJourneyScene extends StatelessWidget {
  const ConversationJourneyScene({
    super.key,
    required this.episodeNumber,
    this.height = 112,
  });

  final int episodeNumber;
  final double height;

  @override
  Widget build(BuildContext context) {
    final path = switch (episodeNumber) {
      1 => 'assets/images/conversation/tokyo-airport-train-tickets.webp',
      2 => 'assets/images/conversation/tokyo-hotel-luggage-drop.webp',
      3 => 'assets/images/conversation/tokyo-cafe-takeout.webp',
      _ => null,
    };
    final colors = Theme.of(context).colorScheme;
    final fallback = ColoredBox(
      color: colors.brightness == Brightness.light
          ? const Color(0xFFFEF0F2)
          : colors.surfaceContainerHigh,
    );

    return SizedBox(
      width: double.infinity,
      height: height,
      child: path == null
          ? fallback
          : Image.asset(
              path,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              errorBuilder: (_, __, ___) => fallback,
            ),
    );
  }
}
