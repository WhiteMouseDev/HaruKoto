import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/services/tts_service.dart';
import '../../../../core/theme/text_theme.dart';
import '../../data/models/lesson_models.dart';
import 'lesson_dialogue_bubble.dart';
import 'lesson_dialogue_audio_control.dart';
import 'lesson_stage_actions.dart';

class LessonGuidedReadingStep extends StatefulWidget {
  final LessonDetailModel detail;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final TtsService? ttsService;

  const LessonGuidedReadingStep({
    super.key,
    required this.detail,
    required this.onPrevious,
    required this.onNext,
    this.ttsService,
  });

  @override
  State<LessonGuidedReadingStep> createState() =>
      _LessonGuidedReadingStepState();
}

class _LessonGuidedReadingStepState extends State<LessonGuidedReadingStep>
    with SingleTickerProviderStateMixin {
  bool _showTranslation = false;
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
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final start = (index * 0.08).clamp(0.0, 0.7);
    final end = (start + 0.4).clamp(0.0, 1.0);
    final curve = Interval(start, end, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: _staggerController,
      builder: (context, child) {
        final progress = curve.transform(_staggerController.value);
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - progress)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final light = theme.brightness == Brightness.light;
    final reading = widget.detail.content.reading;
    final foreground = light ? AppColors.redesignForeground : colors.onSurface;
    final scene = reading.scene?.trim();
    final lines = reading.script.asMap().entries.where(
          (entry) => entry.value.text.trim().isNotEmpty,
        );
    final hasTranslation = lines.any(
      (entry) => entry.value.translation?.trim().isNotEmpty ?? false,
    );
    final speakerSides = <String, bool>{};

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.pageHorizontal,
              AppSizes.lg,
              AppSizes.pageHorizontal,
              AppSizes.lg,
            ),
            children: [
              if (scene != null && scene.isNotEmpty) ...[
                Container(
                  alignment: Alignment.center,
                  constraints:
                      const BoxConstraints(minHeight: AppSizes.buttonHeight),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.md,
                    vertical: AppSizes.sm,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLowest,
                    border: Border.all(
                      color: light
                          ? AppColors.redesignOutline
                          : colors.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    scene,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: redesignFontFamily,
                      color: foreground,
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.lg),
              ],
              if (lines.isNotEmpty || reading.audioUrl != null)
                Row(
                  children: [
                    Expanded(
                      child: LessonDialogueAudioControl(
                        lessonId: widget.detail.id,
                        reading: reading,
                        ttsService: widget.ttsService,
                        compact: true,
                      ),
                    ),
                    if (hasTranslation)
                      MergeSemantics(
                        child: Row(
                          children: [
                            Text(
                              '번역',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontFamily: redesignFontFamily,
                                color: foreground,
                              ),
                            ),
                            const SizedBox(width: AppSizes.xs),
                            Switch.adaptive(
                              value: _showTranslation,
                              activeTrackColor: light
                                  ? AppColors.redesignVocabulary
                                  : colors.primary,
                              onChanged: (value) =>
                                  setState(() => _showTranslation = value),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              for (final entry in lines)
                _staggered(
                  entry.key,
                  LessonDialogueBubble(
                    key: ValueKey(entry.key),
                    line: entry.value,
                    ttsService: widget.ttsService,
                    lessonId: widget.detail.id,
                    scriptLineIndex: entry.key,
                    showTranslation: _showTranslation,
                    isRightAligned: speakerSides.putIfAbsent(
                      entry.value.speaker.trim(),
                      () => speakerSides.length.isOdd,
                    ),
                    audioBelow: true,
                    highlights: reading.highlights,
                  ),
                ),
            ],
          ),
        ),
        LessonStageActions(
          nextLabel: '다음학습',
          onPrevious: widget.onPrevious,
          onNext: widget.onNext,
          showPrevious: true,
        ),
      ],
    );
  }
}
