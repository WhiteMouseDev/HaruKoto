import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../data/models/lesson_models.dart';

class LessonRecognitionCheckStep extends StatefulWidget {
  final List<LessonQuestionModel> questions;
  final int currentIndex;
  final int totalSteps;
  final ValueChanged<Map<String, dynamic>> onAnswer;

  const LessonRecognitionCheckStep({
    super.key,
    required this.questions,
    required this.currentIndex,
    required this.totalSteps,
    required this.onAnswer,
  });

  @override
  State<LessonRecognitionCheckStep> createState() =>
      _LessonRecognitionCheckStepState();
}

class _LessonRecognitionCheckStepState extends State<LessonRecognitionCheckStep>
    with SingleTickerProviderStateMixin {
  String? _selected;
  late List<QuizOptionModel> _shuffledOptions;
  late AnimationController _entryController;

  @override
  void initState() {
    super.initState();
    _shuffleOptions();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _entryController.forward();
    });
  }

  @override
  void didUpdateWidget(covariant LessonRecognitionCheckStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _selected = null;
      _shuffleOptions();
      _entryController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  void _shuffleOptions() {
    final question = widget.questions[widget.currentIndex];
    _shuffledOptions = List.of(question.options ?? [])..shuffle(Random());
  }

  Widget _staggered(int index, Widget child) {
    final start = (index * 0.1).clamp(0.0, 0.7);
    final end = (start + 0.4).clamp(0.0, 1.0);
    final animation = CurvedAnimation(
      parent: _entryController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - animation.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }

  Color _optionBgColor(QuizOptionModel option) {
    if (_selected == option.id) {
      return AppColors.sakuraTrack;
    }
    return AppColors.lightCard;
  }

  Color _optionBorderColor(QuizOptionModel option) {
    if (_selected == option.id) return AppColors.sakura;
    return AppColors.lightBorder;
  }

  void _select(String id) {
    setState(() => _selected = id);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      widget.onAnswer({
        'order': widget.questions[widget.currentIndex].order,
        'selectedAnswer': _selected,
        'responseMs': 0,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final question = widget.questions[widget.currentIndex];

    return Padding(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _staggered(
            0,
            Row(
              children: [
                Text(
                  '문항 ${widget.currentIndex + 1}/${widget.questions.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.lightSubtext,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '이해 체크',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.sakura,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.md),
          _staggered(
            1,
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSizes.md),
              decoration: BoxDecoration(
                color: AppColors.sakuraTrack,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                border: Border.all(
                  color: AppColors.sakura.withValues(alpha: 0.18),
                ),
              ),
              child: Text(
                question.prompt,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.lightText,
                  height: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          ..._shuffledOptions.asMap().entries.map((entry) {
            final option = entry.value;
            return _staggered(
              entry.key + 2,
              Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.sm),
                child: GestureDetector(
                  onTap: _selected != null ? null : () => _select(option.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSizes.md),
                    decoration: BoxDecoration(
                      color: _optionBgColor(option),
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                      border: Border.all(
                        color: _optionBorderColor(option),
                        width: _selected == option.id ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            option.text,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: AppColors.lightText,
                            ),
                          ),
                        ),
                        if (_selected == option.id) ...[
                          const SizedBox(width: AppSizes.sm),
                          const Icon(
                            LucideIcons.check,
                            size: 18,
                            color: AppColors.sakura,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          if (_selected != null && question.explanation != null) ...[
            const SizedBox(height: AppSizes.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSizes.gap),
              decoration: BoxDecoration(
                color: AppColors.sakuraTrack,
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    LucideIcons.lightbulb,
                    size: 16,
                    color: AppColors.sakura,
                  ),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(
                    child: Text(
                      question.explanation!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.lightText,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
