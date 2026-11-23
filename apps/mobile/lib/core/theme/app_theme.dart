import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/sizes.dart';
import 'haru_semantic_colors.dart';
import 'text_theme.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    final background =
        isLight ? AppColors.lightBackground : AppColors.darkBackground;
    final card = isLight ? AppColors.lightCard : AppColors.darkCard;
    final surface =
        isLight ? AppColors.lightSecondary : AppColors.darkSecondary;
    final border = isLight ? AppColors.lightBorder : AppColors.darkBorder;
    final text = isLight ? AppColors.lightText : AppColors.darkText;
    final subtext = isLight ? AppColors.lightSubtext : AppColors.darkSubtext;
    final semantic = HaruSemanticColors.fromBrightness(brightness);

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.primaryPressed,
      secondary: isLight ? AppColors.neutralContainer : AppColors.darkSecondary,
      onSecondary: isLight ? AppColors.neutralOn : AppColors.darkText,
      secondaryContainer: semantic.accentContainer,
      onSecondaryContainer: AppColors.accentAlt,
      surface: background,
      onSurface: text,
      onSurfaceVariant: subtext,
      surfaceContainerLowest: card,
      surfaceContainerLow: card,
      surfaceContainer: card,
      surfaceContainerHigh: surface,
      surfaceContainerHighest: surface,
      error: semantic.error,
      onError: Colors.white,
      outline: border,
    );
    final textTheme = appTextTheme(brightness);
    final primaryButtonStyle = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return semantic.surfaceMuted;
        }
        if (states.contains(WidgetState.pressed)) {
          return AppColors.primaryButtonPressed;
        }
        return AppColors.primaryButton;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.disabled) ? subtext : Colors.white;
      }),
      elevation: const WidgetStatePropertyAll(0),
      minimumSize:
          const WidgetStatePropertyAll(Size(64, AppSizes.buttonHeight)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: AppSizes.pageHorizontal, vertical: 12),
      ),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      textStyle: WidgetStatePropertyAll(
        textTheme.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.4,
          letterSpacing: -0.35,
        ),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      extensions: [semantic],
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          side: BorderSide(color: border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: primaryButtonStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButtonStyle),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.inputRadius),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.inputRadius),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.inputRadius),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: card,
        selectedItemColor: semantic.tabActive,
        unselectedItemColor: subtext,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: semantic.surfaceMuted,
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
    );
  }
}
