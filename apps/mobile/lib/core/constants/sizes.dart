import 'package:flutter/widgets.dart';

abstract final class AppSizes {
  // Spacing
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  // Border radius
  static const double radiusSm = 8;
  static const double radiusMd = 16;
  static const double radiusLg = 24;

  // Card
  static const double cardRadius = 24;
  static const double cardPadding = 20.0;
  static const cardPaddingEdge = EdgeInsets.all(cardPadding);

  // Page
  static const double pageHorizontal = 20.0;
  static const pageHorizontalEdge = EdgeInsets.symmetric(horizontal: pageHorizontal);

  // Icon sizes
  static const double iconSm = 16.0;
  static const double iconMd = 20.0;
  static const double iconLg = 24.0;
  static const double iconXl = 32.0;

  // Button / Input radius
  static const double buttonRadius = 16;
  static const double inputRadius = 16;
}
