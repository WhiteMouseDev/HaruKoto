import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/auth/current_account_provider.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/providers/user_preferences_provider.dart';
import '../../domain/saved_lesson_entry.dart';
import '../../providers/saved_lesson_entry_provider.dart';

/// A separate local entry point: server recommendations and route/station
/// completion retain their original meanings.
class SavedLessonSection extends ConsumerStatefulWidget {
  const SavedLessonSection({super.key, required this.jlptLevel});
  final String jlptLevel;

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
    if (!_scopeCurrent(owner)) return const SizedBox.shrink();
    return entries.when(
      skipLoadingOnRefresh: false,
      skipLoadingOnReload: false,
      loading: () => const SizedBox.shrink(),
      error: (_, __) => _retry(context, () {
        if (!mounted || !_scopeCurrent(owner)) return;
        ref.invalidate(savedLessonEntriesProvider(jlptLevel));
      }),
      data: (data) {
        if (data.accountId != owner ||
            data.jlptLevel != jlptLevel ||
            data.entries.any((entry) =>
                entry.accountId != owner || entry.jlptLevel != jlptLevel)) {
          return const SizedBox.shrink();
        }
        if (data.entries.isEmpty && data.failedLessonIds.isEmpty) {
          return const SizedBox.shrink();
        }
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (data.entries.isNotEmpty) ...[
                Text('이 기기에 저장된 레슨',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('학습 순서대로 표시해요. 열면 저장 위치를 확인해요.',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.brightness == Brightness.light
                            ? AppColors.lightSubtext
                            : AppColors.darkSubtext)),
                const SizedBox(height: 10),
                for (final entry in data.entries.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _SavedEntryTile(
                        entry: entry, onTap: () => _open(context, ref, entry)),
                  ),
                if (data.entries.length > 3)
                  OutlinedButton(
                    onPressed: () => _choose(context, ref, data.entries),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurface),
                    child: Text('저장된 레슨 ${data.entries.length}개 모두 보기'),
                  ),
              ],
              if (data.failedLessonIds.isNotEmpty)
                _retry(context, () {
                  if (!mounted || !_scopeCurrent(owner)) return;
                  for (final id in data.failedLessonIds) {
                    ref.invalidate(savedLessonLookupProvider(
                        (accountId: owner!, lessonId: id)));
                  }
                }),
            ],
          ),
        );
      },
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
      ref.read(currentAccountReaderProvider)() == entry.accountId &&
      ref.read(currentAccountIdProvider) == entry.accountId &&
      ref.read(userPreferencesProvider).jlptLevel == entry.jlptLevel;

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
              '${entry.jlptLevel} · ${entry.chapter.chapterNo}번 역 · '
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
                Text(hint.actionLabel,
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
        owner == entries.first.accountId &&
        ref.read(currentAccountReaderProvider)() == owner &&
        level == entries.first.jlptLevel;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: !current
            ? const Center(child: Text('계정이나 학습 레벨이 변경됐어요. 목록을 다시 열어주세요.'))
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text('저장된 레슨 고르기',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  const Text('학습 순서대로 표시해요. 열면 저장 위치를 확인해요.'),
                  const SizedBox(height: 16),
                  for (final entry in entries)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SavedEntryTile(
                            entry: entry,
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
                            })),
                ],
              ),
      ),
    );
  }
}
