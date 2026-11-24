import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';

class WordbookLoadingList extends StatelessWidget {
  const WordbookLoadingList({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fill = colors.brightness == Brightness.light
        ? AppColors.redesignControl
        : colors.surfaceContainerHigh;

    return Semantics(
      label: '단어장을 불러오는 중',
      liveRegion: true,
      child: ListView(
        padding: AppSizes.pageHorizontalEdge,
        children: List.generate(
          5,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
