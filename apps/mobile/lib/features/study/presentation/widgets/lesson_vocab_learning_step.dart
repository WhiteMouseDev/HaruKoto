import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../shared/widgets/tts_play_button.dart';
import '../../data/models/lesson_models.dart';

class LessonVocabLearningStep extends StatefulWidget {
  final List<VocabItemModel> vocabItems;
  final VoidCallback onNext;
  final VoidCallback? onBackToPrev;

  const LessonVocabLearningStep({
    super.key,
    required this.vocabItems,
    required this.onNext,
    this.onBackToPrev,
  });

  @override
  State<LessonVocabLearningStep> createState() =>
      _LessonVocabLearningStepState();
}

class _LessonVocabLearningStepState extends State<LessonVocabLearningStep> {
  int _currentIndex = 0;

  List<VocabItemModel> get _uniqueVocab {
    final seen = <String>{};
    return widget.vocabItems.where((vocab) {
      final key = '${vocab.word}_${vocab.reading}';
      return seen.add(key);
    }).toList();
  }

  void _next() {
    final vocab = _uniqueVocab;
    if (_currentIndex < vocab.length - 1) {
      setState(() => _currentIndex++);
    } else {
      widget.onNext();
    }
  }

  void _prev() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    } else {
      widget.onBackToPrev?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vocab = _uniqueVocab;
    if (vocab.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onNext());
      return const SizedBox.shrink();
    }

    final item = vocab[_currentIndex];
    final isLast = _currentIndex == vocab.length - 1;
    final showReading = item.word != item.reading;

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '단어 ${_currentIndex + 1}/${vocab.length}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.lightSubtext,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '단어 학습',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.primaryStrong,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: (_currentIndex + 1) / vocab.length,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primaryStrong,
                    ),
                    minHeight: 3,
                  ),
                ),
                const Spacer(),
                Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.05, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Container(
                      key: ValueKey('vocab-$_currentIndex'),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.lg,
                        vertical: AppSizes.xl,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lightCard,
                        borderRadius:
                            BorderRadius.circular(AppSizes.cardRadius),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.word,
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.lightText,
                            ),
                          ),
                          if (showReading) ...[
                            const SizedBox(height: AppSizes.sm),
                            Text(
                              item.reading,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AppColors.lightSubtext,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSizes.md),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.md,
                              vertical: AppSizes.sm,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius:
                                  BorderRadius.circular(AppSizes.radiusSm),
                            ),
                            child: Text(
                              item.meaningKo,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AppColors.primaryStrong,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSizes.md),
                          Text(
                            item.partOfSpeech,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.lightSubtext,
                            ),
                          ),
                          const SizedBox(height: AppSizes.md),
                          TtsPlayButton(
                            text: item.word,
                            iconSize: 28,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Row(
              children: [
                if (_currentIndex > 0 || widget.onBackToPrev != null)
                  Expanded(
                    child: SizedBox(
                      height: AppSizes.buttonHeight,
                      child: OutlinedButton.icon(
                        onPressed: _prev,
                        icon: const Icon(LucideIcons.chevronLeft),
                        label: const Text('이전'),
                      ),
                    ),
                  ),
                if (_currentIndex > 0 || widget.onBackToPrev != null)
                  const SizedBox(width: AppSizes.sm),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: AppSizes.buttonHeight,
                    child: FilledButton.icon(
                      onPressed: _next,
                      icon: Icon(
                        isLast ? LucideIcons.check : LucideIcons.chevronRight,
                      ),
                      label: Text(isLast ? '다음 단계로' : '다음 단어'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
