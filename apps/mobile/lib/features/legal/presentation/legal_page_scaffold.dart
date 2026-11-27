import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/theme/haru_typography.dart';
import '../../../shared/widgets/bottom_nav.dart';

class LegalPageScaffold extends StatelessWidget {
  const LegalPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.onBack,
    this.onTabSelected,
    this.bodyLineHeight = 20 / 13,
  });

  final String title;
  final Widget body;
  final VoidCallback? onBack;
  final ValueChanged<int>? onTabSelected;
  final double bodyLineHeight;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final light = colors.brightness == Brightness.light;
    final textColor = light ? AppColors.redesignForeground : colors.onSurface;
    final surface = light ? Colors.white : colors.surface;
    final selectTab = onTabSelected;
    final canGoBack = onBack != null || Navigator.canPop(context);
    const leadingWidth = 52.0;
    final titleSpacing = canGoBack ? 0.0 : 20.0;
    final titleWidth = MediaQuery.sizeOf(context).width -
        MediaQuery.paddingOf(context).horizontal -
        (canGoBack ? leadingWidth : 0) -
        titleSpacing * 2;
    final textScaler = MediaQuery.textScalerOf(context);
    final titlePainter = TextPainter(
      text: TextSpan(text: title, style: HaruTypography.krTitle2),
      textDirection: Directionality.of(context),
      textScaler: textScaler,
    )..layout(maxWidth: math.max(0, titleWidth));
    final toolbarHeight = math.max(48.0, titlePainter.height + 8);
    titlePainter.dispose();

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: surface,
        foregroundColor: textColor,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: titleSpacing,
        toolbarHeight: toolbarHeight,
        leadingWidth: leadingWidth,
        leading: canGoBack
            ? IconButton(
                alignment: AlignmentDirectional.centerEnd,
                padding: const EdgeInsetsDirectional.only(end: 12),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: onBack ?? () => Navigator.maybePop(context),
                icon: const Icon(LucideIcons.arrowLeft, size: 20),
              )
            : null,
        title: Text(
          title,
          style: HaruTypography.krTitle2,
          textScaler: textScaler,
          softWrap: true,
          overflow: TextOverflow.clip,
        ),
      ),
      bottomNavigationBar: selectTab == null
          ? null
          : BottomNav(currentIndex: 4, onTap: selectTab),
      body: SafeArea(
        top: false,
        child: DefaultTextStyle(
          style: HaruTypography.krBody3.copyWith(
            color: textColor,
            height: bodyLineHeight,
          ),
          child: body,
        ),
      ),
    );
  }
}
