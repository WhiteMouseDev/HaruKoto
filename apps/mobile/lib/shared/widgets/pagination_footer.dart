import 'package:flutter/material.dart';

class PaginationFooter extends StatelessWidget {
  final int page;
  final int totalPages;
  final VoidCallback onPagePrev;
  final VoidCallback onPageNext;

  const PaginationFooter({
    super.key,
    required this.page,
    required this.totalPages,
    required this.onPagePrev,
    required this.onPageNext,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton(
            onPressed: page > 1 ? onPagePrev : null,
            child: const Text('이전'),
          ),
          const SizedBox(width: 12),
          Text('$page / $totalPages', style: theme.textTheme.bodySmall),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: page < totalPages ? onPageNext : null,
            child: const Text('다음'),
          ),
        ],
      ),
    );
  }
}
