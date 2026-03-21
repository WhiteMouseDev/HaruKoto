import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../data/models/lesson_models.dart';
import '../providers/study_provider.dart';

/// 레슨 학습 플로우: 6-Step (상황 프리뷰 → 가이드 리딩 → 이해 체크 → 매칭 게임 → 문장 재구성 → 결과)
class LessonPage extends ConsumerStatefulWidget {
  final String lessonId;
  const LessonPage({super.key, required this.lessonId});

  @override
  ConsumerState<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends ConsumerState<LessonPage> {
  // ── State ──
  int _step = 0; // 0~5

  int _recognitionIndex = 0;
  int _reorderIndex = 0;
  final Map<int, Map<String, dynamic>> _answers = {};

  LessonSubmitResultModel? _result;
  bool _submitting = false;

  static const _totalSteps = 6;

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(lessonDetailProvider(widget.lessonId));

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 0) {
          setState(() {
            if (_step == 5) {
              _step = 0;
            } else {
              _step = (_step - 1).clamp(0, 5);
            }
          });
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
                        currentStep: _step,
                        totalSteps: _totalSteps,
                      ),
                    ),
                    if (_step >= 2 && _step <= 4) ...[
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
                  child: _buildStep(detail),
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

  Widget _buildStep(LessonDetailModel detail) {
    switch (_step) {
      case 0:
        return _ContextPreviewStep(
          key: const ValueKey('step-0'),
          detail: detail,
          onNext: () => setState(() => _step = 1),
        );
      case 1:
        return _GuidedReadingStep(
          key: const ValueKey('step-1'),
          detail: detail,
          onNext: () => _startPractice(detail),
        );
      case 2:
        final recognitionQs = detail.content.questions
            .where((q) => q.type == 'VOCAB_MCQ' || q.type == 'CONTEXT_CLOZE')
            .toList();
        if (recognitionQs.isEmpty) {
          // Skip recognition if no matching questions
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _step = 3);
          });
          return const SizedBox.shrink(key: ValueKey('step-2-skip'));
        }
        return _RecognitionCheckStep(
          key: ValueKey('step-2-$_recognitionIndex'),
          questions: recognitionQs,
          currentIndex: _recognitionIndex,
          totalSteps: _totalSteps,
          onAnswer: (answer) => _handleRecognitionAnswer(
            recognitionQs,
            answer,
          ),
        );
      case 3:
        return _MatchingGameStep(
          key: const ValueKey('step-3'),
          vocabItems: detail.vocabItems,
          onComplete: () {
            setState(() {
              _step = 4;
            });
          },
        );
      case 4:
        final reorderQs = detail.content.questions
            .where((q) => q.type == 'SENTENCE_REORDER')
            .toList();
        if (reorderQs.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _submitAnswers(detail);
          });
          return const SizedBox.shrink(key: ValueKey('step-4-skip'));
        }
        return _SentenceReorderStep(
          key: ValueKey('step-4-$_reorderIndex'),
          questions: reorderQs,
          currentIndex: _reorderIndex,
          totalSteps: _totalSteps,
          onAnswer: (answer) => _handleReorderAnswer(
            detail,
            reorderQs,
            answer,
          ),
        );
      case 5:
        return _ResultStep(
          key: const ValueKey('step-5'),
          result: _result!,
          detail: detail,
          onRetry: _retry,
          onDone: () => context.pop(),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Actions ──

  Future<void> _startPractice(LessonDetailModel detail) async {
    try {
      await ref.read(studyRepositoryProvider).startLesson(detail.id);
    } catch (_) {
      // Already started — ignore
    }
    setState(() {
      _step = 2;
      _recognitionIndex = 0;
      _reorderIndex = 0;
      _answers.clear();
    });
  }

  void _handleRecognitionAnswer(
    List<LessonQuestionModel> recognitionQs,
    Map<String, dynamic> answer,
  ) {
    final order = answer['order'] as int;
    _answers[order] = answer;

    if (_recognitionIndex < recognitionQs.length - 1) {
      setState(() => _recognitionIndex++);
    } else {
      setState(() => _step = 3);
    }
  }

  void _handleReorderAnswer(
    LessonDetailModel detail,
    List<LessonQuestionModel> reorderQs,
    Map<String, dynamic> answer,
  ) {
    final order = answer['order'] as int;
    _answers[order] = answer;

    if (_reorderIndex < reorderQs.length - 1) {
      setState(() => _reorderIndex++);
    } else {
      _submitAnswers(detail);
    }
  }

  Future<void> _submitAnswers(LessonDetailModel detail) async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      final answersList = _answers.values.toList();
      final result = await ref
          .read(studyRepositoryProvider)
          .submitLesson(detail.id, answersList);
      setState(() {
        _result = result;
        _step = 5;
        _submitting = false;
      });
      ref.invalidate(chaptersProvider('N5'));
    } catch (e) {
      setState(() => _submitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('제출 실패: $e')),
        );
      }
    }
  }

  void _retry() {
    setState(() {
      _step = 0;
      _recognitionIndex = 0;
      _reorderIndex = 0;
      _answers.clear();
      _result = null;
    });
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
// Step 0: _ContextPreviewStep
// ═══════════════════════════════════════════════════════════════════

class _ContextPreviewStep extends StatelessWidget {
  final LessonDetailModel detail;
  final VoidCallback onNext;
  const _ContextPreviewStep({
    super.key,
    required this.detail,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reading = detail.content.reading;

    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Scene card
                  if (reading.scene != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSizes.lg),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary.withValues(alpha: 0.08),
                            AppColors.primary.withValues(alpha: 0.03),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            LucideIcons.mapPin,
                            size: AppSizes.iconXl,
                            color: AppColors.primaryStrong,
                          ),
                          const SizedBox(height: AppSizes.gap),
                          Text(
                            reading.scene!,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: AppSizes.lg),

                  // Highlights label
                  if (reading.highlights.isNotEmpty) ...[
                    Text(
                      '오늘의 핵심 표현',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: AppSizes.gap),
                    Wrap(
                      spacing: AppSizes.sm,
                      runSpacing: AppSizes.sm,
                      alignment: WrapAlignment.center,
                      children: reading.highlights.map((h) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusFull),
                          ),
                          child: Text(
                            h,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.onGradient,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
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
                icon: const Icon(LucideIcons.messageSquare),
                label: const Text('대화 시작하기'),
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
  }

  void _initPairs() {
    final all = List.of(widget.vocabItems)..shuffle(Random());
    _pairs = all.take(min(4, all.length)).toList();
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
  final ValueChanged<Map<String, dynamic>> onAnswer;
  const _SentenceReorderStep({
    super.key,
    required this.questions,
    required this.currentIndex,
    required this.totalSteps,
    required this.onAnswer,
  });

  @override
  State<_SentenceReorderStep> createState() => _SentenceReorderStepState();
}

class _SentenceReorderStepState extends State<_SentenceReorderStep> {
  late List<String> _available;
  final List<String> _selected = [];

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
    _available = List.of(q.tokens ?? [])..shuffle(Random());
    _selected.clear();
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

          // Selected tokens area
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.all(AppSizes.gap),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.lightBorder),
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: Wrap(
              spacing: AppSizes.sm,
              runSpacing: AppSizes.sm,
              children: _selected
                  .map((t) => ActionChip(
                        label: Text(t, style: const TextStyle(fontSize: 16)),
                        onPressed: () {
                          setState(() {
                            _selected.remove(t);
                            _available.add(t);
                          });
                        },
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: AppSizes.md),

          // Available tokens
          Wrap(
            spacing: AppSizes.sm,
            runSpacing: AppSizes.sm,
            children: _available
                .map((t) => ActionChip(
                      label: Text(t, style: const TextStyle(fontSize: 16)),
                      onPressed: () {
                        setState(() {
                          _available.remove(t);
                          _selected.add(t);
                        });
                        if (_available.isEmpty) {
                          Future.delayed(const Duration(milliseconds: 400), () {
                            if (!mounted) return;
                            widget.onAnswer({
                              'order': q.order,
                              'submittedOrder': List<String>.from(_selected),
                              'responseMs': 0,
                            });
                          });
                        }
                      },
                    ))
                .toList(),
          ),
        ],
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
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onRetry,
                    child: const Text('다시 풀기'),
                  ),
                ),
                const SizedBox(width: AppSizes.gap),
                Expanded(
                  child: FilledButton(
                    onPressed: onDone,
                    child: const Text('완료'),
                  ),
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
