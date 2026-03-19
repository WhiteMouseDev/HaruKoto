import 'package:flutter/widgets.dart';

abstract final class AppSizes {
  // ─── Spacing scale (4px grid) ──────────────────────────────
  static const double xs = 4;
  static const double sm = 8;
  static const double gap = 12; // between sm and md
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  // ─── Border radius ─────────────────────────────────────────
  static const double radiusSm = 8;
  static const double radiusMd = 16;
  static const double radiusLg = 24;
  static const double radiusFull = 999; // pill shape

  // ─── Card ──────────────────────────────────────────────────
  static const double cardRadius = 24;
  static const double cardPadding = 20.0;
  static const cardPaddingEdge = EdgeInsets.all(cardPadding);

  // ─── Page ──────────────────────────────────────────────────
  static const double pageHorizontal = 20.0;
  static const pageHorizontalEdge =
      EdgeInsets.symmetric(horizontal: pageHorizontal);

  // ─── Icon sizes ────────────────────────────────────────────
  static const double iconSm = 16.0;
  static const double iconMd = 20.0;
  static const double iconLg = 24.0;
  static const double iconXl = 32.0;

  // ─── Button / Input ────────────────────────────────────────
  static const double buttonRadius = 16;
  static const double buttonHeight = 48;
  static const double inputRadius = 16;

  // ─── Chip ──────────────────────────────────────────────────
  static const double chipRadius = 20;
  static const double chipHeight = 32;
  static const chipPadding =
      EdgeInsets.symmetric(horizontal: 12, vertical: 6);

  // ─── Bottom sheet ──────────────────────────────────────────
  static const double sheetRadius = 20;
  static const sheetShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(sheetRadius)),
  );

  // ─── Modal handle bar ──────────────────────────────────────
  static const double handleWidth = 40;
  static const double handleHeight = 4;

  // ─── Progress bar ──────────────────────────────────────────
  static const double progressHeight = 6;
  static const double progressRadius = 3;
}
