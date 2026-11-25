import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/auth/current_account_provider.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/providers/user_preferences_provider.dart';
import '../../../../core/theme/text_theme.dart';
import '../../../../shared/widgets/app_sheet_handle.dart';
import '../../domain/lesson_recommendation.dart';
import '../../domain/saved_lesson_entry.dart';
import '../../providers/saved_lesson_entry_provider.dart';
import 'lesson_continue_banner.dart';

/// Displays the current level's local checkpoints and server recommendation.
class SavedLessonSection extends ConsumerStatefulWidget {
  const SavedLessonSection(
      {super.key,
      required this.jlptLevel,
      this.recommendedLesson,
      this.compact = false,
      this.redesigned = false});
  final String jlptLevel;
  final RecommendedLessonTarget? recommendedLesson;
  final bool compact;
  final bool redesigned;

  @override
  ConsumerState<SavedLessonSection> createState() => _SavedLessonSectionState();
}

class _SavedLessonSectionState extends ConsumerState<SavedLessonSection> {
  bool _opening = false;
  String get jlptLevel => widget.jlptLevel;

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(currentAccountIdProvider);
    final entries = ref.watch(savedLessonEntriesProvider(jlptLevel));
    ref.watch(userPreferencesProvider);
    if (owner == null || !_scopeCurrent(owner)) return const SizedBox.shrink();
    Widget? unavailable({VoidCallback? retry}) => widget.redesigned
        ? (retry == null ? null : _retry(context, retry))
        : _fallback(context, owner, retry: retry);

    final saved = entries.when<Widget?>(
      skipLoadingOnRefresh: false,
      skipLoadingOnReload: false,
      loading: unavailable,
      error: (_, __) => unavailable(retry: () {
        if (!mounted || !_scopeCurrent(owner)) return;
        ref.invalidate(savedLessonEntriesProvider(jlptLevel));
      }),
      data: (data) {
        if (data.accountId != owner ||
            data.jlptLevel != jlptLevel ||
            data.entries.any((entry) =>
                entry.accountId != owner || entry.jlptLevel != jlptLevel)) {
          return null;
        }
        void retry() {
          if (!mounted || !_scopeCurrent(owner)) return;
          for (final id in data.failedLessonIds) {
            ref.invalidate(
                savedLessonLookupProvider((accountId: owner, lessonId: id)));
          }
        }

        if (data.entries.isEmpty) {
          return unavailable(
              retry: data.failedLessonIds.isEmpty ? null : retry);
        }
        if (widget.redesigned) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SavedLessonExpansion(
                key: PageStorageKey((owner, jlptLevel)),
                entries: data.entries,
                onOpen: (entry) => _open(context, ref, entry),
              ),
              if (data.failedLessonIds.isNotEmpty) ...[
                const SizedBox(height: 8),
                _retry(context, retry),
              ],
            ],
          );
        }
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Text('이어서 학습하기',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    TextButton(
                      onPressed: () => _choose(context, ref, data.entries),
                      style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.onSurface),
                      child: Text('모두 보기 · ${data.entries.length}개'),
                    ),
                  ]),
              const SizedBox(height: 4),
              _SavedEntryTile(
                  entry: data.entries.first,
                  onTap: () => _open(context, ref, data.entries.first)),
              if (data.failedLessonIds.isNotEmpty) ...[
                const SizedBox(height: 8),
                _retry(context, retry),
              ],
            ],
          ),
        );
      },
    );
    if (!widget.redesigned) return saved ?? const SizedBox.shrink();

    final target = _recommendation;
    if (target == null && saved == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (target != null)
            LessonContinueBanner(
              target: target,
              redesigned: true,
              onTap: () => _openRecommended(context, owner, target),
            ),
          if (target != null && saved != null) const SizedBox(height: 12),
          if (saved != null) saved,
        ],
      ),
    );
  }

  RecommendedLessonTarget? get _recommendation {
    final candidate = widget.recommendedLesson;
    return candidate?.chapter.jlptLevel == jlptLevel ? candidate : null;
  }

  Widget _fallback(BuildContext context, String owner, {VoidCallback? retry}) {
    final target = _recommendation;
    if (target == null && retry == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (target != null)
          LessonContinueBanner(
              target: target,
              compact: widget.compact,
              onTap: () => _openRecommended(context, owner, target)),
        if (retry != null) ...[
          if (target != null) const SizedBox(height: 8),
          _retry(context, retry),
        ],
      ]),
    );
  }

  Widget _retry(BuildContext context, VoidCallback retry) => Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('일부 저장 위치를 확인하지 못했어요.'),
          TextButton(
              onPressed: retry,
              style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface),
              child: const Text('저장 위치 다시 확인')),
        ],
      );

  bool _scopeCurrent(String? owner) =>
      owner != null &&
      ref.read(currentAccountReaderProvider)() == owner &&
      ref.read(currentAccountIdProvider) == owner &&
      ref.read(userPreferencesProvider).jlptLevel == jlptLevel;

  bool _current(WidgetRef ref, SavedLessonEntry entry) =>
      _scopeCurrent(entry.accountId) && entry.jlptLevel == jlptLevel;

  Future<void> _openRecommended(BuildContext context, String owner,
      RecommendedLessonTarget target) async {
    if (!mounted ||
        !context.mounted ||
        _opening ||
        !_scopeCurrent(owner) ||
        target.chapter.jlptLevel != jlptLevel) {
      return;
    }
    _opening = true;
    try {
      await context.push<void>('/study/lessons/${target.lesson.id}');
      if (!context.mounted ||
          !_scopeCurrent(owner) ||
          target.chapter.jlptLevel != jlptLevel) {
        return;
      }
      ref.invalidate(savedLessonLookupProvider(
          (accountId: owner, lessonId: target.lesson.id)));
    } finally {
      _opening = false;
    }
  }

  Future<void> _open(
      BuildContext context, WidgetRef ref, SavedLessonEntry entry) async {
    if (!mounted || !context.mounted || _opening || !_current(ref, entry)) {
      return;
    }
    _opening = true;
    try {
      await context.push<void>('/study/lessons/${entry.lesson.id}');
      if (!context.mounted || !_current(ref, entry)) return;
      ref.invalidate(savedLessonLookupProvider(
          (accountId: entry.accountId, lessonId: entry.lesson.id)));
    } finally {
      _opening = false;
    }
  }

  Future<void> _choose(BuildContext context, WidgetRef ref,
      List<SavedLessonEntry> entries) async {
    if (!mounted ||
        !context.mounted ||
        _opening ||
        entries.isEmpty ||
        !_current(ref, entries.first)) {
      return;
    }
    _opening = true;
    SavedLessonEntry? selected;
    try {
      selected = await showModalBottomSheet<SavedLessonEntry>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        builder: (_) => _SavedLessonPicker(entries: entries),
      );
    } finally {
      _opening = false;
    }
    // The sheet only returns a selection. Navigation happens here, after await.
    if (!context.mounted || selected == null || !_current(ref, selected)) {
      return;
    }
    await _open(context, ref, selected);
  }
}

class _SavedLessonExpansion extends StatelessWidget {
  const _SavedLessonExpansion({
    super.key,
    required this.entries,
    required this.onOpen,
  });

  final List<SavedLessonEntry> entries;
  final ValueChanged<SavedLessonEntry> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final colors = theme.colorScheme;
    final foreground = light ? AppColors.redesignForeground : colors.onSurface;
    final muted =
        light ? AppColors.redesignMutedForeground : colors.onSurfaceVariant;
    final surface = light ? AppColors.lightCard : colors.surfaceContainerLow;
    final border = BorderSide(
      color: light ? AppColors.redesignOutline : colors.outline,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: border,
    );

    return ExpansionTile(
      minTileHeight: 48,
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      backgroundColor: surface,
      collapsedBackgroundColor: surface,
      iconColor: muted,
      collapsedIconColor: muted,
      shape: shape,
      collapsedShape: shape,
      clipBehavior: Clip.antiAlias,
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      title: Text('이 기기에 저장된 레슨',
          style: TextStyle(
            fontFamily: redesignFontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.5,
            letterSpacing: -0.35,
            color: foreground,
          )),
      children: [
        for (final entry in entries) ...[
          Divider(height: 1, color: border.color),
          Padding(
            key: ValueKey(entry.lesson.id),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.lesson.title,
                          style: TextStyle(
                            fontFamily: redesignFontFamily,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                            letterSpacing: -0.375,
                            color: foreground,
                          )),
                      const SizedBox(height: 4),
                      Text(entry.hint.label,
                          style: TextStyle(
                            fontFamily: redesignFontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            height: 1.5,
                            letterSpacing: -0.325,
                            color: muted,
                          )),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    foregroundColor: foreground,
                    shape: const StadiumBorder(),
                    side: border,
                    iconAlignment: IconAlignment.end,
                    textStyle: const TextStyle(
                      fontFamily: redesignFontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                      letterSpacing: -0.3,
                    ),
                  ),
                  onPressed: () => onOpen(entry),
                  icon: const Icon(LucideIcons.chevronRight, size: 14),
                  label: const Text('열기'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SavedEntryTile extends StatelessWidget {
  const _SavedEntryTile({required this.entry, required this.onTap});
  final SavedLessonEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hint = entry.hint;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(14),
        foregroundColor: theme.colorScheme.onSurface,
        backgroundColor: theme.colorScheme.surfaceContainerLow,
        side: BorderSide(color: theme.colorScheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              entry.recoveryOnly
                  ? '${entry.jlptLevel} · 제출 결과 확인'
                  : '${entry.jlptLevel} · ${entry.chapter.chapterNo}번 역 · '
                      '${entry.lesson.chapterLessonNo}번째 레슨',
              style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.brightness == Brightness.light
                      ? AppColors.lightSubtext
                      : AppColors.darkSubtext)),
          const SizedBox(height: 5),
          Text(entry.lesson.title,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(hint.label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 10),
          Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(
                    hint.needsRecordCheck
                        ? LucideIcons.fileSearch
                        : LucideIcons.playCircle,
                    size: 18,
                    color: theme.colorScheme.primary),
                Text(hint.needsRecordCheck ? hint.actionLabel : '이어하기',
                    style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700)),
                Icon(LucideIcons.arrowRight,
                    size: 16, color: theme.colorScheme.primary),
              ]),
        ],
      ),
    );
  }
}

class _SavedLessonPicker extends ConsumerWidget {
  const _SavedLessonPicker({required this.entries});
  final List<SavedLessonEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(currentAccountIdProvider);
    final level = ref.watch(userPreferencesProvider).jlptLevel;
    final current = entries.isNotEmpty &&
        owner != null &&
        ref.read(currentAccountReaderProvider)() == owner &&
        entries.every(
            (entry) => entry.accountId == owner && entry.jlptLevel == level);
    final hasLegacy = entries.any((entry) => entry.hint.lastStudiedAt == null);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: !current
            ? const Center(child: Text('계정이나 학습 레벨이 변경됐어요. 목록을 다시 열어주세요.'))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: AppSheetHandle()),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('이어할 레슨 모두 보기',
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 6),
                            Text(
                                hasLegacy
                                    ? '최근 학습순 · 이전 저장 기록은 학습 순서'
                                    : '최근 학습한 순서예요.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: Theme.of(context).brightness ==
                                                Brightness.light
                                            ? AppColors.lightSubtext
                                            : AppColors.darkSubtext)),
                          ])),
                  Expanded(
                      child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                    itemCount: entries.length,
                    separatorBuilder: (context, _) => Divider(
                        height: 1,
                        color: Theme.of(context).colorScheme.outline),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return ListTile(
                          contentPadding: const EdgeInsets.all(8),
                          title: Text(entry.lesson.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface)),
                          subtitle: Text(
                              entry.recoveryOnly
                                  ? '${entry.jlptLevel} · ${entry.hint.label}'
                                  : '${entry.jlptLevel} · ${entry.chapter.chapterNo}번 역 · '
                                      '${entry.lesson.chapterLessonNo}번째 레슨\n${entry.hint.label}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: Theme.of(context).brightness ==
                                              Brightness.light
                                          ? AppColors.lightSubtext
                                          : AppColors.darkSubtext)),
                          trailing: Icon(LucideIcons.chevronRight,
                              color: Theme.of(context).colorScheme.onSurface),
                          onTap: () {
                            if (!context.mounted ||
                                ref.read(currentAccountIdProvider) !=
                                    entry.accountId ||
                                ref.read(currentAccountReaderProvider)() !=
                                    entry.accountId ||
                                ref.read(userPreferencesProvider).jlptLevel !=
                                    entry.jlptLevel) {
                              return;
                            }
                            Navigator.pop(context, entry);
                          });
                    },
                  )),
                ],
              ),
      ),
    );
  }
}
