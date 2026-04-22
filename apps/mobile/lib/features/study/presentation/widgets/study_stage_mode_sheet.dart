import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/sizes.dart';
import '../../../../shared/widgets/app_sheet_handle.dart';
import '../../data/models/stage_model.dart';
import '../study_page.dart';

Future<String?> showStudyStageModeSheet({
  required BuildContext context,
  required StageModel stage,
  required StudyCategory category,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: AppSizes.sheetShape,
    builder: (ctx) {
      return _ModeSelectionSheet(
        stage: stage,
        category: category,
        onStart: (mode) => Navigator.pop(ctx, mode),
      );
    },
  );
}

class _ModeSelectionSheet extends StatefulWidget {
  final StageModel stage;
  final StudyCategory category;
  final ValueChanged<String> onStart;

  const _ModeSelectionSheet({
    required this.stage,
    required this.category,
    required this.onStart,
  });

  @override
  State<_ModeSelectionSheet> createState() => _ModeSelectionSheetState();
}

class _ModeSelectionSheetState extends State<_ModeSelectionSheet> {
  late String _selectedMode;

  List<_ModeInfo> get _availableModes {
    switch (widget.category) {
      case StudyCategory.vocabulary:
        return [
          const _ModeInfo(
            id: 'normal',
            label: '4지선다',
            icon: LucideIcons.listChecks,
            description: '4개 보기 중 정답을 고르세요',
          ),
          const _ModeInfo(
            id: 'matching',
            label: '매칭',
            icon: LucideIcons.shuffle,
            description: '단어와 뜻을 연결하세요',
          ),
        ];
      case StudyCategory.grammar:
        return [
          const _ModeInfo(
            id: 'normal',
            label: '4지선다',
            icon: LucideIcons.listChecks,
            description: '4개 보기 중 정답을 고르세요',
          ),
          const _ModeInfo(
            id: 'cloze',
            label: '빈칸',
            icon: LucideIcons.textCursorInput,
            description: '빈칸에 알맞은 문법을 채우세요',
          ),
        ];
      case StudyCategory.sentenceArrange:
        return [
          const _ModeInfo(
            id: 'arrange',
            label: '어순배열',
            icon: LucideIcons.arrowUpDown,
            description: '올바른 어순으로 문장을 배열하세요',
          ),
        ];
      case StudyCategory.kana:
        return [
          const _ModeInfo(
            id: 'normal',
            label: '4지선다',
            icon: LucideIcons.listChecks,
            description: '4개 보기 중 정답을 고르세요',
          ),
        ];
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedMode = _availableModes.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final modes = _availableModes;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppSheetHandle(),
                    const SizedBox(height: 20),
                    _StageModeHeader(stage: widget.stage),
                    const SizedBox(height: 20),
                    if (modes.length > 1) ...[
                      Text(
                        '학습 모드',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    ...modes.map((mode) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ModeOptionTile(
                          mode: mode,
                          isSelected: _selectedMode == mode.id,
                          onTap: () => setState(() => _selectedMode = mode.id),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: AppSizes.buttonHeight,
              child: FilledButton(
                onPressed: () => widget.onStart(_selectedMode),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '학습 시작',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      LucideIcons.flower2,
                      size: 16,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StageModeHeader extends StatelessWidget {
  final StageModel stage;

  const _StageModeHeader({required this.stage});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Stage ${stage.stageNumber}',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          stage.title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (stage.description != null) ...[
          const SizedBox(height: 4),
          Text(
            stage.description!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          '${stage.contentCount}개 항목',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

class _ModeOptionTile extends StatelessWidget {
  final _ModeInfo mode;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeOptionTile({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: isSelected
          ? theme.colorScheme.primary.withValues(alpha: 0.08)
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: Row(
            children: [
              Icon(
                mode.icon,
                size: 20,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? theme.colorScheme.primary : null,
                      ),
                    ),
                    Text(
                      mode.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  LucideIcons.check,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeInfo {
  final String id;
  final String label;
  final IconData icon;
  final String description;

  const _ModeInfo({
    required this.id,
    required this.label,
    required this.icon,
    required this.description,
  });
}
