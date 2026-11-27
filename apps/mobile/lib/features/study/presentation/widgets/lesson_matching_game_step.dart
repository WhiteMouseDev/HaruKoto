import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/theme/haru_semantic_colors.dart';
import '../../../../core/theme/haru_typography.dart';
import '../../data/models/lesson_models.dart';
import 'lesson_stage_actions.dart';

const _matchingSecondaryText = Color(0xFF505050);
const _matchingSelection = Color(0xFFFF5173);
const _matchingCorrect = Color(0xFF00C853);

class LessonMatchingGameStep extends StatefulWidget {
  final List<VocabItemModel> vocabItems;
  final VoidCallback onComplete;
  final VoidCallback? onPrevious;
  final List<String>? pairOrder;
  final List<int>? rightOrder;
  final Set<int> initialMatched;
  final int? initialLeft;
  final int? initialRight;
  final bool autoAdvance;
  final void Function(Set<int> matched, int? left, int? right)? onProgress;
  final void Function(
    String leftVocabularyId,
    String rightVocabularyId,
    Set<int> matched,
    int? left,
    int? right,
  )? onAnswer;

  const LessonMatchingGameStep({
    super.key,
    required this.vocabItems,
    required this.onComplete,
    this.onPrevious,
    this.pairOrder,
    this.rightOrder,
    this.initialMatched = const {},
    this.initialLeft,
    this.initialRight,
    this.autoAdvance = true,
    this.onProgress,
    this.onAnswer,
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

    if (_pairs.length < 2 && widget.autoAdvance) {
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
    _pairs = widget.pairOrder == null
        ? unique.take(min(4, unique.length)).toList()
        : [
            for (final id in widget.pairOrder!)
              widget.vocabItems.firstWhere((item) => item.id == id),
          ];
    _shuffledRightIndices = widget.rightOrder == null
        ? (List.generate(_pairs.length, (index) => index)..shuffle(Random()))
        : List<int>.from(widget.rightOrder!);
    _selectedLeft = widget.initialLeft;
    _selectedRight = widget.initialRight;
    _matched
      ..clear()
      ..addAll(widget.initialMatched);
  }

  void _notifyProgress() => widget.onProgress?.call(
        Set<int>.from(_matched),
        _selectedLeft,
        _selectedRight,
      );

  void _onTapLeft(int index) {
    if (_matched.contains(index)) return;
    setState(() {
      _selectedLeft = index;
      _wrongFlash = false;
    });
    _checkMatch();
    _notifyProgress();
  }

  void _onTapRight(int index) {
    if (_matched.contains(index)) return;
    setState(() {
      _selectedRight = index;
      _wrongFlash = false;
    });
    _checkMatch();
    _notifyProgress();
  }

  void _checkMatch() {
    if (_selectedLeft == null || _selectedRight == null) return;

    final leftId = _pairs[_selectedLeft!].id;
    final rightId = _pairs[_selectedRight!].id;

    if (_selectedLeft == _selectedRight) {
      setState(() {
        _matched.add(_selectedLeft!);
        _selectedLeft = null;
        _selectedRight = null;
      });
      widget.onAnswer?.call(
        leftId,
        rightId,
        Set<int>.from(_matched),
        _selectedLeft,
        _selectedRight,
      );
      return;
    }

    setState(() => _wrongFlash = true);
    widget.onAnswer?.call(
      leftId,
      rightId,
      Set<int>.from(_matched),
      _selectedLeft,
      _selectedRight,
    );
    _shakeController.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() {
        _selectedLeft = null;
        _selectedRight = null;
        _wrongFlash = false;
      });
      _notifyProgress();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final foreground =
        light ? AppColors.redesignForeground : theme.colorScheme.onSurface;
    final muted =
        light ? _matchingSecondaryText : theme.colorScheme.onSurfaceVariant;
    final canContinue = _matched.length == _pairs.length ||
        (!widget.autoAdvance && _pairs.length < 2);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.pageHorizontal,
              // The lesson progress row already reserves room for its shortcut.
              AppSizes.xs / 2,
              AppSizes.pageHorizontal,
              AppSizes.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    '단어 매칭',
                    style: HaruTypography.krTitle3.copyWith(
                      fontSize: 16,
                      letterSpacing: -0.4,
                      color: foreground,
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.xs),
                Text(
                  '일본어와 뜻을 연결하세요.',
                  style: HaruTypography.krBody3.copyWith(color: muted),
                ),
                const SizedBox(height: AppSizes.sm),
                AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    final shakeOffset = _wrongFlash
                        ? sin(_shakeAnimation.value * pi * 4) * 6
                        : 0.0;
                    return Transform.translate(
                      offset: Offset(shakeOffset, 0),
                      child: child,
                    );
                  },
                  child: Column(
                    children: [
                      for (var index = 0; index < _pairs.length; index++) ...[
                        if (index > 0) const SizedBox(height: AppSizes.gap),
                        _pairRow(index),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        LessonStageActions(
          nextLabel: '다음 학습',
          showPrevious: true,
          onPrevious: widget.onPrevious,
          onNext: canContinue ? widget.onComplete : null,
        ),
      ],
    );
  }

  Widget _pairRow(int index) {
    final rightIndex = _shuffledRightIndices[index];
    final left = _pairs[index];
    final right = _pairs[rightIndex];
    final leftStatus = _status(index, _selectedLeft);
    final rightStatus = _status(rightIndex, _selectedRight);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _MatchCard(
              label: left.word,
              reading: left.reading == left.word || left.reading.trim().isEmpty
                  ? null
                  : left.reading,
              isJapanese: true,
              status: leftStatus,
              onPressed: leftStatus == _MatchStatus.matched
                  ? null
                  : () => _onTapLeft(index),
            ),
          ),
          const SizedBox(width: AppSizes.gap),
          Expanded(
            child: _MatchCard(
              label: right.meaningKo,
              status: rightStatus,
              onPressed: rightStatus == _MatchStatus.matched
                  ? null
                  : () => _onTapRight(rightIndex),
            ),
          ),
        ],
      ),
    );
  }

  _MatchStatus _status(int index, int? selected) {
    if (_matched.contains(index)) return _MatchStatus.matched;
    if (index != selected) return _MatchStatus.plain;
    return _wrongFlash ? _MatchStatus.wrong : _MatchStatus.selected;
  }
}

enum _MatchStatus { plain, selected, matched, wrong }

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.label,
    required this.status,
    required this.onPressed,
    this.reading,
    this.isJapanese = false,
  });

  final String label;
  final String? reading;
  final bool isJapanese;
  final _MatchStatus status;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final semanticColors = HaruSemanticColors.of(context);
    final light = theme.brightness == Brightness.light;
    final surface = light ? AppColors.lightCard : colors.surfaceContainerLowest;
    final foreground = light ? AppColors.redesignForeground : colors.onSurface;
    final muted = light ? _matchingSecondaryText : colors.onSurfaceVariant;
    final (background, outline) = switch (status) {
      _MatchStatus.plain => (
          surface,
          light ? AppColors.redesignOutline : colors.outlineVariant,
        ),
      _MatchStatus.selected => (
          surface,
          light ? _matchingSelection : colors.primary,
        ),
      _MatchStatus.matched => (
          light
              ? _matchingCorrect.withValues(alpha: 0.08)
              : AppColors.quizCorrectBgDark,
          light
              ? _matchingCorrect
              : semanticColors.success.withValues(alpha: 0.4),
        ),
      _MatchStatus.wrong => (
          light ? AppColors.quizWrongBg : AppColors.quizWrongBgDark,
          semanticColors.error,
        ),
    };
    final labelStyle = isJapanese
        ? HaruTypography.jpBody3.copyWith(
            fontSize: 15,
            letterSpacing: -0.375,
            fontWeight: FontWeight.w600,
          )
        : HaruTypography.krCompactButton;
    final matchedForeground =
        light ? foreground : Color.lerp(foreground, muted, 0.65)!;

    return Semantics(
      selected: status == _MatchStatus.selected || status == _MatchStatus.wrong,
      value: switch (status) {
        _MatchStatus.matched => '맞춘 짝',
        _MatchStatus.wrong => '틀린 짝',
        _ => null,
      },
      child: Opacity(
        opacity: light && status == _MatchStatus.matched ? 0.5 : 1,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: background,
            disabledBackgroundColor: background,
            foregroundColor: foreground,
            disabledForegroundColor: matchedForeground,
            side: BorderSide(
              color: outline,
              width: status == _MatchStatus.selected ? 2 : 1,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.gap),
            ),
            minimumSize: const Size(double.infinity, 86),
            padding: const EdgeInsets.all(AppSizes.gap),
            visualDensity: VisualDensity.standard,
            textStyle: labelStyle,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, textAlign: TextAlign.center),
              if (reading case final value?) ...[
                const SizedBox(height: AppSizes.xs / 2),
                Text(
                  value,
                  textAlign: TextAlign.center,
                  style: HaruTypography.jpBody3.copyWith(
                    fontSize: 12,
                    letterSpacing: -0.3,
                    color: muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
