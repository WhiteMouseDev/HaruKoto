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
  final VoidCallback? onNext;
  final TtsService? ttsService;

  const LessonGuidedReadingStep({
    super.key,
    required this.detail,
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
    final light = theme.brightness == Brightness.light;
    final reading = widget.detail.content.reading;
    final foreground =
        light ? AppColors.redesignForeground : theme.colorScheme.onSurface;
    final scene = reading.scene;

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
              if (scene != null && scene.trim().isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.md,
                    vertical: AppSizes.gap,
                  ),
                  decoration: BoxDecoration(
                    color: light
                        ? AppColors.brandPink.withValues(alpha: 0.12)
                        : theme.colorScheme.surfaceContainerHigh,
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
              if (reading.script.isNotEmpty) ...[
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          '대화',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontFamily: redesignFontFamily,
                            fontWeight: FontWeight.w700,
                            color: foreground,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.gap,
                        vertical: AppSizes.xs,
                      ),
                      decoration: BoxDecoration(
                        color: light
                            ? AppColors.redesignControl
                            : theme.colorScheme.surfaceContainerHigh,
                        borderRadius:
                            BorderRadius.circular(AppSizes.chipRadius),
                      ),
                      child: Text(
                        '총 ${reading.script.length}개',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontFamily: redesignFontFamily,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.sm),
              ],
              LessonDialogueAudioControl(
                lessonId: widget.detail.id,
                reading: reading,
                ttsService: widget.ttsService,
              ),
              const SizedBox(height: AppSizes.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '번역',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: foreground,
                    ),
                  ),
                  const SizedBox(width: AppSizes.xs),
                  Switch.adaptive(
                    value: _showTranslation,
                    onChanged: (value) =>
                        setState(() => _showTranslation = value),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.sm),
              ...reading.script.asMap().entries.map(
                    (entry) => _staggered(
                      entry.key,
                      LessonDialogueBubble(
                        line: entry.value,
                        ttsService: widget.ttsService,
                        lessonId: widget.detail.id,
                        scriptLineIndex: entry.key,
                        showTranslation: _showTranslation,
                        fullWidth: true,
                        highlights: reading.highlights,
                      ),
                    ),
                  ),
              const SizedBox(height: AppSizes.lg),
            ],
          ),
        ),
        LessonStageActions(
          nextLabel: '이해 체크로',
          onNext: widget.onNext == null
              ? null
              : () {
                  (widget.ttsService ?? TtsService())
                      .stop(lessonId: widget.detail.id);
                  widget.onNext!();
                },
        ),
      ],
    );
  }
}
