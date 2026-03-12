import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/sizes.dart';
import '../wrong_answers_page.dart';
import '../learned_words_page.dart';
import '../wordbook_page.dart';

class MyStudyData extends StatelessWidget {
  const MyStudyData({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final items = [
      (LucideIcons.fileX, '오답 노트',
          const WrongAnswersPage()),
      (LucideIcons.bookOpen, '내가 학습한 단어',
          const LearnedWordsPage()),
      (LucideIcons.bookMarked, '내 단어장',
          const WordbookPage()),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '내 학습 데이터',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(
                    AppSizes.radiusMd),
                child: InkWell(
                  borderRadius: BorderRadius.circular(
                      AppSizes.radiusMd),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => item.$3),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color:
                              theme.colorScheme.outline),
                      borderRadius: BorderRadius.circular(
                          AppSizes.radiusMd),
                    ),
                    child: Row(
                      children: [
                        Icon(item.$1,
                            size: 16,
                            color: theme
                                .colorScheme.onSurface
                                .withValues(alpha: 0.5)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.$2,
                            style: theme
                                .textTheme.bodyMedium
                                ?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Icon(LucideIcons.chevronRight,
                            size: 16,
                            color: theme
                                .colorScheme.onSurface
                                .withValues(alpha: 0.5)),
                      ],
                    ),
                  ),
                ),
              ),
            )),
      ],
    );
  }
}
