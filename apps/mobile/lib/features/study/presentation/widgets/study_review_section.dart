import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/auth/current_account_provider.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/text_theme.dart';
import '../../data/models/review_summary_model.dart';
import '../../providers/lesson_pilot_telemetry_provider.dart';
import '../../providers/study_provider.dart';
import '../quiz_launch.dart';
import '../study_map_colors.dart';

/// Review reads fail independently of the curriculum. A category action always
/// names the batch it opens; the combined due count is never a mixed quiz.
class StudyReviewSection extends ConsumerStatefulWidget {
  const StudyReviewSection({
    super.key,
    required this.jlptLevel,
    required this.mapEnabled,
    this.redesigned = false,
    this.routeBuilder = buildQuizPageRoute,
  });

  final String jlptLevel;
  final bool mapEnabled;
  final bool redesigned;
  final QuizRouteBuilder routeBuilder;

  @override
  ConsumerState<StudyReviewSection> createState() => _StudyReviewSectionState();
}

class _StudyReviewSectionState extends ConsumerState<StudyReviewSection> {
  static const _buttonHitInset = 3.0;
  static const _secondaryText = Color(0xFF505050);

  bool _opening = false;

  bool _isCurrent(String? owner) =>
      mounted &&
      owner != null &&
      ref.read(currentAccountIdProvider) == owner &&
      ref.read(currentAccountReaderProvider)() == owner;

  void _retry(String? owner, String level) {
    if (!_isCurrent(owner) ||
        widget.jlptLevel != level ||
        ref.read(reviewSummaryProvider(level)).isLoading) {
      return;
    }
    ref.invalidate(reviewSummaryProvider(level));
  }

  Future<void> _openReview({
    required String? owner,
    required String level,
    required ReviewSummaryModel summary,
    required String quizType,
    required int due,
  }) async {
    if (_opening ||
        due <= 0 ||
        !_isCurrent(owner) ||
        widget.jlptLevel != level) {
      return;
    }
    setState(() => _opening = true);
    try {
      ref.read(lessonPilotTelemetryProvider).trackReviewCtaClicked(
            jlptLevel: level,
            totalDue: summary.totalDue,
            wordDue: summary.wordDue,
            grammarDue: summary.grammarDue,
            quizType: quizType,
          );
      await openQuizPage(
        context,
        request: QuizLaunchRequest(
          quizType: quizType,
          // Match the review summary's N5 content mapping; retain the selected
          // level for cache and return guards.
          jlptLevel: level == 'ABSOLUTE_ZERO' ? 'N5' : level,
          count: math.min(due, 10),
          mode: 'review',
        ),
        routeBuilder: widget.routeBuilder,
      );
    } finally {
      if (mounted) {
        setState(() => _opening = false);
        if (_isCurrent(owner) && widget.jlptLevel == level) {
          ref.invalidate(reviewSummaryProvider(level));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final level = widget.jlptLevel;
    final owner = ref.watch(currentAccountIdProvider);
    final review = ref.watch(reviewSummaryProvider(widget.jlptLevel));
    // Retained AsyncValue data/errors belong to the previous read while a new
    // request is pending. Never let them launch a quiz or imply zero due items.
    if (!_isCurrent(owner) || review.isLoading) {
      return _panel(context, const [
        Text('복습 현황을 불러오고 있어요.'),
        SizedBox(height: 12),
        LinearProgressIndicator(semanticsLabel: '복습 현황 불러오는 중'),
      ]);
    }
    if (review.hasError) {
      final error = review.error;
      final message = error is DioException
          ? ApiException.fromDioException(error).userMessage
          : error is ApiException
              ? error.userMessage
              : const ApiException(message: '잠시 후 다시 시도해 주세요.').userMessage;
      return _panel(context, [
        const Text('복습 현황을 확인하지 못했어요.'),
        const SizedBox(height: 6),
        Text(message, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        const Text('레슨 학습은 계속할 수 있어요.'),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const ValueKey('review-summary-retry'),
          onPressed: () => _retry(owner, level),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            foregroundColor: _accent(context),
          ),
          icon: const Icon(LucideIcons.refreshCw, size: 18),
          label: const Text('다시 확인', semanticsLabel: '복습 현황 다시 확인'),
        ),
      ]);
    }
    final summary = review.requireValue;
    if (summary.wordDue <= 0 && summary.grammarDue <= 0) {
      return _panel(context, [
        Text('지금 복습할 표현이 없어요', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        const Text('새 레슨을 배우거나 다음 복습 시간에 다시 만나요.'),
      ]);
    }
    final breakdown = '단어 ${summary.wordDue}개 · 문법 ${summary.grammarDue}개';
    final hasBoth = summary.wordDue > 0 && summary.grammarDue > 0;
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    return _panel(
        context,
        [
          if (widget.redesigned) ...[
            Semantics(
              header: true,
              child: Text('오늘 복습할 표현',
                  style: TextStyle(
                    fontFamily: redesignFontFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    letterSpacing: -0.45,
                    color: light
                        ? AppColors.redesignForeground
                        : theme.colorScheme.onSurface,
                  )),
            ),
            const SizedBox(height: 4),
            Transform.translate(
              offset: const Offset(0, 1),
              child: Text(
                hasBoth
                    ? '단어와 문법을 골라 한 번에 최대 10개씩 복습해요.'
                    : '학습한 내용을 복습하고, 실력을 키워봐요!',
                style: TextStyle(
                  fontFamily: redesignFontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                  letterSpacing: -0.325,
                  color: light
                      ? _secondaryText
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 12 - _buttonHitInset),
          ] else ...[
            Text('복습할 표현 ${summary.totalDue}개',
                style: theme.textTheme.headlineSmall?.copyWith(
                    fontSize: 24, fontWeight: FontWeight.w800, height: 1.3)),
            const SizedBox(height: 6),
            Text(breakdown),
            const SizedBox(height: 6),
            const Text('단어와 문법을 골라 한 번에 최대 10개씩 복습해요.'),
            const SizedBox(height: 16),
          ],
          if (summary.wordDue > 0)
            _categoryButton(context,
                owner: owner,
                summary: summary,
                label: '단어',
                quizType: 'VOCABULARY',
                due: summary.wordDue),
          if (hasBoth) SizedBox(height: widget.redesigned ? 8 : 10),
          if (summary.grammarDue > 0)
            _categoryButton(context,
                owner: owner,
                summary: summary,
                label: '문법',
                quizType: 'GRAMMAR',
                due: summary.grammarDue),
        ],
        breakdown: widget.redesigned ? breakdown : null);
  }

  Color _accent(BuildContext context) => widget.mapEnabled
      ? StudyMapColors.accent(Theme.of(context).brightness)
      : AppColors.primaryStrong;

  Widget _categoryButton(BuildContext context,
      {required String? owner,
      required ReviewSummaryModel summary,
      required String label,
      required String quizType,
      required int due}) {
    final batch = math.min(due, 10);
    final level = widget.jlptLevel;
    final brightness = Theme.of(context).brightness;
    final light = brightness == Brightness.light;
    final buttonLabel =
        widget.redesigned && (summary.wordDue <= 0 || summary.grammarDue <= 0)
            ? '복습 시작'
            : '$label 최대 $batch개 복습';
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        key: ValueKey('review-category-$quizType'),
        onPressed: _opening
            ? null
            : () => unawaited(_openReview(
                owner: owner,
                level: level,
                summary: summary,
                quizType: quizType,
                due: due)),
        style: FilledButton.styleFrom(
          backgroundColor: widget.redesigned
              ? (light ? AppColors.brandPink : null)
              : (widget.mapEnabled
                  ? StudyMapColors.button(brightness)
                  : AppColors.sakuraContainer),
          foregroundColor: widget.redesigned
              ? (light ? Colors.white : null)
              : _accent(context),
          minimumSize: Size.fromHeight(widget.redesigned ? 42 : 48),
          tapTargetSize: MaterialTapTargetSize.padded,
          visualDensity: widget.redesigned ? VisualDensity.standard : null,
          padding: EdgeInsets.symmetric(
              horizontal: widget.redesigned ? 20 : 16,
              vertical: widget.redesigned ? 10 : 12),
          textStyle: widget.redesigned
              ? const TextStyle(
                  fontFamily: redesignFontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                  letterSpacing: -0.35,
                )
              : null,
        ),
        child: Text(buttonLabel,
            semanticsLabel: '$label 복습, 남은 $due개 중 최대 $batch개',
            textAlign: TextAlign.center),
      ),
    );
  }

  Widget _panel(BuildContext context, List<Widget> children,
      {String? breakdown}) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final header = widget.redesigned
        ? Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Image.asset('assets/icons/figma-study-review.png',
                  width: 40, height: 40, excludeFromSemantics: true),
              if (breakdown != null)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: light ? Colors.white : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Transform.translate(
                      offset: const Offset(0, 1),
                      child: Text(
                        breakdown,
                        style: TextStyle(
                          fontFamily: redesignFontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                          letterSpacing: -0.24,
                          color: light
                              ? _secondaryText
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          )
        : Row(children: [
            Icon(LucideIcons.rotateCcw, size: 20, color: _accent(context)),
            const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                header: true,
                child: Text('오늘의 복습', style: theme.textTheme.titleSmall),
              ),
            ),
          ]);
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: widget.redesigned
            ? EdgeInsets.fromLTRB(
                16, 16, 16, breakdown == null ? 16 : 16 - _buttonHitInset)
            : const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: light
              ? (widget.redesigned
                  ? AppColors.redesignSurface
                  : AppColors.cardWarm)
              : theme.colorScheme.surfaceContainerLow,
          border: widget.redesigned
              ? null
              : Border.all(
                  color: light
                      ? AppColors.lightBorder
                      : theme.colorScheme.outline),
          borderRadius:
              BorderRadius.circular(widget.redesigned ? 12 : AppSizes.radiusMd),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: double.infinity, child: header),
          const SizedBox(height: 12),
          ...children,
        ]),
      ),
    );
  }
}
