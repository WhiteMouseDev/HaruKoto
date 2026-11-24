import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/theme/text_theme.dart';
import '../../../shared/widgets/app_error_retry.dart';
import '../data/models/achievement_model.dart';
import '../providers/my_provider.dart';

const _medalAsset = 'assets/icons/figma-home-shortcut-challenges.png';

class AchievementsPage extends ConsumerWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final background = light ? Colors.white : theme.colorScheme.surface;
    final foreground =
        light ? AppColors.redesignForeground : theme.colorScheme.onSurface;
    final achievements = ref.watch(achievementsProvider);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        titleSpacing: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: background,
        foregroundColor: foreground,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
        ),
        title: const Text(
          '도전과제',
          style: TextStyle(
            fontFamily: redesignFontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: achievements.when(
          skipLoadingOnRefresh: false,
          loading: () => Semantics(
            label: '도전과제를 불러오는 중',
            liveRegion: true,
            excludeSemantics: true,
            child: const _AchievementsContent(),
          ),
          error: (_, __) => AppErrorRetry(
            message: '도전과제를 불러올 수 없습니다',
            onRetry: () => ref.invalidate(achievementsProvider),
          ),
          data: (items) => items.isEmpty
              ? const Center(child: Text('아직 표시할 도전과제가 없어요.'))
              : _AchievementsContent(items: items),
        ),
      ),
    );
  }
}

class _AchievementsContent extends StatelessWidget {
  const _AchievementsContent({this.items});

  final List<AchievementItem>? items;

  @override
  Widget build(BuildContext context) {
    final items = this.items;
    final loading = items == null;
    final count = items?.where((item) => item.achieved).length;
    final badgeCount = items?.length ?? 6;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _AchievementSummary(earned: count, total: items?.length),
        const SizedBox(height: 20),
        for (var start = 0; start < badgeCount; start += 3) ...[
          if (start != 0) const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var column = 0; column < 3; column++) ...[
                if (column != 0) const SizedBox(width: 10),
                Expanded(
                  child: loading
                      ? const _BadgePlaceholder()
                      : start + column < items.length
                          ? _AchievementTile(item: items[start + column])
                          : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _AchievementSummary extends StatelessWidget {
  const _AchievementSummary({required this.earned, required this.total});

  final int? earned;
  final int? total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final foreground =
        light ? AppColors.redesignForeground : theme.colorScheme.onSurface;
    final muted = light
        ? AppColors.redesignMutedForeground
        : theme.colorScheme.onSurfaceVariant;
    final earned = this.earned;
    final total = this.total;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: light
            ? AppColors.redesignSurface
            : theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Column(
          children: [
            if (earned != null && total != null) ...[
              Image.asset(
                _medalAsset,
                width: 23.45,
                height: 30,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
              const SizedBox(height: 6),
              Text(
                '$earned개 달성',
                textAlign: TextAlign.center,
                style: _achievementText(16, foreground, FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                '$earned / $total',
                semanticsLabel: '전체 $total개 중 $earned개',
                style: _achievementText(12, muted),
              ),
            ] else ...[
              const _LoadingMark(width: 23.45, height: 30),
              const SizedBox(height: 8),
              const _LoadingMark(width: 56, height: 18),
              const SizedBox(height: 6),
              const _LoadingMark(width: 34, height: 13),
            ],
          ],
        ),
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.item});

  final AchievementItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final foreground =
        light ? AppColors.redesignForeground : theme.colorScheme.onSurface;
    final muted = light
        ? AppColors.redesignMutedForeground
        : theme.colorScheme.onSurfaceVariant;
    final date =
        item.achieved ? DateTime.tryParse(item.achievedAt ?? '') : null;
    final dateLabel = date == null ? null : _formatDate(date);
    final status = item.achieved ? '달성' : '미달성';

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: [item.title, status, if (dateLabel != null) dateLabel].join(', '),
      child: Column(
        children: [
          _BadgeCircle(
            child: item.achieved
                ? _UnlockedBadge(item: item)
                : Image.asset(
                    _medalAsset,
                    width: 24,
                    height: 31,
                    fit: BoxFit.contain,
                    color: light ? const Color(0xFFA5A5AF) : muted,
                    excludeFromSemantics: true,
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            textAlign: TextAlign.center,
            style: _achievementText(12, item.achieved ? foreground : muted,
                item.achieved ? FontWeight.w600 : FontWeight.w400),
          ),
          const SizedBox(height: 3),
          Text(
            dateLabel ?? '-',
            textAlign: TextAlign.center,
            style: _achievementText(10, muted),
          ),
        ],
      ),
    );
  }
}

class _BadgeCircle extends StatelessWidget {
  const _BadgeCircle({this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.brightness == Brightness.light
        ? AppColors.redesignControl
        : theme.colorScheme.surfaceContainerHigh;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 100),
      child: AspectRatio(
        aspectRatio: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _UnlockedBadge extends StatelessWidget {
  const _UnlockedBadge({required this.item});

  final AchievementItem item;

  @override
  Widget build(BuildContext context) {
    if (item.type == 'first_quiz') {
      return SizedBox(
        width: 38,
        height: 34,
        child: Stack(
          children: [
            Image.asset(
              'assets/icons/figma-practice-hero.png',
              width: 32,
              height: 29,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
            const Positioned(
              bottom: 0,
              right: 0,
              child: CircleAvatar(
                radius: 8,
                backgroundColor: AppColors.redesignGrammar,
                child: Icon(LucideIcons.check, size: 9, color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    final (icon, color) = switch (item.emoji) {
      'target' => (LucideIcons.target, AppColors.redesignVocabulary),
      'file-text' => (LucideIcons.fileText, AppColors.redesignSentence),
      'library' => (LucideIcons.library, AppColors.redesignSentence),
      'trophy' => (LucideIcons.trophy, AppColors.amberPressed),
      'check-check' => (LucideIcons.checkCheck, AppColors.redesignGrammar),
      'message-circle' || 'messageCircle' => (
          LucideIcons.messageCircle,
          AppColors.redesignVocabulary
        ),
      'messages-square' => (
          LucideIcons.messagesSquare,
          AppColors.redesignVocabulary
        ),
      'mic' => (LucideIcons.mic, AppColors.redesignVocabulary),
      'flame' => (LucideIcons.flame, AppColors.redesignVocabulary),
      'zap' => (LucideIcons.zap, AppColors.amberPressed),
      'sparkles' => (LucideIcons.sparkles, AppColors.amberPressed),
      'crown' => (LucideIcons.crown, AppColors.amberPressed),
      'book-open' || 'bookOpen' => (
          LucideIcons.bookOpen,
          AppColors.redesignSentence
        ),
      'book-marked' => (LucideIcons.bookMarked, AppColors.redesignSentence),
      'star' => (LucideIcons.star, AppColors.amberPressed),
      'moon' => (LucideIcons.moon, AppColors.redesignSentence),
      'flower-2' => (LucideIcons.flower2, AppColors.redesignVocabulary),
      'gem' => (LucideIcons.gem, AppColors.redesignSentence),
      'medal' => (LucideIcons.medal, AppColors.amberPressed),
      'sprout' => (LucideIcons.sprout, AppColors.redesignGrammar),
      _ => (LucideIcons.award, AppColors.amberPressed),
    };
    return Icon(icon, size: 28, color: color);
  }
}

class _BadgePlaceholder extends StatelessWidget {
  const _BadgePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _BadgeCircle(),
        SizedBox(height: 9),
        _LoadingMark(width: 60, height: 11),
      ],
    );
  }
}

class _LoadingMark extends StatelessWidget {
  const _LoadingMark({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light
            ? AppColors.redesignControl
            : theme.colorScheme.outlineVariant,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

TextStyle _achievementText(
  double size,
  Color color, [
  FontWeight weight = FontWeight.w400,
]) =>
    TextStyle(
      fontFamily: redesignFontFamily,
      fontSize: size,
      color: color,
      fontWeight: weight,
      height: 1.4,
    );

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}.$month.$day';
}
