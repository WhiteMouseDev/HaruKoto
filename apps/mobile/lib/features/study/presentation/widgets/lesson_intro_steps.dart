import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../shared/widgets/tts_play_button.dart';
import '../../data/learning_goals.dart';
import '../../data/models/lesson_models.dart';

class LessonStepProgressBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const LessonStepProgressBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (index) {
        final isCompleted = index < currentStep;
        final isCurrent = index == currentStep;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index < totalSteps - 1 ? 3 : 0),
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

void showLessonDialogueSheet(BuildContext context, LessonDetailModel detail) {
  final theme = Theme.of(context);
  showModalBottomSheet<void>(
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
            (line) => LessonDialogueBubble(
              line: line,
              showTranslation: true,
            ),
          ),
        ],
      ),
    ),
  );
}

class LessonContextPreviewStep extends StatefulWidget {
  final LessonDetailModel detail;
  final VoidCallback onNext;

  const LessonContextPreviewStep({
    super.key,
    required this.detail,
    required this.onNext,
  });

  @override
  State<LessonContextPreviewStep> createState() =>
      _LessonContextPreviewStepState();
}

class _LessonContextPreviewStepState extends State<LessonContextPreviewStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _staggerController.forward();
    });
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  Widget _staggered(int index, Widget child) {
    final start = (index * 0.12).clamp(0.0, 0.7);
    final end = (start + 0.4).clamp(0.0, 1.0);
    final animation = CurvedAnimation(
      parent: _staggerController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - animation.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }

  List<VocabItemModel> get _uniqueVocab {
    final seen = <String>{};
    return widget.detail.vocabItems.where((vocab) {
      final key = '${vocab.word}_${vocab.reading}';
      return seen.add(key);
    }).toList();
  }

  List<VocabItemModel> _previewVocab() {
    return _uniqueVocab.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
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
                _staggered(
                  0,
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
                ),
                const SizedBox(height: AppSizes.md),
                _staggered(
                  1,
                  Text(
                    detail.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.lightText,
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.lg),
                _staggered(
                  2,
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
                ),
                if (reading.scene != null) ...[
                  const SizedBox(height: AppSizes.lg),
                  _staggered(
                    3,
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
                  ),
                ],
                const SizedBox(height: AppSizes.lg),
                if (previewVocab.isNotEmpty)
                  _staggered(
                    4,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                            ...previewVocab.map(
                              (vocab) => LessonVocabPreviewChip(vocab: vocab),
                            ),
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
                    ),
                  ),
                if (previewVocab.isNotEmpty && detail.grammarItems.isNotEmpty)
                  Divider(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    height: AppSizes.xl,
                  ),
                if (detail.grammarItems.isNotEmpty)
                  _staggered(
                    5,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                        const SizedBox(height: AppSizes.gap),
                        ...detail.grammarItems.take(3).map(
                              (grammar) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSizes.sm,
                                ),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(AppSizes.gap),
                                  decoration: BoxDecoration(
                                    color: AppColors.lightCard,
                                    borderRadius: BorderRadius.circular(
                                      AppSizes.radiusSm,
                                    ),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.15,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        grammar.pattern,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryStrong,
                                        ),
                                      ),
                                      const SizedBox(width: AppSizes.sm),
                                      Text(
                                        '—',
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: AppColors.lightSubtext,
                                        ),
                                      ),
                                      const SizedBox(width: AppSizes.sm),
                                      Expanded(
                                        child: Text(
                                          grammar.meaningKo,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: AppColors.lightText,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        if (detail.grammarItems.length > 3)
                          Text(
                            '+${detail.grammarItems.length - 3}개',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.lightSubtext,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
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
                onPressed: widget.onNext,
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

class LessonGuidedReadingStep extends StatefulWidget {
  final LessonDetailModel detail;
  final VoidCallback onNext;

  const LessonGuidedReadingStep({
    super.key,
    required this.detail,
    required this.onNext,
  });

  @override
  State<LessonGuidedReadingStep> createState() =>
      _LessonGuidedReadingStepState();
}

class _LessonGuidedReadingStepState extends State<LessonGuidedReadingStep>
    with SingleTickerProviderStateMixin {
  bool _showTranslation = false;
  late final AnimationController _staggerController;
  late final Map<String, int> _speakerIndex;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _buildSpeakerMap();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _staggerController.forward();
    });
  }

  void _buildSpeakerMap() {
    _speakerIndex = {};
    var index = 0;
    for (final line in widget.detail.content.reading.script) {
      _speakerIndex.putIfAbsent(line.speaker, () => index++);
    }
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  Widget _staggered(int index, Widget child) {
    final start = (index * 0.08).clamp(0.0, 0.7);
    final end = (start + 0.4).clamp(0.0, 1.0);
    final animation = CurvedAnimation(
      parent: _staggerController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - animation.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }

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
                const SizedBox(height: AppSizes.sm),
              ],
              if (reading.audioUrl != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.gap,
                    vertical: AppSizes.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.headphones,
                        size: 16,
                        color: AppColors.primaryStrong,
                      ),
                      const SizedBox(width: AppSizes.sm),
                      Text(
                        '전체 듣기',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.primaryStrong,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TtsPlayButton(
                        url: reading.audioUrl,
                        iconSize: 18,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.sm),
              ],
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
                      onChanged: (value) =>
                          setState(() => _showTranslation = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.sm),
              ...reading.script.asMap().entries.map(
                    (entry) => _staggered(
                      entry.key,
                      LessonDialogueBubble(
                        line: entry.value,
                        showTranslation: _showTranslation,
                        isRightAligned:
                            (_speakerIndex[entry.value.speaker] ?? 0) == 1,
                        highlights: reading.highlights,
                      ),
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

class LessonDialogueBubble extends StatelessWidget {
  final ScriptLineModel line;
  final bool showTranslation;
  final bool isRightAligned;
  final List<String> highlights;

  const LessonDialogueBubble({
    super.key,
    required this.line,
    this.showTranslation = true,
    this.isRightAligned = false,
    this.highlights = const [],
  });

  List<TextSpan> _buildHighlightedSpans(String text, TextStyle baseStyle) {
    if (highlights.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    final pattern = highlights.map(RegExp.escape).join('|');
    final regex = RegExp(pattern);
    final spans = <TextSpan>[];
    var lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: baseStyle,
        ));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: baseStyle.copyWith(
          backgroundColor: AppColors.primary.withValues(alpha: 0.18),
          fontWeight: FontWeight.w700,
        ),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: baseStyle,
      ));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crossAxisAlignment =
        isRightAligned ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    final bubbleRadius = isRightAligned
        ? const BorderRadius.only(
            topLeft: Radius.circular(AppSizes.radiusMd),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(AppSizes.radiusMd),
            bottomRight: Radius.circular(AppSizes.radiusMd),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(AppSizes.radiusMd),
            bottomLeft: Radius.circular(AppSizes.radiusMd),
            bottomRight: Radius.circular(AppSizes.radiusMd),
          );

    final bubbleColor = isRightAligned
        ? AppColors.primary.withValues(alpha: 0.08)
        : theme.colorScheme.surfaceContainerLow;

    final bubbleBorder = isRightAligned
        ? null
        : Border.all(
            color: AppColors.primary.withValues(alpha: 0.12),
          );

    final baseTextStyle = theme.textTheme.bodyLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          height: 1.5,
          color: AppColors.lightText,
        ) ??
        const TextStyle();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.gap),
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          Text(
            line.speaker,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.primaryStrong,
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            child: Container(
              padding: const EdgeInsets.all(AppSizes.gap),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: bubbleRadius,
                border: bubbleBorder,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            children: _buildHighlightedSpans(
                              line.text,
                              baseTextStyle,
                            ),
                          ),
                        ),
                      ),
                      TtsPlayButton(text: line.text, iconSize: 16),
                    ],
                  ),
                  if (showTranslation && line.translation != null) ...[
                    const SizedBox(height: AppSizes.xs),
                    Text(
                      line.translation!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.55,
                        ),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LessonVocabPreviewChip extends StatelessWidget {
  final VocabItemModel vocab;

  const LessonVocabPreviewChip({
    super.key,
    required this.vocab,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showReading = vocab.word != vocab.reading;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.lightCard,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
          Text(
            vocab.meaningKo,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.primaryStrong,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
