import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../data/models/lesson_models.dart';

class LessonMatchingGameStep extends StatefulWidget {
  final List<VocabItemModel> vocabItems;
  final VoidCallback onComplete;

  const LessonMatchingGameStep({
    super.key,
    required this.vocabItems,
    required this.onComplete,
  });

  @override
  State<LessonMatchingGameStep> createState() => _LessonMatchingGameStepState();
}

class _LessonMatchingGameStepState extends State<LessonMatchingGameStep>
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

    if (_pairs.length < 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onComplete();
      });
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _initPairs() {
    final seen = <String>{};
    final unique = <VocabItemModel>[];
    for (final vocab in widget.vocabItems) {
      final key = vocab.meaningKo.trim();
      if (key.isNotEmpty && seen.add(key)) unique.add(vocab);
    }
    unique.shuffle(Random());
    _pairs = unique.take(min(4, unique.length)).toList();
    _shuffledRightIndices = List.generate(_pairs.length, (index) => index)
      ..shuffle(Random());
    _selectedLeft = null;
    _selectedRight = null;
    _matched.clear();
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
      return;
    }

    setState(() => _wrongFlash = true);
    _shakeController.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() {
        _selectedLeft = null;
        _selectedRight = null;
        _wrongFlash = false;
      });
    });
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
              color: AppColors.purple,
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            '일본어와 뜻을 연결하세요',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.lightSubtext,
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
                children: List.generate(_pairs.length, (index) {
                  final rightIndex = _shuffledRightIndices[index];
                  final leftMatched = _matched.contains(index);
                  final rightMatched = _matched.contains(rightIndex);
                  final leftSelected = _selectedLeft == index && !leftMatched;
                  final rightSelected =
                      _selectedRight == rightIndex && !rightMatched;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSizes.sm),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 300),
                              opacity: leftMatched ? 0.3 : 1.0,
                              child: _MatchCard(
                                onTap: leftMatched
                                    ? null
                                    : () => _onTapLeft(index),
                                isSelected: leftSelected,
                                isMatched: leftMatched,
                                isWrong: _wrongFlash && leftSelected,
                                brightness: brightness,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _pairs[index].word,
                                      style:
                                          theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (_pairs[index].reading !=
                                        _pairs[index].word) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        _pairs[index].reading,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: AppColors.lightSubtext,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSizes.gap),
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
    Color backgroundColor;
    Color borderColor;

    if (isMatched) {
      backgroundColor = AppColors.success(brightness).withValues(alpha: 0.15);
      borderColor = AppColors.success(brightness);
    } else if (isWrong) {
      backgroundColor = AppColors.error(brightness).withValues(alpha: 0.15);
      borderColor = AppColors.error(brightness);
    } else if (isSelected) {
      backgroundColor = AppColors.purpleTrack;
      borderColor = AppColors.purple;
    } else {
      backgroundColor = AppColors.lightCard;
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
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Center(child: child),
      ),
    );
  }
}
