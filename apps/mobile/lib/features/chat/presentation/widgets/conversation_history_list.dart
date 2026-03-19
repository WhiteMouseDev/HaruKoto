import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/constants/character_assets.dart';
import '../../data/models/conversation_model.dart';
import '../../providers/chat_provider.dart';

class ConversationHistoryList extends ConsumerWidget {
  final String? filter; // 'voice' | 'text'

  const ConversationHistoryList({super.key, this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final historyAsync = ref.watch(chatHistoryProvider);

    return historyAsync.when(
      loading: () => Column(
        children: List.generate(
          3,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.sm),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
            ),
          ),
        ),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.lg),
        child: Center(
          child: Text(
            '기록을 불러올 수 없습니다.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
      data: (items) {
        final filtered = filter != null
            ? items.where((item) {
                if (filter == 'voice') return item.type == 'VOICE';
                return item.type == 'TEXT';
              }).toList()
            : items;

        if (filtered.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.lg),
            child: Center(
              child: Text(
                '아직 회화 기록이 없어요.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          );
        }

        return Column(
          children: filtered.map((item) => _HistoryItem(item: item)).toList(),
        );
      },
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final ConversationModel item;

  const _HistoryItem({required this.item});

  Widget _buildAvatar(ConversationModel item, bool isVoice) {
    final localPath = CharacterAssets.pathFor(item.character?.name);
    if (localPath != null) {
      return ClipOval(
        child: Image.asset(
          localPath,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
        ),
      );
    }
    if (item.character?.avatarUrl != null) {
      return ClipOval(
        child: Image.network(
          item.character!.avatarUrl!,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(LucideIcons.phone, size: 16, color: AppColors.primary),
        ),
      );
    }
    return Icon(
      isVoice ? LucideIcons.phone : LucideIcons.messageSquare,
      size: 16,
      color: AppColors.primary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isVoice = item.scenario == null || item.scenario!.category == 'FREE';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          onTap: () {
            HapticService().selection();
            context.go('/chat/${item.id}/feedback');
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: _buildAvatar(item, isVoice),
                  ),
                ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.character != null
                            ? '${item.character!.name}와의 통화'
                            : item.scenario?.title ?? '음성 통화',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(LucideIcons.clock,
                              size: 12,
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.5)),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(item.createdAt),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${item.messageCount}턴',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Score
                if (item.overallScore != null) ...[
                  _ScoreBadge(score: item.overallScore!),
                  const SizedBox(width: 4),
                ],
                Icon(LucideIcons.chevronRight,
                    size: 16,
                    color: colorScheme.onSurface.withValues(alpha: 0.4)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      final month = d.month;
      final day = d.day;
      final hours = d.hour.toString().padLeft(2, '0');
      final mins = d.minute.toString().padLeft(2, '0');
      return '$month/$day $hours:$mins';
    } catch (_) {
      return dateStr;
    }
  }
}

class _ScoreBadge extends StatelessWidget {
  final int score;

  const _ScoreBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    final stars = (score / 100 * 5 * 10).round() / 10;
    final color = score >= 80
        ? AppColors.hkYellowLight
        : score >= 50
            ? AppColors.scoreMid
            : AppColors.overlay(0.5);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(LucideIcons.star, size: 12, color: color),
        const SizedBox(width: 2),
        Text(
          stars.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
