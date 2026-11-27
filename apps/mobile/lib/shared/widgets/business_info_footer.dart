import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/theme/text_theme.dart';

class BusinessInfoFooter extends StatelessWidget {
  const BusinessInfoFooter({super.key, this.titleWeight = FontWeight.w600});

  final FontWeight titleWeight;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final light = colors.brightness == Brightness.light;
    return ColoredBox(
      color: light ? AppColors.redesignControl : colors.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: DefaultTextStyle(
          style: TextStyle(
            fontFamily: redesignFontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w400,
            height: 1.5,
            letterSpacing: -0.3,
            color: light ? const Color(0xFF505050) : colors.onSurfaceVariant,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '화이트마우스데브 (WhiteMouseDev)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: titleWeight,
                  letterSpacing: -0.35,
                  color:
                      light ? AppColors.redesignForeground : colors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              const Text('대표: 김건우'),
              const Text('사업자등록번호: 634-26-01985'),
              const Text('통신판매업신고번호: 2026-서울송파-0749'),
              const Text('주소: 서울특별시 송파구 양재대로 1218'),
              const SizedBox(height: 16),
              const Text('연락처: 010-8595-9869'),
              const Text('이메일: whitemousedev@whitemouse.dev'),
            ],
          ),
        ),
      ),
    );
  }
}
