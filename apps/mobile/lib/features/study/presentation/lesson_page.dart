import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/providers/user_preferences_provider.dart';
import '../data/learning_goals.dart';
import '../data/models/lesson_models.dart';
import '../providers/lesson_session_provider.dart';
import '../providers/study_provider.dart';

/// 레슨 학습 플로우: 6-Step (상황 프리뷰 → 가이드 리딩 → 이해 체크 → 매칭 게임 → 문장 재구성 → 결과)
class LessonPage extends ConsumerStatefulWidget {
  final String lessonId;
  const LessonPage({super.key, required this.lessonId});

  @override
  ConsumerState<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends ConsumerState<LessonPage> {
  static const _totalSteps = 6;

  @override
  void dispose() {
    final container = ProviderScope.containerOf(context, listen: false);
    Future(() => container.invalidate(lessonSessionProvider));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(lessonDetailProvider(widget.lessonId));
    final session = ref.watch(lessonSessionProvider);

    return PopScope(
      canPop: session.canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ref.read(lessonSessionProvider.notifier).goBack();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: detailAsync.when(
            data: (d) => Text(d.title),
            loading: () => const Text('레슨'),
            error: (_, __) => const Text('레슨'),
          ),
          leading: IconButton(
            icon: const Icon(LucideIcons.x),
            onPressed: () => context.pop(),
          ),
        ),
        body: detailAsync.when(
          data: (detail) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.md,
                  vertical: AppSizes.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _StepProgressBar(
                        currentStep: session.step.index,
                        totalSteps: _totalSteps,
                      ),
                    ),
                    if (session.showDialogueShortcut) ...[
                      const SizedBox(width: AppSizes.sm),
                      GestureDetector(
                        onTap: () => _showDialogueSheet(context, detail),
                        child: const Icon(
                          LucideIcons.messageSquare,
                          size: 18,
                          color: AppColors.primaryStrong,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildStep(
                    context,
                    ref,
                    detail,
                    session,
                  ),
                ),
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('오류: $e')),
        ),
      ),
    );
  }

  Widget _buildStep(
    BuildContext context,
    WidgetRef ref,
    LessonDetailModel detail,
    LessonSessionState session,
  ) {
    switch (session.step) {
      case LessonStep.contextPreview:
        return _ContextPreviewStep(
          key: const ValueKey('step-0'),
          detail: detail,
          onNext: () =>
              ref.read(lessonSessionProvider.notifier).goToGuidedReading(),
        );
      case LessonStep.guidedReading:
        return _GuidedReadingStep(
          key: const ValueKey('step-1'),
          detail: detail,
          onNext: () {
            unawaited(
              ref.read(lessonSessionProvider.notifier).startPractice(detail),
            );
          },
        );
      case LessonStep.recognition:
        final recognitionQs = lessonRecognitionQuestions(detail);
        if (recognitionQs.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(lessonSessionProvider.notifier).skipRecognition();
          });
          return const SizedBox.shrink(key: ValueKey('step-2-skip'));
        }
        return _RecognitionCheckStep(
          key: ValueKey('step-2-${session.recognitionIndex}'),
          questions: recognitionQs,
          currentIndex: session.recognitionIndex,
          totalSteps: _totalSteps,
          onAnswer: (answer) => ref
              .read(lessonSessionProvider.notifier)
              .answerRecognition(detail, answer),
        );
      case LessonStep.matching:
        return _MatchingGameStep(
          key: const ValueKey('step-3'),
          vocabItems: detail.vocabItems,
          onComplete: () {
            unawaited(_handleMatchingComplete(context, ref, detail));
          },
        );
      case LessonStep.sentenceReorder:
        final reorderQs = lessonReorderQuestions(detail);
        if (reorderQs.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(_submitLesson(context, ref, detail));
          });
          return const SizedBox.shrink(key: ValueKey('step-4-skip'));
        }
        return _SentenceReorderStep(
          key: ValueKey('step-4-${session.reorderIndex}'),
          questions: reorderQs,
          currentIndex: session.reorderIndex,
          totalSteps: _totalSteps,
          vocabItems: detail.vocabItems,
          onAnswer: (answer) => _handleReorderAnswer(
            context,
            ref,
            detail,
            answer,
          ),
        );
      case LessonStep.result:
        return _ResultStep(
          key: const ValueKey('step-5'),
          result: session.result!,
          detail: detail,
          onRetry: () => ref.read(lessonSessionProvider.notifier).reset(),
          onDone: () => context.pop(),
        );
    }
  }

  Future<void> _handleMatchingComplete(
    BuildContext context,
    WidgetRef ref,
    LessonDetailModel detail,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final level = ref.read(userPreferencesProvider).jlptLevel;
      await ref.read(lessonSessionProvider.notifier).completeMatching(
            detail: detail,
            jlptLevel: level,
          );
    } catch (e) {
      _showSubmitError(messenger, e);
    }
  }

  Future<void> _handleReorderAnswer(
    BuildContext context,
    WidgetRef ref,
    LessonDetailModel detail,
    Map<String, dynamic> answer,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final level = ref.read(userPreferencesProvider).jlptLevel;
      await ref.read(lessonSessionProvider.notifier).answerReorder(
            detail: detail,
            jlptLevel: level,
            answer: answer,
          );
    } catch (e) {
      _showSubmitError(messenger, e);
    }
  }

  Future<void> _submitLesson(
    BuildContext context,
    WidgetRef ref,
    LessonDetailModel detail,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final level = ref.read(userPreferencesProvider).jlptLevel;
      await ref.read(lessonSessionProvider.notifier).submitAnswers(
            lessonId: detail.id,
            jlptLevel: level,
          );
    } catch (e) {
      _showSubmitError(messenger, e);
    }
  }

  void _showSubmitError(ScaffoldMessengerState? messenger, Object error) {
    messenger?.showSnackBar(
      SnackBar(content: Text('제출 실패: $error')),
    );
  }

  void _showDialogueSheet(BuildContext context, LessonDetailModel detail) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(AppSizes.md),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSizes.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              '대화 다시 보기',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSizes.md),
            ...detail.content.reading.script.map(
              (line) => _DialogueBubble(line: line, showTranslation: true),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// _StepProgressBar — 6 segments
// ═══════════════════════════════════════════════════════════════════

class _StepProgressBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  const _StepProgressBar({required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (i) {
        final isCompleted = i < currentStep;
        final isCurrent = i == currentStep;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < totalSteps - 1 ? 3 : 0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: isCompleted || isCurrent
                    ? AppColors.primaryStrong
                    : AppColors.primary.withValues(alpha: 0.15),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Step 0: _ContextPreviewStep (Lesson Briefing)
// ═══════════════════════════════════════════════════════════════════

class _ContextPreviewStep extends StatelessWidget {
  final LessonDetailModel detail;
  final VoidCallback onNext;
  const _ContextPreviewStep({
    super.key,
    required this.detail,
    required this.onNext,
  });

  /// Deduplicated vocab list (by word+reading)
  List<VocabItemModel> get _uniqueVocab {
    final seen = <String>{};
    return detail.vocabItems.where((v) {
      final key = '${v.word}_${v.reading}';
      return seen.add(key);
    }).toList();
  }

  /// Select first 3 unique vocab items for preview
  List<VocabItemModel> _previewVocab() {
    return _uniqueVocab.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reading = detail.content.reading;
    final learningGoal = getLearningGoal(detail.topic);
    final previewVocab = _previewVocab();
    final remainingCount = _uniqueVocab.length - previewVocab.length;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.lg,
              vertical: AppSizes.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Meta bar: lesson number + time
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryStrong,
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusFull),
                      ),
                      child: Text(
                        '레슨 ${detail.lessonNo}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.onGradient,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      LucideIcons.clock,
                      size: 14,
                      color: AppColors.lightSubtext,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${detail.estimatedMinutes}분',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.lightSubtext,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSizes.md),

                // Title
                Text(
                  detail.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.lightText,
                  ),
                ),

                const SizedBox(height: AppSizes.lg),

                // Learning goal
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSizes.md),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.12),
                        AppColors.primary.withValues(alpha: 0.04),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.target,
                            size: 16,
                            color: AppColors.primaryStrong,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '이번 레슨을 끝내면',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.primaryStrong,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        learningGoal,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.lightText,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                // Scene (compact)
                if (reading.scene != null) ...[
                  const SizedBox(height: AppSizes.md),
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.mapPin,
                        size: 14,
                        color: AppColors.lightSubtext,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          reading.scene!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.lightSubtext,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),

                // Vocab preview
                if (previewVocab.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.bookOpen,
                        size: 16,
                        color: AppColors.primaryStrong,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '배울 단어',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.gap),
                  Wrap(
                    spacing: AppSizes.sm,
                    runSpacing: AppSizes.sm,
                    children: [
                      ...previewVocab.map((v) => _VocabPreviewChip(vocab: v)),
                      if (remainingCount > 0)
                        Text(
                          '+$remainingCount개',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.lightSubtext,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ],

                const SizedBox(height: 20),

                // Grammar preview
                if (detail.grammarItems.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.braces,
                        size: 16,
                        color: AppColors.primaryStrong,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '배울 문법',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.sm),
                  Text(
                    '${detail.grammarItems.first.pattern} — ${detail.grammarItems.first.meaningKo}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.lightText,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: SizedBox(
              width: double.infinity,
              height: AppSizes.buttonHeight,
              child: FilledButton.icon(
                onPressed: onNext,
                icon: const Icon(LucideIcons.sparkles),
                label: const Text('학습 시작하기'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Step 1: _GuidedReadingStep
// ═══════════════════════════════════════════════════════════════════

class _GuidedReadingStep extends StatefulWidget {
  final LessonDetailModel detail;
  final VoidCallback onNext;
  const _GuidedReadingStep({
    super.key,
    required this.detail,
    required this.onNext,
  });

  @override
  State<_GuidedReadingStep> createState() => _GuidedReadingStepState();
}

class _GuidedReadingStepState extends State<_GuidedReadingStep> {
  bool _showTranslation = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reading = widget.detail.content.reading;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSizes.md),
            children: [
              // Scene bar
              if (reading.scene != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSizes.gap),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.mapPin,
                        size: AppSizes.iconSm,
                        color: AppColors.primaryStrong,
                      ),
                      const SizedBox(width: AppSizes.sm),
                      Expanded(
                        child: Text(
                          reading.scene!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.lightText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.md),
              ],

              // Translation toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '번역',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.lightText,
                    ),
                  ),
                  const SizedBox(width: AppSizes.xs),
                  SizedBox(
                    height: 28,
                    child: Switch.adaptive(
                      value: _showTranslation,
                      onChanged: (v) => setState(() => _showTranslation = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.sm),

              // Dialogue bubbles
              ...reading.script.map(
                (line) => _DialogueBubble(
                  line: line,
                  showTranslation: _showTranslation,
                ),
              ),

              const SizedBox(height: AppSizes.lg),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: SizedBox(
              width: double.infinity,
              height: AppSizes.buttonHeight,
              child: FilledButton.icon(
                onPressed: widget.onNext,
                icon: const Icon(LucideIcons.checkCircle),
                label: const Text('이해 체크로'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Dialogue Bubble (shared) ──

class _DialogueBubble extends StatelessWidget {
  final ScriptLineModel line;
  final bool showTranslation;
  const _DialogueBubble({
    required this.line,
    this.showTranslation = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            line.speaker,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.primaryStrong,
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          Container(
            padding: const EdgeInsets.all(AppSizes.gap),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.text,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                    color: AppColors.lightText,
                  ),
                ),
                if (showTranslation && line.translation != null) ...[
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    line.translation!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Step 2: _RecognitionCheckStep
// ═══════════════════════════════════════════════════════════════════

class _RecognitionCheckStep extends StatefulWidget {
  final List<LessonQuestionModel> questions;
  final int currentIndex;
  final int totalSteps;
  final ValueChanged<Map<String, dynamic>> onAnswer;
  const _RecognitionCheckStep({
    super.key,
    required this.questions,
    required this.currentIndex,
    required this.totalSteps,
    required this.onAnswer,
  });

  @override
  State<_RecognitionCheckStep> createState() => _RecognitionCheckStepState();
}

class _RecognitionCheckStepState extends State<_RecognitionCheckStep> {
  String? _selected;
  late List<QuizOptionModel> _shuffledOptions;

  @override
  void initState() {
    super.initState();
    _shuffleOptions();
  }

  @override
  void didUpdateWidget(covariant _RecognitionCheckStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _selected = null;
      _shuffleOptions();
    }
  }

  void _shuffleOptions() {
    final q = widget.questions[widget.currentIndex];
    _shuffledOptions = List.of(q.options ?? [])..shuffle(Random());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = widget.questions[widget.currentIndex];

    return Padding(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sub-progress
          Text(
            '3/${widget.totalSteps} · 문항 ${widget.currentIndex + 1}/${widget.questions.length}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: AppSizes.md),

          Text(
            q.prompt,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSizes.lg),

          ..._shuffledOptions.map((opt) => Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.sm),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _selected != null ? null : () => _select(opt.id),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(AppSizes.md),
                      side: BorderSide(
                        color: _selected == opt.id
                            ? AppColors.primaryStrong
                            : AppColors.lightBorder,
                      ),
                      backgroundColor: _selected == opt.id
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : null,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(opt.text, style: theme.textTheme.bodyLarge),
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  void _select(String id) {
    setState(() => _selected = id);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      widget.onAnswer({
        'order': widget.questions[widget.currentIndex].order,
        'selectedAnswer': _selected,
        'responseMs': 0,
      });
    });
  }
}

// ═══════════════════════════════════════════════════════════════════
// Step 3: _MatchingGameStep
// ═══════════════════════════════════════════════════════════════════

class _MatchingGameStep extends StatefulWidget {
  final List<VocabItemModel> vocabItems;
  final VoidCallback onComplete;
  const _MatchingGameStep({
    super.key,
    required this.vocabItems,
    required this.onComplete,
  });

  @override
  State<_MatchingGameStep> createState() => _MatchingGameStepState();
}

class _MatchingGameStepState extends State<_MatchingGameStep>
    with SingleTickerProviderStateMixin {
  late List<VocabItemModel> _pairs;
  late List<int> _shuffledRightIndices;
  int? _selectedLeft;
  int? _selectedRight;
  final Set<int> _matched = {};
  bool _wrongFlash = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _initPairs();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    // Skip matching step if not enough unique pairs
    if (_pairs.length < 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onComplete();
      });
    }
  }

  void _initPairs() {
    // Deduplicate by meaningKo so matching is unambiguous
    // Skip entries with empty meaningKo, normalize with trim
    final seen = <String>{};
    final unique = <VocabItemModel>[];
    for (final v in widget.vocabItems) {
      final key = v.meaningKo.trim();
      if (key.isNotEmpty && seen.add(key)) unique.add(v);
    }
    unique.shuffle(Random());
    _pairs = unique.take(min(4, unique.length)).toList();
    _shuffledRightIndices = List.generate(_pairs.length, (i) => i)
      ..shuffle(Random());
    _selectedLeft = null;
    _selectedRight = null;
    _matched.clear();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onTapLeft(int index) {
    if (_matched.contains(index)) return;
    setState(() {
      _selectedLeft = index;
      _wrongFlash = false;
    });
    _checkMatch();
  }

  void _onTapRight(int index) {
    if (_matched.contains(index)) return;
    setState(() {
      _selectedRight = index;
      _wrongFlash = false;
    });
    _checkMatch();
  }

  void _checkMatch() {
    if (_selectedLeft == null || _selectedRight == null) return;

    if (_selectedLeft == _selectedRight) {
      // Correct match
      setState(() {
        _matched.add(_selectedLeft!);
        _selectedLeft = null;
        _selectedRight = null;
      });
      if (_matched.length == _pairs.length) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) widget.onComplete();
        });
      }
    } else {
      // Wrong match
      setState(() => _wrongFlash = true);
      _shakeController.forward(from: 0).then((_) {
        if (mounted) {
          setState(() {
            _selectedLeft = null;
            _selectedRight = null;
            _wrongFlash = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    return Padding(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '단어 매칭',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            '일본어와 뜻을 연결하세요',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          Expanded(
            child: AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                final shakeOffset =
                    _wrongFlash ? sin(_shakeAnimation.value * pi * 4) * 6 : 0.0;
                return Transform.translate(
                  offset: Offset(shakeOffset, 0),
                  child: child,
                );
              },
              child: Column(
                children: List.generate(_pairs.length, (i) {
                  final rightIndex = _shuffledRightIndices[i];
                  final leftMatched = _matched.contains(i);
                  final rightMatched = _matched.contains(rightIndex);
                  final leftSelected = _selectedLeft == i && !leftMatched;
                  final rightSelected =
                      _selectedRight == rightIndex && !rightMatched;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSizes.sm),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left: Japanese
                          Expanded(
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 300),
                              opacity: leftMatched ? 0.3 : 1.0,
                              child: _MatchCard(
                                onTap: leftMatched ? null : () => _onTapLeft(i),
                                isSelected: leftSelected,
                                isMatched: leftMatched,
                                isWrong: _wrongFlash && leftSelected,
                                brightness: brightness,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _pairs[i].word,
                                      style:
                                          theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (_pairs[i].reading !=
                                        _pairs[i].word) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        _pairs[i].reading,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: theme.colorScheme.outline,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSizes.gap),
                          // Right: Korean
                          Expanded(
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 300),
                              opacity: rightMatched ? 0.3 : 1.0,
                              child: _MatchCard(
                                onTap: rightMatched
                                    ? null
                                    : () => _onTapRight(rightIndex),
                                isSelected: rightSelected,
                                isMatched: rightMatched,
                                isWrong: _wrongFlash && rightSelected,
                                brightness: brightness,
                                child: Text(
                                  _pairs[rightIndex].meaningKo,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isSelected;
  final bool isMatched;
  final bool isWrong;
  final Brightness brightness;
  final Widget child;

  const _MatchCard({
    required this.onTap,
    required this.isSelected,
    required this.isMatched,
    required this.isWrong,
    required this.brightness,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color borderColor;

    if (isMatched) {
      bgColor = AppColors.success(brightness).withValues(alpha: 0.15);
      borderColor = AppColors.success(brightness);
    } else if (isWrong) {
      bgColor = AppColors.error(brightness).withValues(alpha: 0.15);
      borderColor = AppColors.error(brightness);
    } else if (isSelected) {
      bgColor = AppColors.primary.withValues(alpha: 0.15);
      borderColor = AppColors.primaryStrong;
    } else {
      bgColor = AppColors.lightCard;
      borderColor = AppColors.lightBorder;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.gap,
          vertical: AppSizes.md,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Center(child: child),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Step 4: _SentenceReorderStep
// ═══════════════════════════════════════════════════════════════════

class _SentenceReorderStep extends StatefulWidget {
  final List<LessonQuestionModel> questions;
  final int currentIndex;
  final int totalSteps;
  final List<VocabItemModel> vocabItems;
  final ValueChanged<Map<String, dynamic>> onAnswer;
  const _SentenceReorderStep({
    super.key,
    required this.questions,
    required this.currentIndex,
    required this.totalSteps,
    required this.vocabItems,
    required this.onAnswer,
  });

  @override
  State<_SentenceReorderStep> createState() => _SentenceReorderStepState();
}

class _SentenceReorderStepState extends State<_SentenceReorderStep> {
  late List<String> _available;
  final List<String> _selected = [];
  late int _correctTokenCount;
  bool _submitting = false;

  // Track which tokens were just added/removed for animation
  String? _lastAddedToken;
  String? _lastRemovedToken;

  // Drag-and-drop: index being hovered over (-1 = none)
  int _dragHoverIndex = -1;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(covariant _SentenceReorderStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _reset();
    }
  }

  void _reset() {
    final q = widget.questions[widget.currentIndex];
    final correctTokens = q.tokens ?? [];
    _correctTokenCount = correctTokens.length;

    // Generate distractors from vocabItems
    final correctSet = correctTokens.toSet();
    final distractors = widget.vocabItems
        .map((v) => v.word)
        .where((w) => w.trim().isNotEmpty && !correctSet.contains(w))
        .toSet()
        .toList()
      ..shuffle(Random());
    final picked = distractors.take(min(3, distractors.length)).toList();

    _available = [...correctTokens, ...picked]..shuffle(Random());
    _selected.clear();
    _submitting = false;
    _lastAddedToken = null;
    _lastRemovedToken = null;
    _dragHoverIndex = -1;
  }

  bool get _isFull => _selected.length >= _correctTokenCount;

  void _selectToken(String token) {
    if (_isFull || _submitting) return;
    setState(() {
      _available.remove(token);
      _selected.add(token);
      _lastAddedToken = token;
      _lastRemovedToken = null;
    });
  }

  void _deselectToken(int index) {
    if (_submitting) return;
    setState(() {
      final token = _selected.removeAt(index);
      _available.add(token);
      _lastRemovedToken = token;
      _lastAddedToken = null;
    });
  }

  void _onReorder(int fromIndex, int toIndex) {
    if (_submitting || fromIndex == toIndex) return;
    // Bounds check to prevent RangeError from stale drag data
    if (fromIndex < 0 ||
        fromIndex >= _selected.length ||
        toIndex < 0 ||
        toIndex >= _selected.length) {
      return;
    }
    setState(() {
      final item = _selected.removeAt(fromIndex);
      _selected.insert(toIndex, item);
      _dragHoverIndex = -1;
    });
  }

  void _submit() {
    if (!_isFull || _submitting) return;
    final q = widget.questions[widget.currentIndex];
    setState(() => _submitting = true);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      // Reset submitting so widget is not permanently locked on failure
      setState(() => _submitting = false);
      widget.onAnswer({
        'order': q.order,
        'submittedOrder': List<String>.from(_selected),
        'responseMs': 0,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = widget.questions[widget.currentIndex];

    return Padding(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sub-progress
          Text(
            '5/${widget.totalSteps} · 문항 ${widget.currentIndex + 1}/${widget.questions.length}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.lightSubtext,
            ),
          ),
          const SizedBox(height: AppSizes.md),

          // Prompt
          Text(
            q.prompt,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.lightText,
            ),
          ),

          // Korean hint (explanation as subtitle)
          if (q.explanation != null) ...[
            const SizedBox(height: AppSizes.xs),
            Text(
              q.explanation!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.lightSubtext,
                fontSize: 13,
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Answer area label + counter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '정답 영역',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.lightSubtext,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '선택 ${_selected.length}/$_correctTokenCount',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: _isFull
                      ? AppColors.primaryStrong
                      : AppColors.lightSubtext,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),

          // Answer area card
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 70),
            padding: const EdgeInsets.all(AppSizes.gap),
            decoration: BoxDecoration(
              color: AppColors.lightCard,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              border: Border.all(color: AppColors.lightBorder),
            ),
            child: _buildAnswerArea(theme),
          ),

          const SizedBox(height: 20),

          // Bank area
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _available.asMap().entries.map((entry) {
              final token = entry.value;
              final isJustReturned = _lastRemovedToken == token;
              final disabled = _isFull || _submitting;
              return TweenAnimationBuilder<double>(
                key: ValueKey('bank-$token-${entry.key}'),
                tween: Tween(
                  begin: isJustReturned ? 0.8 : 1.0,
                  end: 1.0,
                ),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                builder: (context, scale, child) => Transform.scale(
                  scale: scale,
                  child: child,
                ),
                child: _BankToken(
                  text: token,
                  disabled: disabled,
                  onTap: disabled ? null : () => _selectToken(token),
                ),
              );
            }).toList(),
          ),

          if (_available.isNotEmpty && _selected.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSizes.gap),
              child: Center(
                child: Text(
                  '토큰을 탭해서 문장을 만드세요',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.lightSubtext,
                  ),
                ),
              ),
            ),

          const Spacer(),

          // Confirm button
          SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (_isFull && !_submitting) ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryStrong,
                  disabledBackgroundColor:
                      AppColors.lightBorder.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  elevation: 0,
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        '확인',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _isFull
                              ? AppColors.onGradient
                              : AppColors.lightSubtext,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerArea(ThemeData theme) {
    final remaining = _correctTokenCount - _selected.length;

    final List<Widget> children = [];

    for (int i = 0; i < _selected.length; i++) {
      final token = _selected[i];
      final isJustAdded = _lastAddedToken == token;
      final isHovered = _dragHoverIndex == i;

      children.add(
        DragTarget<int>(
          key: ValueKey('answer-target-$i'),
          onWillAcceptWithDetails: (details) {
            if (details.data != i) {
              setState(() => _dragHoverIndex = i);
            }
            return details.data != i;
          },
          onLeave: (_) {
            if (_dragHoverIndex == i) {
              setState(() => _dragHoverIndex = -1);
            }
          },
          onAcceptWithDetails: (details) {
            _onReorder(details.data, i);
          },
          builder: (context, candidateData, rejectedData) {
            return LongPressDraggable<int>(
              data: i,
              delay: const Duration(milliseconds: 200),
              feedback: Material(
                color: Colors.transparent,
                child: _AnswerToken(
                  text: token,
                  index: i,
                  isDragging: true,
                  isHovered: false,
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.3,
                child: _AnswerToken(
                  text: token,
                  index: i,
                  isDragging: false,
                  isHovered: false,
                ),
              ),
              child: TweenAnimationBuilder<double>(
                tween: Tween(
                  begin: isJustAdded ? 0.8 : 1.0,
                  end: 1.0,
                ),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: GestureDetector(
                  onTap: _submitting ? null : () => _deselectToken(i),
                  child: _AnswerToken(
                    text: token,
                    index: i,
                    isDragging: false,
                    isHovered: isHovered,
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    // Empty slot placeholders
    for (int i = 0; i < remaining; i++) {
      children.add(
        Container(
          key: ValueKey('empty-slot-${_selected.length + i}'),
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.lightBorder),
          ),
          child: Text(
            '　',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.lightSubtext.withValues(alpha: 0.3),
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: children,
    );
  }
}

/// Answer area token with drag-and-drop support
class _AnswerToken extends StatelessWidget {
  final String text;
  final int index;
  final bool isDragging;
  final bool isHovered;

  const _AnswerToken({
    required this.text,
    required this.index,
    required this.isDragging,
    required this.isHovered,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: isHovered
                ? AppColors.primaryStrong.withValues(alpha: 0.22)
                : AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primaryStrong,
              width: isHovered ? 2.0 : 1.5,
            ),
            boxShadow: isDragging
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            text,
            style: TextStyle(
              color: AppColors.lightText,
              fontSize: isDragging ? 17 : 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // Index badge
        Positioned(
          top: -6,
          left: -6,
          child: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: AppColors.primaryStrong,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: AppColors.onGradient,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Bank token widget
class _BankToken extends StatelessWidget {
  final String text;
  final bool disabled;
  final VoidCallback? onTap;

  const _BankToken({
    required this.text,
    required this.disabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: disabled ? 0.4 : 1.0,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.lightCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.lightBorder,
            ),
            boxShadow: disabled
                ? null
                : [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.lightText,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Step 5: _ResultStep
// ═══════════════════════════════════════════════════════════════════

class _ResultStep extends StatelessWidget {
  final LessonSubmitResultModel result;
  final LessonDetailModel detail;
  final VoidCallback onRetry;
  final VoidCallback onDone;
  const _ResultStep({
    super.key,
    required this.result,
    required this.detail,
    required this.onRetry,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final score = result.scoreTotal > 0
        ? (result.scoreCorrect / result.scoreTotal * 100).round()
        : 0;
    final isPerfect = result.scoreCorrect == result.scoreTotal;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSizes.md),
            children: [
              const SizedBox(height: AppSizes.lg),
              Center(
                child: Icon(
                  isPerfect ? LucideIcons.trophy : LucideIcons.clipboardCheck,
                  size: 48,
                  color: isPerfect
                      ? AppColors.success(brightness)
                      : AppColors.primaryStrong,
                ),
              ),
              const SizedBox(height: AppSizes.md),
              Center(
                child: Text(
                  '$score%',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Center(
                child: Text(
                  '${result.scoreCorrect}/${result.scoreTotal} 정답',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.md),

              // SRS registration card
              if (result.srsItemsRegistered > 0)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSizes.md),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.md,
                    vertical: AppSizes.gap,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success(brightness).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    border: Border.all(
                      color:
                          AppColors.success(brightness).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.checkCircle2,
                        color: AppColors.success(brightness),
                        size: AppSizes.iconMd,
                      ),
                      const SizedBox(width: AppSizes.sm),
                      Expanded(
                        child: Text(
                          '${result.srsItemsRegistered}개 항목이 복습 예약되었습니다',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: AppSizes.sm),

              // Per-question results
              ...result.results.map((r) {
                final q = detail.content.questions.firstWhere(
                  (q) => q.order == r.order,
                  orElse: () => detail.content.questions.first,
                );
                return Card(
                  margin: const EdgeInsets.only(bottom: AppSizes.sm),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.gap),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              r.isCorrect
                                  ? LucideIcons.checkCircle2
                                  : LucideIcons.xCircle,
                              color: r.isCorrect
                                  ? AppColors.success(brightness)
                                  : AppColors.error(brightness),
                              size: AppSizes.iconMd,
                            ),
                            const SizedBox(width: AppSizes.sm),
                            Expanded(
                              child: Text(
                                q.prompt,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                        if (r.explanation != null) ...[
                          const SizedBox(height: AppSizes.xs),
                          Padding(
                            padding: const EdgeInsets.only(left: 28),
                            child: Text(
                              r.explanation!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ),
                        ],
                        // SRS state transition
                        if (r.stateBefore != null && r.stateAfter != null) ...[
                          const SizedBox(height: AppSizes.sm),
                          Padding(
                            padding: const EdgeInsets.only(left: 28),
                            child: Row(
                              children: [
                                Icon(
                                  _srsTransitionIcon(
                                      r.stateBefore!, r.stateAfter!),
                                  size: 14,
                                  color: _srsTransitionColor(
                                    brightness,
                                    r.stateBefore!,
                                    r.stateAfter!,
                                  ),
                                ),
                                const SizedBox(width: AppSizes.xs),
                                Text(
                                  '${r.stateBefore} → ${r.stateAfter}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: _srsTransitionColor(
                                      brightness,
                                      r.stateBefore!,
                                      r.stateAfter!,
                                    ),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (r.isProvisionalPhase) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning(brightness)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'SRS 등록됨',
                                      style:
                                          theme.textTheme.labelSmall?.copyWith(
                                        color: AppColors.warning(brightness),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        // Next review date
                        if (r.nextReviewAt != null) ...[
                          const SizedBox(height: AppSizes.xs),
                          Padding(
                            padding: const EdgeInsets.only(left: 28),
                            child: Text(
                              '다음 복습: ${_formatReviewDate(r.nextReviewAt!)}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: onDone,
                    icon: const Icon(LucideIcons.bookOpen, size: 18),
                    label: const Text('학습으로 돌아가기'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryStrong,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: onRetry,
                        child: const Text('다시 풀기'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  IconData _srsTransitionIcon(String before, String after) {
    if (before == 'UNSEEN') return LucideIcons.sparkles;
    if (after == 'REVIEW' || after == 'MASTERED') return LucideIcons.trendingUp;
    if (after == 'RELEARNING') return LucideIcons.refreshCw;
    return LucideIcons.arrowLeftRight;
  }

  Color _srsTransitionColor(
      Brightness brightness, String before, String after) {
    if (after == 'MASTERED') return AppColors.success(brightness);
    if (after == 'REVIEW') return AppColors.info(brightness);
    if (after == 'LEARNING') return AppColors.warning(brightness);
    if (after == 'RELEARNING') return AppColors.error(brightness);
    if (after == 'PROVISIONAL') return AppColors.warning(brightness);
    return AppColors.lightSubtext;
  }

  String _formatReviewDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final now = DateTime.now();
      final diff = date.difference(now);
      if (diff.inMinutes < 60) return '${diff.inMinutes}분 후';
      if (diff.inHours < 24) return '${diff.inHours}시간 후';
      if (diff.inDays < 7) return '${diff.inDays}일 후';
      return '${date.month}/${date.day}';
    } catch (_) {
      return isoDate;
    }
  }
}

/// Compact vocab preview chip for Step 0
class _VocabPreviewChip extends StatelessWidget {
  final VocabItemModel vocab;
  const _VocabPreviewChip({required this.vocab});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showReading = vocab.word != vocab.reading;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.lightCard,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            vocab.word,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.lightText,
            ),
          ),
          if (showReading)
            Text(
              vocab.reading,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.lightSubtext,
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }
}
