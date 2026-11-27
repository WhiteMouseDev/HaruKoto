import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/theme/haru_typography.dart';
import '../../../../shared/widgets/haru_button_styles.dart';

String themeModeLabel(ThemeMode mode) => switch (mode) {
      ThemeMode.light => '라이트',
      ThemeMode.dark => '다크',
      ThemeMode.system => '시스템',
    };

class ThemePickerSheet extends StatefulWidget {
  const ThemePickerSheet({super.key, required this.initialMode});

  final ThemeMode initialMode;

  @override
  State<ThemePickerSheet> createState() => _ThemePickerSheetState();
}

class _ThemePickerSheetState extends State<ThemePickerSheet> {
  static const _modes = [ThemeMode.light, ThemeMode.dark, ThemeMode.system];
  late ThemeMode _selectedMode = widget.initialMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final light = theme.brightness == Brightness.light;
    final foreground = light ? AppColors.redesignForeground : colors.onSurface;
    final handle = light ? const Color(0xFFC9C9CF) : colors.outline;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.pageHorizontal,
          20,
          AppSizes.pageHorizontal,
          AppSizes.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 3,
                decoration: ShapeDecoration(
                  color: handle,
                  shape: const StadiumBorder(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Semantics(
              header: true,
              child: Text(
                '테마 선택',
                textAlign: TextAlign.center,
                style: HaruTypography.krTitle2.copyWith(color: foreground),
              ),
            ),
            const SizedBox(height: 20),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final mode in _modes) ...[
                    if (mode != _modes.first)
                      const SizedBox(width: AppSizes.xs),
                    Expanded(
                      child: _ThemeOption(
                        mode: mode,
                        selected: mode == _selectedMode,
                        onPressed: () => setState(() => _selectedMode = mode),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: HaruButtonStyles.primary(
                context,
                size: HaruButtonSize.regular,
              ),
              onPressed: () => Navigator.pop(context, _selectedMode),
              child: const Text('적용'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.mode,
    required this.selected,
    required this.onPressed,
  });

  final ThemeMode mode;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final light = theme.brightness == Brightness.light;
    final foreground = light ? AppColors.redesignForeground : colors.onSurface;
    final outline = light ? AppColors.redesignOutline : colors.outline;
    final icon = light ? AppColors.redesignStrong : colors.onSurface;
    final accent = light ? AppColors.brandPink : colors.primary;
    final horizontalPadding =
        MediaQuery.textScalerOf(context).scale(14) > 18 ? AppSizes.xs : 20.0;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? accent : foreground,
        side: BorderSide(color: selected ? accent : outline),
        minimumSize: const Size(0, 90),
        visualDensity: VisualDensity.standard,
        padding:
            EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppSizes.gap)),
        ),
        textStyle: HaruTypography.krCompactButton,
      ),
      child: Semantics(
        selected: selected,
        inMutuallyExclusiveGroup: true,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/icons/figma-my-theme-${mode.name}.svg',
              width: AppSizes.iconLg,
              height: AppSizes.iconLg,
              excludeFromSemantics: true,
              colorFilter: ColorFilter.mode(
                selected ? accent : icon,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: 6),
            Text(themeModeLabel(mode), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
