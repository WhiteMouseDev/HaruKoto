import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/theme/text_theme.dart';

class WrongAnswersSummaryCard extends StatelessWidget {
  const WrongAnswersSummaryCard({
    super.key,
    required this.label,
    required this.count,
    required this.iconAsset,
  });

  final String label;
  final int? count;
  final String iconAsset;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final light = colors.brightness == Brightness.light;
    final foreground = light ? AppColors.redesignForeground : colors.onSurface;
    final secondary = light ? const Color(0xFF767676) : colors.onSurfaceVariant;
    final value = count;

    return Expanded(
      child: Semantics(
        excludeSemantics: true,
        label: value == null ? '$label 불러오는 중' : '$label $value개',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Column(
            children: [
              SvgPicture.asset(iconAsset, width: 24, height: 24),
              const SizedBox(height: 2),
              if (value == null)
                Center(
                  child: Container(
                    width: 38,
                    height: MediaQuery.textScalerOf(context).scale(18) * 1.4,
                    decoration: BoxDecoration(
                      color: light
                          ? AppColors.redesignOutline
                          : colors.outlineVariant,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                )
              else
                Text.rich(
                  TextSpan(
                    text: '$value',
                    children: const [
                      TextSpan(
                        text: '개',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: redesignFontFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: foreground,
                  ),
                ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: redesignFontFamily,
                  fontSize: 12,
                  height: 1.5,
                  color: secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
