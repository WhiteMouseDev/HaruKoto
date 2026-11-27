import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/current_account_provider.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/haru_typography.dart';
import '../../../../shared/widgets/app_skeleton.dart';
import '../../data/models/wordbook_entry_model.dart';
import '../../providers/study_provider.dart';
import 'wordbook_entry_dialog.dart';

class WordbookEntryDetail extends ConsumerStatefulWidget {
  const WordbookEntryDetail({
    super.key,
    required this.entryId,
    required this.owner,
    required this.onUpdated,
    required this.onDeleted,
  });

  final String entryId;
  final String owner;
  final VoidCallback onUpdated;
  final VoidCallback onDeleted;

  @override
  ConsumerState<WordbookEntryDetail> createState() =>
      _WordbookEntryDetailState();
}

class _WordbookEntryDetailState extends ConsumerState<WordbookEntryDetail> {
  late Future<WordbookEntryModel> _detail;
  bool _working = false;
  String? _deleteError;

  bool get _isCurrent =>
      mounted && ref.read(currentAccountReaderProvider)() == widget.owner;

  @override
  void initState() {
    super.initState();
    _detail = _fetch();
  }

  Future<WordbookEntryModel> _fetch() async {
    if (!_isCurrent) throw const ApiException(message: '계정이 변경되었어요.');
    return ref.read(studyRepositoryProvider).fetchWordbookEntry(widget.entryId);
  }

  void _reload() {
    final detail = _fetch();
    setState(() {
      _detail = detail;
    });
  }

  Future<void> _edit(WordbookEntryModel entry) async {
    if (_working || !_isCurrent || entry.source != 'MANUAL') return;
    final onUpdated = widget.onUpdated;
    setState(() {
      _working = true;
      _deleteError = null;
    });
    try {
      final saved = await showWordbookEntryDialog(
        context,
        entry: entry,
        onSave: (fields) {
          if (!_isCurrent) throw const ApiException(message: '계정이 변경되었어요.');
          return ref.read(studyRepositoryProvider).updateWordbookEntry(
                widget.entryId,
                word: fields.word,
                reading: fields.reading,
                meaningKo: fields.meaningKo,
              );
        },
      );
      if (!saved) return;
      onUpdated();
      if (_isCurrent) _reload();
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _delete() async {
    if (_working || !_isCurrent) return;
    final onDeleted = widget.onDeleted;
    setState(() {
      _working = true;
      _deleteError = null;
    });
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const Text('단어를 삭제할까요?', style: HaruTypography.krTitle2),
          content: const Text('단어장에서 이 항목을 삭제합니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('삭제'),
            ),
          ],
        ),
      );
      if (confirmed != true || !_isCurrent) return;
      await ref.read(studyRepositoryProvider).deleteWord(widget.entryId);
      onDeleted();
    } catch (_) {
      if (_isCurrent) {
        setState(() => _deleteError = '삭제하지 못했어요. 잠시 후 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(currentAccountIdProvider);
    if (owner != widget.owner || !_isCurrent) return const SizedBox.shrink();

    return FutureBuilder<WordbookEntryModel>(
      future: _detail,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Padding(
            padding: const EdgeInsets.only(top: AppSizes.sm),
            child: Semantics(
              label: '단어를 불러오는 중',
              liveRegion: true,
              child: const AppSkeletonBlock(
                width: double.infinity,
                height: 72,
                radius: AppSizes.radiusSm,
              ),
            ),
          );
        }
        if (snapshot.data case final entry?) return _content(context, entry);
        final apiError = switch (snapshot.error) {
          final ApiException exception => exception,
          final DioException exception =>
            ApiException.fromDioException(exception),
          _ => null,
        };
        final missing = apiError?.statusCode == 404;
        return Padding(
          padding: const EdgeInsets.only(top: AppSizes.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  missing ? '저장된 단어를 찾을 수 없어요.' : '단어를 불러올 수 없어요.',
                  style: HaruTypography.krBody3,
                ),
              ),
              if (!missing)
                TextButton(
                  onPressed: _reload,
                  child: const Text('다시 시도하기'),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _content(BuildContext context, WordbookEntryModel entry) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final colors = theme.colorScheme;
    final foreground = light ? AppColors.redesignForeground : colors.onSurface;
    final secondary =
        light ? AppColors.redesignMutedForeground : colors.onSurfaceVariant;
    final outline = light ? AppColors.redesignOutline : colors.outline;
    final example = entry.exampleSentence?.trim() ?? '';
    final translation = entry.exampleTranslation?.trim() ?? '';
    final note = entry.note?.trim() ?? '';
    const minimumSize = Size(64, 32);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (example.isNotEmpty) ...[
          Text('예문',
              style: HaruTypography.krBody3
                  .copyWith(color: foreground, fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSizes.xs),
          Text(example,
              style: HaruTypography.jpBody3.copyWith(color: foreground)),
          if (translation.isNotEmpty)
            Text(translation,
                style: HaruTypography.krBody3.copyWith(color: secondary)),
          const SizedBox(height: AppSizes.sm),
        ],
        if (note.isNotEmpty)
          DecoratedBox(
            decoration: BoxDecoration(
              color: light
                  ? AppColors.redesignSurface
                  : colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('메모',
                      style: HaruTypography.krBody3.copyWith(
                          color: foreground, fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppSizes.xs),
                  Text(note,
                      style: HaruTypography.krBody3.copyWith(color: secondary)),
                ],
              ),
            ),
          ),
        if (_deleteError case final message?)
          Semantics(
            liveRegion: true,
            child: Text(message,
                style: HaruTypography.krBody3.copyWith(color: colors.error)),
          ),
        Center(
          child: Wrap(
            spacing: AppSizes.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton(
                onPressed: _working ? null : _delete,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: outline),
                  foregroundColor: foreground,
                  minimumSize: minimumSize,
                  tapTargetSize: MaterialTapTargetSize.padded,
                  visualDensity: VisualDensity.standard,
                  textStyle: HaruTypography.krCompactButton,
                ),
                child: const Text('삭제'),
              ),
              if (entry.source == 'MANUAL')
                FilledButton(
                  onPressed: _working ? null : () => _edit(entry),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        light ? AppColors.redesignStrong : colors.onSurface,
                    foregroundColor: light ? Colors.white : colors.surface,
                    minimumSize: minimumSize,
                    tapTargetSize: MaterialTapTargetSize.padded,
                    visualDensity: VisualDensity.standard,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.md, vertical: AppSizes.xs),
                    textStyle: HaruTypography.krCompactButton,
                  ),
                  child: const Text('수정'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
