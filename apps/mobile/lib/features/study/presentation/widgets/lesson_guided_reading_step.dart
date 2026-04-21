import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../shared/widgets/tts_play_button.dart';
import '../../data/models/lesson_models.dart';
import 'lesson_dialogue_bubble.dart';

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
