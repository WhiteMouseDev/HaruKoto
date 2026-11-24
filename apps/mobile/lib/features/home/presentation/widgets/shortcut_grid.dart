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
        iconAsset: 'assets/icons/figma-home-shortcut-words.png',
        label: '단어장',
        onTap: () => context.push('/study/wordbook'),
      ),
      _ShortcutItem(
        iconAsset: 'assets/icons/figma-home-shortcut-review.png',
        label: '오답노트',
        onTap: () => context.push('/study/wrong-answers'),
      ),
      _ShortcutItem(
        iconAsset: 'assets/icons/figma-home-shortcut-challenges.png',
        label: '도전과제',
        onTap: () => _showAchievements(context, ref),
      ),
      _ShortcutItem(
        iconAsset: 'assets/icons/figma-home-shortcut-kana.png',
        label: '가나차트',
        onTap: () => context.push('/study/kana/chart'),
      ),
    ];

    return Padding(
      padding: AppSizes.pageHorizontalEdge,
      child: Column(
        children: [
          Text(
            '학습 도우미',
            style: theme.textTheme.titleLarge?.copyWith(
              fontFamily: 'Pretendard',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              height: 1.4,
              letterSpacing: -0.5,
              color: _shortcutForeground(theme),
            ),
          ),
          const SizedBox(height: 16),
          for (var row = 0; row < 2; row++) ...[
            if (row != 0) const SizedBox(height: 8),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _ShortcutTile(item: shortcuts[2 * row])),
                  const SizedBox(width: 8),
                  Expanded(child: _ShortcutTile(item: shortcuts[2 * row + 1])),
                ],
              ),
            ),
          ],
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

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({required this.item});

  final _ShortcutItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.brightness == Brightness.light
        ? const Color(0xFFE5E5EC)
        : theme.colorScheme.outline;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: borderColor),
    );

    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticService().selection();
          item.onTap();
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 66),
          padding: const EdgeInsets.fromLTRB(22, 12, 20, 12),
          child: Row(
            children: [
              Image.asset(
                item.iconAsset,
                width: 24,
                height: 24,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
              const SizedBox(width: 11),
              Flexible(
                child: Text(
                  item.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    height: 1.4,
                    letterSpacing: -0.35,
                    color: _shortcutForeground(theme),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShortcutItem {
  final String iconAsset;
  final String label;
  final VoidCallback onTap;

  const _ShortcutItem({
    required this.iconAsset,
    required this.label,
    required this.onTap,
  });
}

Color _shortcutForeground(ThemeData theme) =>
    theme.brightness == Brightness.light
        ? const Color(0xFF111111)
        : theme.colorScheme.onSurface;
