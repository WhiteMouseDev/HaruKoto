import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/theme/haru_typography.dart';
import '../../data/models/lesson_models.dart';
import 'lesson_stage_actions.dart';

class LessonSentenceReorderStep extends StatefulWidget {
  const LessonSentenceReorderStep({
    super.key,
    required this.questions,
    required this.currentIndex,
    required this.vocabItems,
    required this.onAnswer,
    this.shuffledBank,
    this.initialSelected = const [],
    this.initialAvailable,
    this.onDraftChanged,
    this.onPrevious,
  });

  final List<LessonQuestionModel> questions;
  final int currentIndex;
  final List<VocabItemModel> vocabItems;
  final ValueChanged<Map<String, dynamic>> onAnswer;
  final List<String>? shuffledBank;
  final List<String> initialSelected;
  final List<String>? initialAvailable;
  final void Function(List<String> selected, List<String> available)?
      onDraftChanged;
  final VoidCallback? onPrevious;

  @override
  State<LessonSentenceReorderStep> createState() =>
      _LessonSentenceReorderStepState();
}

class _LessonSentenceReorderStepState extends State<LessonSentenceReorderStep> {
  static final _quotedPrompt = RegExp(
    r"^'(.+)'[을를] (?:올바른 순서로 )?배열하세요\.?$",
  );
  static const _moveEarlier = CustomSemanticsAction(label: '앞으로 이동');
  static const _moveLater = CustomSemanticsAction(label: '뒤로 이동');

  late List<String> _bank;
  late List<int> _available;
  final List<int> _selected = [];
  late int _correctTokenCount;
  bool _submitting = false;
  bool _showHint = false;
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
    final tokens = question.tokens ?? const [];
    _correctTokenCount = tokens.length;

    final restoredAvailable = widget.initialAvailable;
    _bank = switch ((widget.shuffledBank, restoredAvailable)) {
      (final bank?, _) => List.of(bank),
      (_, final available?) => [...available, ...widget.initialSelected],
      _ => _makeBank(tokens),
    };

    // Use a separate slot for each occurrence of repeated tokens.
    final unused = [for (var slot = 0; slot < _bank.length; slot++) slot];
    int takeSlot(String token) {
      final index = unused.indexWhere((slot) => _bank[slot] == token);
      if (index >= 0) return unused.removeAt(index);
      _bank.add(token);
      return _bank.length - 1;
    }

    _selected
      ..clear()
      ..addAll(widget.initialSelected.map(takeSlot));
    _available = restoredAvailable == null
        ? unused
        : restoredAvailable.map(takeSlot).toList();
    _submitting = false;
    _showHint = false;
    _dragHoverIndex = -1;
  }

  List<String> _makeBank(List<String> tokens) {
    final distractors = widget.vocabItems
        .map((item) => item.word)
        .where((word) => word.trim().isNotEmpty && !tokens.contains(word))
        .toSet()
        .toList()
      ..shuffle(Random());
    final picked = distractors.take(min(3, distractors.length));
    return [...tokens, ...picked]..shuffle(Random());
  }

  List<String> _wordsFor(List<int> slots) {
    return [for (final slot in slots) _bank[slot]];
  }

  void _notifyDraft() => widget.onDraftChanged?.call(
        _wordsFor(_selected),
        _wordsFor(_available),
      );

  void _selectToken(int slot) {
    if (_isFull || _submitting || !_available.contains(slot)) return;
    setState(() {
      _available.remove(slot);
      _selected.add(slot);
    });
    _notifyDraft();
  }

  void _deselectToken(int index) {
    if (_submitting || index < 0 || index >= _selected.length) return;
    setState(() => _available.add(_selected.removeAt(index)));
    _notifyDraft();
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
      final token = _selected.removeAt(fromIndex);
      _selected.insert(toIndex, token);
      _dragHoverIndex = -1;
    });
    _notifyDraft();
  }

  void _submit() {
    if (!_isFull || _submitting) return;
    final question = widget.questions[widget.currentIndex];
    final submittedOrder = _wordsFor(_selected);
    setState(() => _submitting = true);
    // Confirm is the answer boundary. Record before close or background can
    // flush the checkpoint and stay locked until the parent transitions.
    widget.onAnswer({
      'order': question.order,
      'submittedOrder': submittedOrder,
      'responseMs': 0,
    });
  }

  Widget _answerToken(int index) {
    final slot = _selected[index];
    final text = _bank[slot];
    final editable = !_submitting;
    final onTap = editable ? () => _deselectToken(index) : null;
    return DragTarget<int>(
      key: ValueKey('answer-target-$index'),
      onWillAcceptWithDetails: (details) {
        if (!editable || details.data == index) return false;
        setState(() => _dragHoverIndex = index);
        return true;
      },
      onLeave: (_) {
        if (_dragHoverIndex == index) {
          setState(() => _dragHoverIndex = -1);
        }
      },
      onAcceptWithDetails: (details) => _onReorder(details.data, index),
      builder: (context, candidateData, rejectedData) {
        return LongPressDraggable<int>(
          data: index,
          maxSimultaneousDrags: editable ? 1 : 0,
          delay: const Duration(milliseconds: 200),
          feedback: Material(
            type: MaterialType.transparency,
            child: _ReorderToken(text: text, highlighted: true),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: _ReorderToken(text: text),
          ),
          child: Semantics(
            button: true,
            enabled: editable,
            label: text,
            hint: editable ? '탭해서 토큰 목록으로 돌려보내기' : null,
            onTap: onTap,
            customSemanticsActions: editable
                ? {
                    if (index > 0)
                      _moveEarlier: () => _onReorder(index, index - 1),
                    if (index + 1 < _selected.length)
                      _moveLater: () => _onReorder(index, index + 1),
                  }
                : null,
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: _ReorderToken(
                text: text,
                highlighted: _dragHoverIndex == index,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _bankToken(int slot) {
    final text = _bank[slot];
    final placed = !_available.contains(slot);
    final enabled = !placed && !_isFull && !_submitting;
    final onTap = enabled ? () => _selectToken(slot) : null;
    return Semantics(
      key: ValueKey('bank-slot-$slot'),
      button: true,
      enabled: enabled,
      label: text,
      value: placed ? '답안에 배치됨' : null,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: _ReorderToken(text: text, muted: placed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final light = theme.brightness == Brightness.light;
    final foreground = light ? AppColors.redesignForeground : colors.onSurface;
    final muted =
        light ? AppColors.redesignMutedForeground : colors.onSurfaceVariant;
    final outline = light ? AppColors.redesignOutline : colors.outlineVariant;
    final question = widget.questions[widget.currentIndex];
    final rawPrompt = question.prompt.trim();
    final hint = question.explanation?.trim();
    final prompt = _quotedPrompt.firstMatch(rawPrompt)?.group(1) ?? rawPrompt;
    final selectedCount = _selected.length;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.pageHorizontal,
              AppSizes.md,
              AppSizes.pageHorizontal,
              AppSizes.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '문장 배열',
                  style: HaruTypography.krTitle3.copyWith(
                    color: foreground,
                    fontSize: 16,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: AppSizes.xs),
                Text(
                  '토큰을 탭해서 주어진 뜻에 맞게 문장을 완성하세요.',
                  style: HaruTypography.krBody3.copyWith(color: muted),
                ),
                const SizedBox(height: AppSizes.lg),
                Container(
                  padding: const EdgeInsets.all(AppSizes.md),
                  decoration: BoxDecoration(
                    color: light
                        ? AppColors.redesignSurface
                        : colors.surfaceContainerHigh,
                    border: Border.all(color: outline),
                    borderRadius: BorderRadius.circular(AppSizes.gap),
                  ),
                  child: Column(
                    children: [
                      Text(
                        prompt,
                        textAlign: TextAlign.center,
                        style: HaruTypography.krTitle3.copyWith(
                          color: foreground,
                          fontSize: 16,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: AppSizes.md),
                      Semantics(
                        container: true,
                        label: '정답 영역, 선택 $selectedCount/$_correctTokenCount',
                        child: Container(
                          key: const ValueKey('sentence-reorder-answer-well'),
                          width: double.infinity,
                          constraints: const BoxConstraints(minHeight: 56),
                          padding: const EdgeInsets.all(AppSizes.xs),
                          decoration: BoxDecoration(
                            color: light
                                ? AppColors.lightCard
                                : colors.surfaceContainerLowest,
                            border: Border.all(color: outline),
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusSm),
                          ),
                          child: Wrap(
                            spacing: AppSizes.xs,
                            runSpacing: AppSizes.xs,
                            children: [
                              for (var index = 0;
                                  index < selectedCount;
                                  index++)
                                _answerToken(index),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.lg),
                Wrap(
                  spacing: AppSizes.sm,
                  children: [
                    for (var slot = 0; slot < _bank.length; slot++)
                      _bankToken(slot),
                  ],
                ),
                if (hint != null && hint.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => setState(() => _showHint = !_showHint),
                      child: Text(_showHint ? '힌트 숨기기' : '힌트 보기'),
                    ),
                  ),
                  if (_showHint)
                    Text(hint,
                        style: HaruTypography.krBody3.copyWith(color: muted)),
                ],
              ],
            ),
          ),
        ),
        LessonStageActions(
          nextLabel: _isFull ? '정답 확인' : '다음 학습',
          onNext: _isFull && !_submitting ? _submit : null,
          onPrevious: _submitting ? null : widget.onPrevious,
          showPrevious: true,
          accentNext: false,
          showNextChevron: false,
        ),
      ],
    );
  }
}

class _ReorderToken extends StatelessWidget {
  const _ReorderToken({
    required this.text,
    this.muted = false,
    this.highlighted = false,
  });

  final String text;
  final bool muted;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final light = theme.brightness == Brightness.light;
    final foreground = light ? AppColors.redesignForeground : colors.onSurface;
    final outline = light ? AppColors.redesignOutline : colors.outlineVariant;
    final surface = light ? AppColors.lightCard : colors.surfaceContainerLowest;
    final background = muted
        ? light
            ? AppColors.redesignControl
            : colors.surfaceContainerHigh
        : surface;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40, minWidth: 40),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.sm,
            vertical: AppSizes.xs,
          ),
          decoration: BoxDecoration(
            color: background,
            border: Border.all(
              color: highlighted ? colors.primary : outline,
            ),
            borderRadius: BorderRadius.circular(AppSizes.xs),
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: HaruTypography.jpBody3.copyWith(
                fontSize: 14,
                letterSpacing: -0.35,
                fontWeight: FontWeight.w500,
                color: muted
                    ? light
                        ? AppColors.redesignMutedForeground
                        : colors.onSurfaceVariant
                    : foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
