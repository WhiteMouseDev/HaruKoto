import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../shared/widgets/app_sheet_handle.dart';
import '../../../my/providers/my_provider.dart';

class ShortcutGrid extends ConsumerWidget {
  const ShortcutGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final shortcuts = [
      _ShortcutItem(
        icon: LucideIcons.bookMarked,
        label: '단어장',
        color: theme.colorScheme.primary,
        onTap: () => context.push('/study/wordbook'),
      ),
      _ShortcutItem(
        icon: LucideIcons.fileX,
        label: '오답노트',
        color: const Color(0xFFEF8354),
        onTap: () => context.push('/study/wrong-answers'),
      ),
      _ShortcutItem(
        icon: LucideIcons.trophy,
        label: '도전과제',
        color: const Color(0xFFEAB308),
        onTap: () => _showAchievements(context, ref),
      ),
      _ShortcutItem(
        icon: LucideIcons.grid,
        label: '가나 차트',
        color: const Color(0xFF6DB3CE),
        onTap: () => context.push('/study/kana/chart'),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.pageHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: shortcuts.map((item) {
              return Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      HapticService().selection();
                      item.onTap();
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: item.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            item.icon,
                            size: 24,
                            color: item.color,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showAchievements(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: AppSizes.sheetShape,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Consumer(
              builder: (context, ref, _) {
                final asyncValue = ref.watch(achievementsProvider);

                return asyncValue.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.alertCircle,
                          size: 48,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '도전과제를 불러올 수 없습니다',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => ref.invalidate(achievementsProvider),
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  ),
                  data: (achievements) {
                    final achievedCount =
                        achievements.where((a) => a.achieved).length;

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const AppSheetHandle(),
                              const SizedBox(height: 16),
                              Text(
                                '도전과제',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '$achievedCount/${achievements.length} 달성',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: GridView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 0.75,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemCount: achievements.length,
                            itemBuilder: (context, index) {
                              final item = achievements[index];

                              return Opacity(
                                opacity: item.achieved ? 1.0 : 0.4,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color:
                                        theme.colorScheme.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Stack(
                                    children: [
                                      Center(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                _iconForEmoji(item.emoji),
                                                size: 28,
                                                color: item.achieved
                                                    ? theme.colorScheme.primary
                                                    : theme
                                                        .colorScheme.onSurface
                                                        .withValues(alpha: 0.4),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                item.title,
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              if (item.achieved &&
                                                  item.achievedAt != null) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  _formatDate(item.achievedAt!),
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    color: theme
                                                        .colorScheme.onSurface
                                                        .withValues(alpha: 0.5),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (!item.achieved)
                                        Positioned(
                                          right: 6,
                                          top: 6,
                                          child: Icon(
                                            LucideIcons.lock,
                                            size: 12,
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.3),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final y = date.year;
      final m = date.month.toString().padLeft(2, '0');
      final d = date.day.toString().padLeft(2, '0');
      return '$y.$m.$d';
    } catch (_) {
      return '';
    }
  }

  IconData _iconForEmoji(String emoji) {
    switch (emoji) {
      case 'target':
        return LucideIcons.target;
      case 'trophy':
        return LucideIcons.trophy;
      case 'star':
        return LucideIcons.star;
      case 'messageCircle':
        return LucideIcons.messageCircle;
      case 'flame':
        return LucideIcons.flame;
      case 'bookOpen':
        return LucideIcons.bookOpen;
      case 'zap':
        return LucideIcons.zap;
      default:
        return LucideIcons.award;
    }
  }
}

class _ShortcutItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShortcutItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}
