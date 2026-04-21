import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../data/models/lesson_models.dart';

export 'lesson_recognition_check_step.dart';

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

class LessonSentenceReorderStep extends StatefulWidget {
  final List<LessonQuestionModel> questions;
  final int currentIndex;
  final int totalSteps;
  final List<VocabItemModel> vocabItems;
  final ValueChanged<Map<String, dynamic>> onAnswer;

  const LessonSentenceReorderStep({
    super.key,
    required this.questions,
    required this.currentIndex,
    required this.totalSteps,
    required this.vocabItems,
    required this.onAnswer,
  });

  @override
  State<LessonSentenceReorderStep> createState() =>
      _LessonSentenceReorderStepState();
}

class _LessonSentenceReorderStepState extends State<LessonSentenceReorderStep> {
  late List<String> _available;
  final List<String> _selected = [];
  late int _correctTokenCount;
  bool _submitting = false;
  String? _lastAddedToken;
  String? _lastRemovedToken;
  int _dragHoverIndex = -1;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(covariant LessonSentenceReorderStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _reset();
    }
  }

  bool get _isFull => _selected.length >= _correctTokenCount;

  void _reset() {
    final question = widget.questions[widget.currentIndex];
    final correctTokens = question.tokens ?? [];
    _correctTokenCount = correctTokens.length;

    final correctSet = correctTokens.toSet();
    final distractors = widget.vocabItems
        .map((vocab) => vocab.word)
        .where((word) => word.trim().isNotEmpty && !correctSet.contains(word))
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
    final question = widget.questions[widget.currentIndex];
    setState(() => _submitting = true);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _submitting = false);
      widget.onAnswer({
        'order': question.order,
        'submittedOrder': List<String>.from(_selected),
        'responseMs': 0,
      });
    });
  }

  Widget _buildAnswerArea() {
    final remaining = _correctTokenCount - _selected.length;
    final children = <Widget>[];

    for (int index = 0; index < _selected.length; index++) {
      final token = _selected[index];
      final isJustAdded = _lastAddedToken == token;
      final isHovered = _dragHoverIndex == index;

      children.add(
        DragTarget<int>(
          key: ValueKey('answer-target-$index'),
          onWillAcceptWithDetails: (details) {
            if (details.data != index) {
              setState(() => _dragHoverIndex = index);
            }
            return details.data != index;
          },
          onLeave: (_) {
            if (_dragHoverIndex == index) {
              setState(() => _dragHoverIndex = -1);
            }
          },
          onAcceptWithDetails: (details) {
            _onReorder(details.data, index);
          },
          builder: (context, candidateData, rejectedData) {
            return LongPressDraggable<int>(
              data: index,
              delay: const Duration(milliseconds: 200),
              feedback: Material(
                color: Colors.transparent,
                child: _AnswerToken(
                  text: token,
                  index: index,
                  isDragging: true,
                  isHovered: false,
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.3,
                child: _AnswerToken(
                  text: token,
                  index: index,
                  isDragging: false,
                  isHovered: false,
                ),
              ),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: isJustAdded ? 0.8 : 1.0, end: 1.0),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: GestureDetector(
                  onTap: _submitting ? null : () => _deselectToken(index),
                  child: _AnswerToken(
                    text: token,
                    index: index,
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

    for (int index = 0; index < remaining; index++) {
      children.add(
        Container(
          key: ValueKey('empty-slot-${_selected.length + index}'),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final question = widget.questions[widget.currentIndex];

    return Padding(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '5/${widget.totalSteps} · 문항 ${widget.currentIndex + 1}/${widget.questions.length}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.lightSubtext,
            ),
          ),
          const SizedBox(height: AppSizes.md),
          Text(
            question.prompt,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.lightText,
            ),
          ),
          if (question.explanation != null) ...[
            const SizedBox(height: AppSizes.xs),
            Text(
              question.explanation!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.lightSubtext,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 20),
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
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 70),
            padding: const EdgeInsets.all(AppSizes.gap),
            decoration: BoxDecoration(
              color: AppColors.lightCard,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              border: Border.all(color: AppColors.lightBorder),
            ),
            child: _buildAnswerArea(),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _available.asMap().entries.map((entry) {
              final token = entry.value;
              final isJustReturned = _lastRemovedToken == token;
              final disabled = _isFull || _submitting;
              return TweenAnimationBuilder<double>(
                key: ValueKey('bank-$token-${entry.key}'),
                tween: Tween(begin: isJustReturned ? 0.8 : 1.0, end: 1.0),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
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
      backgroundColor = AppColors.primary.withValues(alpha: 0.15);
      borderColor = AppColors.primaryStrong;
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
            border: Border.all(color: AppColors.lightBorder),
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
