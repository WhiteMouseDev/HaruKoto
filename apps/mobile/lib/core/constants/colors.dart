import 'package:flutter/material.dart';

abstract final class AppColors {
  // ─── Brand ───────────────────────────────────────────────
  static const primary = Color(0xFFF6A5B3);
  static const brandPink = Color(0xFFFFB7C5);

  // ─── Light theme ─────────────────────────────────────────
  static const lightBackground = Color(0xFFFCF6F5);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightSecondary = Color(0xFFFFF0F3);
  static const lightBorder = Color(0xFFFCE7EC);
  static const lightText = Color(0xFF1A1A2E);
  static const lightSubtext = Color(0xFF666680);

  // ─── Dark theme ──────────────────────────────────────────
  static const darkBackground = Color(0xFF1A1A2E);
  static const darkCard = Color(0xFF242442);
  static const darkSecondary = Color(0xFF2A2A4A);
  static const darkBorder = Color(0x1AFFFFFF); // rgba(255,255,255,0.1)
  static const darkText = Color(0xFFFFFFFF);
  static const darkSubtext = Color(0xFFB0B0C0);

  // ─── HK semantic colors (light / dark) ───────────────────
  static const hkBlueLight = Color(0xFF87CEEB);
  static const hkBlueDark = Color(0xFF5BA3C9);
  static const hkYellowLight = Color(0xFFFFD93D);
  static const hkYellowDark = Color(0xFFE5C235);
  static const hkRedLight = Color(0xFFFF6B6B);
  static const hkRedDark = Color(0xFFE05252);

  static Color hkBlue(Brightness brightness) =>
      brightness == Brightness.light ? hkBlueLight : hkBlueDark;
  static Color hkYellow(Brightness brightness) =>
      brightness == Brightness.light ? hkYellowLight : hkYellowDark;
  static Color hkRed(Brightness brightness) =>
      brightness == Brightness.light ? hkRedLight : hkRedDark;

  // ─── Functional semantic colors (brightness-aware) ───────
  // Soft teal green – complements pink theme without clashing
  static Color success(Brightness brightness) => brightness == Brightness.light
      ? const Color(0xFF2DB08A)
      : const Color(0xFF26997A);
  // Warm rose – harmonises with brandPink rather than harsh red
  static Color error(Brightness brightness) => brightness == Brightness.light
      ? const Color(0xFFE8577D)
      : const Color(0xFFD14468);
  static Color warning(Brightness brightness) => brightness == Brightness.light
      ? const Color(0xFFF59E0B)
      : const Color(0xFFD97706);
  static Color info(Brightness brightness) => brightness == Brightness.light
      ? const Color(0xFF3B82F6)
      : const Color(0xFF2563EB);

  // ─── Auth gradient ───────────────────────────────────────
  static const authGradientTop = Color(0xFFFCF6F5);
  static const authGradientMid = Color(0xFFFFF0F3);
  static const authGradientBottom = Color(0xFFFFE4EC);
  static const authGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [authGradientTop, authGradientMid, authGradientBottom],
  );

  // ─── Kakao brand ─────────────────────────────────────────
  static const kakaoBg = Color(0xFFFEE500);
  static const kakaoText = Color(0xFF191919);

  // ─── Voice call / dark surface ───────────────────────────
  static const callBackground = Color(0xFF0F172A);
  static const callSurface = Color(0xFF1E293B);
  static const callAccent = Color(0xFF10B981);
  static const callAccentLight = Color(0xFF34D399);

  // ─── Scenario / difficulty ───────────────────────────────
  static const difficultyBeginner = Color(0xFF22C55E);
  static const difficultyIntermediate = Color(0xFFEAB308);
  static const difficultyAdvanced = Color(0xFFEF4444);
  static const scenarioPurple = Color(0xFF8B5CF6);

  // ─── Quiz feedback (duolingo-style) ─────────────────────
  static const quizCorrect = Color(0xFF4CAF50);
  // 정답: 민트 톤
  static const quizCorrectBg = Color(0xFFE8F5EE);
  static const quizCorrectBgDark = Color(0xFF1A3D2A);
  static const quizCorrectButton = Color(0xFF2DB08A);
  static const quizCorrectButtonDark = Color(0xFF26997A);
  static const quizCorrectText = Color(0xFF1B7A53);
  static const quizCorrectTextDark = Color(0xFF6EDAAD);
  // 오답: 코랄/레드 톤
  static const quizWrongBg = Color(0xFFFFF0F0);
  static const quizWrongBgDark = Color(0xFF3D1A1A);
  static const quizWrongButton = Color(0xFFE8577D);
  static const quizWrongButtonDark = Color(0xFFD14468);
  static const quizWrongText = Color(0xFFCF3A5A);
  static const quizWrongTextDark = Color(0xFFFF8A9E);

  // ─── Notification icon backgrounds ───────────────────────
  static const notifLevelUp = Color(0xFFFFF3E0);
  static const notifStreak = Color(0xFFFBE9E7);
  static const notifAchievement = Color(0xFFFFF8E1);

  // ─── Score ───────────────────────────────────────────────
  static const scoreMid = Color(0xFFFBBF24);

  // ─── Heatmap intensities ─────────────────────────────────
  static const heatmapLight = [
    Color(0xFFF0F0F0),
    Color(0xFFFCE7EC),
    Color(0xFFF6A5B3),
    Color(0xFFF494A4),
    Color(0xFFE5607A),
  ];
  static const heatmapDark = [
    Color(0xFF2A2A4A),
    Color(0xFF3D1F2A),
    Color(0xFF6B3040),
    Color(0xFF994158),
    Color(0xFFCC5570),
  ];

  static List<Color> heatmapColors(Brightness brightness) =>
      brightness == Brightness.light ? heatmapLight : heatmapDark;

  // ─── On gradient surfaces ────────────────────────────────
  static const onGradient = Colors.white;
  static const onGradientMuted = Color(0xB3FFFFFF); // white70

  // ─── Overlay ─────────────────────────────────────────────
  static Color overlay(double alpha) => Colors.black.withValues(alpha: alpha);
}
