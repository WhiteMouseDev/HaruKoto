import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import 'study_list_status.dart';

class WordbookEmptyState extends StatelessWidget {
  final bool hasActiveQuery;
  final VoidCallback onAddFirst;

  const WordbookEmptyState({
    super.key,
    required this.hasActiveQuery,
    required this.onAddFirst,
  });

  @override
  Widget build(BuildContext context) {
    return StudyListStatus(
      icon: const Icon(LucideIcons.inbox, size: 32),
      title: hasActiveQuery ? '검색 결과가 없어요' : '단어장에 단어가 없어요.',
      subtitle: hasActiveQuery ? null : '단어를 추가해 보세요!',
      action: hasActiveQuery
          ? null
          : StudyListStatusAction(
              onPressed: onAddFirst,
              icon: LucideIcons.plus,
              label: '단어 추가',
            ),
    );
  }
}

class WordbookErrorState extends StatelessWidget {
  const WordbookErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return StudyListStatus(
      icon: const SizedBox.square(
        dimension: 32,
        child: Stack(
          children: [
            Align(
              alignment: Alignment.bottomRight,
              child: Icon(LucideIcons.barChart3, size: 27),
            ),
            Positioned(
              top: 0,
              left: 0,
              child: Icon(
                LucideIcons.x,
                size: 14,
                color: AppColors.redesignVocabulary,
              ),
            ),
          ],
        ),
      ),
      title: message,
      subtitle: '네트워크 연결을 확인해 주세요.',
      action: StudyListStatusAction(
        onPressed: onRetry,
        icon: LucideIcons.refreshCw,
        label: '다시 시도하기',
      ),
    );
  }
}
