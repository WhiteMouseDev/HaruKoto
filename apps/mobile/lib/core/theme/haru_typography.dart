import 'package:flutter/material.dart';

import 'text_theme.dart';

abstract final class HaruTypography {
  static const krTitle2 = TextStyle(
    fontFamily: redesignFontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: -0.5,
  );

  static const krTitle3 = TextStyle(
    fontFamily: redesignFontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: -0.45,
  );

  static const krBody3 = TextStyle(
    fontFamily: redesignFontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: -0.325,
  );

  static const jpBody3 = TextStyle(
    fontFamily: redesignJapaneseFontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: -0.325,
  );

  static const krCompactButton = TextStyle(
    fontFamily: redesignFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: -0.35,
  );

  static const krRegularButton = TextStyle(
    fontFamily: redesignFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: -0.35,
  );

  static const krPillTab = TextStyle(
    fontFamily: redesignFontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: -0.325,
  );
}
