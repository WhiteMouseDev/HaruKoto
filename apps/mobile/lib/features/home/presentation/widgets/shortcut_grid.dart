import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/services/haptic_service.dart';

class ShortcutGrid extends StatelessWidget {
  const ShortcutGrid({super.key});

  @override
  Widget build(BuildContext context) {
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
        onTap: () => context.push('/home/achievements'),
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
