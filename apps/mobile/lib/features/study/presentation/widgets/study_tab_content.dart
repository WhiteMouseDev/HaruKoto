import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../shared/widgets/app_error_retry.dart';
import '../../../../shared/widgets/app_sheet_handle.dart';
import '../../data/models/stage_model.dart';
import '../../providers/study_provider.dart';
import '../quiz_launch.dart';
import '../study_page.dart';

/// Content for each study category tab (vocabulary, grammar, sentence arrange).
/// Shows a vertical list of stage cards fetched from the API.
class StudyTabContent extends ConsumerWidget {
  final StudyCategory category;
  final String jlptLevel;

  const StudyTabContent({
    super.key,
    required this.category,
    required this.jlptLevel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stagesAsync = ref.watch(
      stagesProvider((category: category.apiType, jlptLevel: jlptLevel)),
    );

    return stagesAsync.when(
      loading: () => const _StageListSkeleton(),
      error: (error, _) => AppErrorRetry(
        onRetry: () => ref.invalidate(
          stagesProvider((category: category.apiType, jlptLevel: jlptLevel)),
        ),
      ),
      data: (stages) {
        if (stages.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.bookOpen,
                    size: 48,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '준비 중인 콘텐츠입니다',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: stages.length,
          itemBuilder: (context, index) {
            final stage = stages[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _StageCard(
                stage: stage,
                category: category,
                jlptLevel: jlptLevel,
              ),
            );
          },
        );
      },
    );
  }
}

/// A single stage card showing stage number, title, progress, and lock status.
class _StageCard extends ConsumerWidget {
  final StageModel stage;
  final StudyCategory category;
  final String jlptLevel;

  const _StageCard({
    required this.stage,
    required this.category,
    required this.jlptLevel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isCurrent = !stage.isLocked && !stage.isCompleted;

    // Determine card style based on state
    final Color borderColor;
    final Color bgColor;
    final double borderWidth;

    if (stage.isLocked) {
      borderColor = theme.colorScheme.outline.withValues(alpha: 0.3);
      bgColor = theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.3);
      borderWidth = 1;
    } else if (stage.isCompleted) {
      borderColor = AppColors.success(theme.brightness).withValues(alpha: 0.3);
      bgColor = AppColors.success(theme.brightness).withValues(alpha: 0.04);
      borderWidth = 1;
    } else {
      // Current / active stage
      borderColor = theme.colorScheme.primary;
      bgColor = theme.colorScheme.primary.withValues(alpha: 0.04);
      borderWidth = 2;
    }

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        onTap: stage.isLocked ? null : () => _showModeSheet(context, ref),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: borderWidth),
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: Row(
            children: [
              // Stage number badge
              _StageBadge(
                stageNumber: stage.stageNumber,
                isLocked: stage.isLocked,
                isCompleted: stage.isCompleted,
                isCurrent: isCurrent,
              ),
              const SizedBox(width: 14),
              // Title and info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stage.title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight:
                            isCurrent ? FontWeight.bold : FontWeight.w500,
                        color: stage.isLocked
                            ? theme.colorScheme.onSurface
                                .withValues(alpha: 0.35)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${stage.contentCount}개 항목',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: stage.isLocked
                                ? theme.colorScheme.onSurface
                                    .withValues(alpha: 0.25)
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                          ),
                        ),
                        if (stage.userProgress != null &&
                            stage.userProgress!.attempts > 0) ...[
                          const SizedBox(width: 12),
                          Text(
                            '${stage.userProgress!.attempts}회 도전',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ],
                    ),
                    // Progress bar for non-locked stages with progress
                    if (!stage.isLocked && stage.bestScore > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: stage.bestScore / 100,
                                minHeight: 6,
                                backgroundColor:
                                    theme.colorScheme.surfaceContainerHigh,
                                color: stage.isCompleted
                                    ? AppColors.success(theme.brightness)
                                    : theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${stage.bestScore}%',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: stage.isCompleted
                                  ? AppColors.success(theme.brightness)
                                  : theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Right indicator
              if (stage.isLocked)
                Icon(
                  LucideIcons.lock,
                  size: 18,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                )
              else if (stage.isCompleted)
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.success(theme.brightness)
                        .withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.check,
                    size: 16,
                    color: AppColors.success(theme.brightness),
                  ),
                )
              else
                Icon(
                  LucideIcons.chevronRight,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showModeSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: AppSizes.sheetShape,
      builder: (ctx) {
        return _ModeSelectionSheet(
          stage: stage,
          category: category,
          jlptLevel: jlptLevel,
          onStart: (mode) {
            Navigator.pop(ctx);
            _startStageQuiz(context, ref, mode);
          },
        );
      },
    );
  }

  void _startStageQuiz(BuildContext context, WidgetRef ref, String mode) {
    openQuizPageForSession(
      context,
      quizType: category.apiType,
      jlptLevel: jlptLevel,
      count: stage.contentCount > 0 ? stage.contentCount : 10,
      mode: mode != 'normal' ? mode : null,
      stageId: stage.id,
    ).then((_) {
      // Refresh stages after quiz completion
      ref.invalidate(
        stagesProvider((category: category.apiType, jlptLevel: jlptLevel)),
      );
    });
  }
}

/// Circular badge showing stage number, lock icon, or check.
class _StageBadge extends StatelessWidget {
  final int stageNumber;
  final bool isLocked;
  final bool isCompleted;
  final bool isCurrent;

  const _StageBadge({
    required this.stageNumber,
    required this.isLocked,
    required this.isCompleted,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color bgColor;
    final Color textColor;

    if (isLocked) {
      bgColor = theme.colorScheme.surfaceContainerHigh;
      textColor = theme.colorScheme.onSurface.withValues(alpha: 0.3);
    } else if (isCompleted) {
      bgColor = AppColors.success(theme.brightness).withValues(alpha: 0.1);
      textColor = AppColors.success(theme.brightness);
    } else {
      bgColor = theme.colorScheme.primary.withValues(alpha: 0.1);
      textColor = theme.colorScheme.primary;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$stageNumber',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for selecting quiz mode before starting a stage.
class _ModeSelectionSheet extends StatefulWidget {
  final StageModel stage;
  final StudyCategory category;
  final String jlptLevel;
  final ValueChanged<String> onStart;

  const _ModeSelectionSheet({
    required this.stage,
    required this.category,
    required this.jlptLevel,
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
            // 스크롤 가능한 콘텐츠 영역
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    const AppSheetHandle(),
                    const SizedBox(height: 20),
                    // Stage title
                    Text(
                      'Stage ${widget.stage.stageNumber}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.stage.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.stage.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.stage.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '${widget.stage.contentCount}개 항목',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Mode selector
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
                      final isSelected = _selectedMode == mode.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: isSelected
                              ? theme.colorScheme.primary
                                  .withValues(alpha: 0.08)
                              : theme.colorScheme.surface,
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusMd),
                          child: InkWell(
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusMd),
                            onTap: () =>
                                setState(() => _selectedMode = mode.id),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.outline,
                                  width: isSelected ? 2 : 1,
                                ),
                                borderRadius:
                                    BorderRadius.circular(AppSizes.radiusMd),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    mode.icon,
                                    size: 20,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface
                                            .withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          mode.label,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: isSelected
                                                ? theme.colorScheme.primary
                                                : null,
                                          ),
                                        ),
                                        Text(
                                          mode.description,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.5),
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
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            // 하단 고정 버튼
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

/// Skeleton loader for the stage list.
class _StageListSkeleton extends StatelessWidget {
  const _StageListSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: List.generate(
        5,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
          ),
        ),
      ),
    );
  }
}
