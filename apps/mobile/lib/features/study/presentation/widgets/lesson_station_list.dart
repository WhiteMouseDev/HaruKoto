import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../data/models/lesson_models.dart';
import '../../domain/lesson_recommendation.dart';
import 'lesson_station_tile.dart';
import '../study_map_colors.dart';

/// The line is a curriculum guide, never a sequential progress indicator.
class LessonStationList extends StatefulWidget {
  const LessonStationList({
    super.key,
    required this.chapters,
    required this.padding,
    this.recommendedLessonId,
  });

  final List<ChapterModel> chapters;
  final EdgeInsetsGeometry padding;
  final String? recommendedLessonId;

  @override
  State<LessonStationList> createState() => _LessonStationListState();
}

class _LessonStationListState extends State<LessonStationList> {
  String? _expandedChapterId;

  String? get _recommendedId =>
      widget.recommendedLessonId ??
      findRecommendedLesson(widget.chapters)?.lesson.id;

  @override
  void didUpdateWidget(covariant LessonStationList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refreshes create new model instances. Only a different curriculum should
    // reset browsing; opening/collapsing a station is not learning progress.
    final oldIdentity = _curriculumIdentity(oldWidget.chapters);
    final newIdentity = _curriculumIdentity(widget.chapters);
    if (!listEquals(oldIdentity, newIdentity)) {
      _expandedChapterId = null;
    }
  }

  List<String> _curriculumIdentity(List<ChapterModel> chapters) => [
        for (final chapter in chapters)
          '${chapter.jlptLevel}:${chapter.id}:'
              '${chapter.lessons.map((lesson) => lesson.id).join(',')}',
      ];

  @override
  Widget build(BuildContext context) {
    if (widget.chapters.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final subtext = theme.brightness == Brightness.light
        ? AppColors.lightSubtext
        : AppColors.darkSubtext;
    final completed = widget.chapters.where(_isChapterComplete).length;
    final multipleParts =
        widget.chapters.map((chapter) => chapter.partNo).toSet().length > 1;

    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 2, 2, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: StudyMapColors.panel(theme.brightness),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.chapters.first.jlptLevel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Text(
                      '$completed / ${widget.chapters.length}개 역 완료',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: subtext,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '관심 있는 역부터 자유롭게 학습해요',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: subtext,
                  ),
                ),
              ],
            ),
          ),
          for (var index = 0; index < widget.chapters.length; index++)
            _StationRow(
              key: ValueKey('station-${widget.chapters[index].id}'),
              chapter: widget.chapters[index],
              isFirst: index == 0,
              isLast: index == widget.chapters.length - 1,
              showPart: multipleParts,
              recommendedLessonId: _recommendedId,
              isExpanded: _expandedChapterId == widget.chapters[index].id,
              onToggle: () {
                setState(() {
                  final id = widget.chapters[index].id;
                  _expandedChapterId = _expandedChapterId == id ? null : id;
                });
              },
            ),
        ],
      ),
    );
  }
}

bool _isChapterComplete(ChapterModel chapter) =>
    chapter.totalLessons > 0 &&
    chapter.completedLessons >= chapter.totalLessons &&
    chapter.lessons.every((lesson) => lesson.status == 'COMPLETED');

enum _StationState { complete, resume, recommended, learning, idle }

class _StationRow extends StatelessWidget {
  static const _leftInset = 8.0;
  static const _verticalInset = 18.0;
  static const _markerWidth = 44.0;
  static const _markerGap = 14.0;
  static const _railWidth = 7.0;
  static const _railCenter = _leftInset + _markerWidth / 2;

  const _StationRow({
    super.key,
    required this.chapter,
    required this.isFirst,
    required this.isLast,
    required this.showPart,
    required this.recommendedLessonId,
    required this.isExpanded,
    required this.onToggle,
  });

  final ChapterModel chapter;
  final bool isFirst;
  final bool isLast;
  final bool showPart;
  final String? recommendedLessonId;
  final bool isExpanded;
  final VoidCallback onToggle;

  _StationState get _state {
    if (_isChapterComplete(chapter)) return _StationState.complete;
    final recommended = chapter.lessons
        .where((lesson) => lesson.id == recommendedLessonId)
        .firstOrNull;
    if (recommended?.status == 'IN_PROGRESS') return _StationState.resume;
    if (recommended?.status == 'NOT_STARTED') {
      return _StationState.recommended;
    }
    if (chapter.completedLessons > 0 ||
        chapter.lessons.any((lesson) => lesson.status != 'NOT_STARTED')) {
      return _StationState.learning;
    }
    return _StationState.idle;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final state = _state;
    final isRecommended =
        state == _StationState.resume || state == _StationState.recommended;
    final accent = StudyMapColors.accent(theme.brightness);
    final completeColor = isLight ? AppColors.mintOn : AppColors.mintContainer;
    final subtext = isLight ? AppColors.lightSubtext : AppColors.darkSubtext;
    final background = isRecommended
        ? isLight
            ? AppColors.lightCard
            : AppColors.darkCard
        : theme.colorScheme.surface;
    final textScaler = MediaQuery.textScalerOf(context);
    final stackTitle = textScaler.scale(16) > 21;
    final stationNumber = chapter.chapterNo.toString().padLeft(2, '0');
    final signLevel = showPart
        ? '${chapter.jlptLevel} · ${chapter.partNo}부'
        : chapter.jlptLevel;
    final signSide = _StationSign.measureSide(
      context,
      level: signLevel,
      number: stationNumber,
    );
    final nodeCenter = _verticalInset + signSide / 2;
    final stationLabel =
        showPart ? '${chapter.partNo}-$stationNumber' : stationNumber;
    final stateLabel = switch (state) {
      _StationState.complete => '완료',
      _StationState.resume => '이어할 역',
      _StationState.recommended => '추천 역',
      _StationState.learning => '학습 중',
      _StationState.idle => '시작 전',
    };
    final count = chapter.completedLessons.clamp(0, chapter.totalLessons);
    final sign = _StationSign(
      level: signLevel,
      number: stationNumber,
      side: signSide,
    );
    final chevron = Icon(
      isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
      color: subtext,
      size: 18,
    );
    final titleAndStatus = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          chapter.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 18,
            fontWeight: isRecommended ? FontWeight.w800 : FontWeight.w700,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '$count/${chapter.totalLessons} 레슨',
              style: theme.textTheme.bodySmall?.copyWith(
                color: subtext,
                fontSize: 13,
              ),
            ),
            if (state != _StationState.idle)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: isRecommended
                    ? BoxDecoration(
                        color: StudyMapColors.button(theme.brightness),
                        borderRadius: BorderRadius.circular(6),
                      )
                    : null,
                child: Text(
                  stateLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 12,
                    height: 1.2,
                    fontWeight:
                        isRecommended ? FontWeight.w800 : FontWeight.w600,
                    color: state == _StationState.complete
                        ? completeColor
                        : isRecommended
                            ? accent
                            : subtext,
                  ),
                ),
              ),
          ],
        ),
      ],
    );

    return Stack(
      children: [
        // A single brand-colored route connects every station, independent of
        // completion. Only the recommended header covers the rail with a card.
        Positioned(
          left: _railCenter - _railWidth / 2,
          top: isFirst ? nodeCenter : 0,
          bottom: isLast ? null : 0,
          height: isLast ? (isFirst ? 0 : nodeCenter) : null,
          width: _railWidth,
          child: const ColoredBox(color: StudyMapColors.route),
        ),
        Column(
          children: [
            Material(
              key: isRecommended
                  ? ValueKey('station-highlight-${chapter.id}')
                  : null,
              color: isRecommended ? background : Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isRecommended
                      ? theme.colorScheme.outline
                      : Colors.transparent,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Semantics(
                key: ValueKey('station-semantics-${chapter.id}'),
                button: true,
                onTap: onToggle,
                expanded: isExpanded,
                label: '${chapter.jlptLevel} $stationLabel역, '
                    '${chapter.title}, $stateLabel, '
                    '$count/${chapter.totalLessons} 레슨 완료',
                child: InkWell(
                  key: ValueKey('station-toggle-${chapter.id}'),
                  onTap: onToggle,
                  excludeFromSemantics: true,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        _leftInset, _verticalInset, 12, _verticalInset),
                    child: ExcludeSemantics(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: _markerWidth,
                            child: Padding(
                              padding: EdgeInsets.only(
                                top: (signSide - (isRecommended ? 50 : 34)) / 2,
                              ),
                              child: _StationNode(
                                state: state,
                                background: background,
                                color: state == _StationState.complete
                                    ? completeColor
                                    : isRecommended
                                        ? accent
                                        : subtext,
                                borderColor: state == _StationState.complete
                                    ? completeColor
                                    : isRecommended
                                        ? StudyMapColors.route
                                        : subtext,
                              ),
                            ),
                          ),
                          const SizedBox(width: _markerGap),
                          Expanded(
                            child: stackTitle
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          sign,
                                          const Spacer(),
                                          chevron,
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      titleAndStatus,
                                    ],
                                  )
                                : Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      sign,
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                              minHeight: signSide),
                                          child: titleAndStatus,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      SizedBox(
                                        height: signSide,
                                        child: Center(child: chevron),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: isExpanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(
                        _leftInset + _markerWidth + _markerGap,
                        0,
                        0,
                        12,
                      ),
                      child: Column(
                        children: [
                          for (final lesson in chapter.lessons)
                            LessonStationTile(
                              lesson: lesson,
                              isRecommended: isRecommended &&
                                  lesson.id == recommendedLessonId,
                            ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ],
    );
  }
}

class _StationSign extends StatelessWidget {
  const _StationSign({
    required this.level,
    required this.number,
    required this.side,
  });

  final String level;
  final String number;
  final double side;

  static TextStyle _levelStyle(ThemeData theme) =>
      theme.textTheme.labelSmall!.copyWith(
        color: theme.colorScheme.onSurface,
        fontSize: 11,
        height: 1,
        fontWeight: FontWeight.w800,
      );

  static TextStyle _numberStyle(ThemeData theme) =>
      theme.textTheme.titleMedium!.copyWith(
        fontSize: 24,
        height: 1,
        fontWeight: FontWeight.w900,
      );

  static double measureSide(
    BuildContext context, {
    required String level,
    required String number,
  }) {
    final theme = Theme.of(context);
    Size measure(String value, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: value, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
      )..layout();
      final size = painter.size;
      painter.dispose();
      return size;
    }

    final levelSize = measure(level, _levelStyle(theme));
    final numberSize = measure(number, _numberStyle(theme));
    // Include padding and border on both axes, then grow the square to fit.
    return math.max(
      56,
      math.max(
        math.max(levelSize.width, numberSize.width) + 20,
        levelSize.height + numberSize.height + 16,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: ValueKey('station-sign-$level-$number'),
      width: side,
      height: side,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border.all(color: StudyMapColors.route, width: 4),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            level,
            style: _levelStyle(theme),
          ),
          Text(
            number,
            style: _numberStyle(theme),
          ),
        ],
      ),
    );
  }
}

class _StationNode extends StatelessWidget {
  const _StationNode({
    required this.state,
    required this.background,
    required this.color,
    required this.borderColor,
  });

  final _StationState state;
  final Color background;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (state == _StationState.resume || state == _StationState.recommended) {
      return Center(
        key: const ValueKey('station-train'),
        child: SizedBox(
          width: 40,
          height: 50,
          child: CustomPaint(
            key: ValueKey('station-node-${state.name}'),
            painter: _StationTrainPainter(
              background: background,
              body: StudyMapColors.route,
              detail: StudyMapColors.trainDetail(theme.brightness),
              light: StudyMapColors.trainLight(theme.brightness),
            ),
          ),
        ),
      );
    }
    return Center(
      child: Container(
        key: ValueKey('station-node-${state.name}'),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 4),
        ),
        child: switch (state) {
          _StationState.complete =>
            Icon(LucideIcons.check, size: 18, color: color),
          _StationState.resume || _StationState.recommended => null,
          _StationState.learning =>
            Center(child: Icon(Icons.circle, size: 8, color: color)),
          _StationState.idle => null,
        },
      ),
    );
  }
}

/// A standalone train marks the recommended station, before or during study.
class _StationTrainPainter extends CustomPainter {
  const _StationTrainPainter({
    required this.background,
    required this.body,
    required this.detail,
    required this.light,
  });

  final Color background;
  final Color body;
  final Color detail;
  final Color light;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 32, size.height / 40);
    // Mask the route behind the entire silhouette, including its windows and
    // wheels, so the train reads independently from the line.
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 32, 40),
      Paint()..color = background,
    );
    final trackPaint = Paint()
      ..color = body
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(11, 30), const Offset(6, 38), trackPaint);
    canvas.drawLine(const Offset(21, 30), const Offset(26, 38), trackPaint);
    canvas.drawLine(const Offset(9, 35), const Offset(23, 35), trackPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(2, 1, 28, 31),
        const Radius.circular(7),
      ),
      Paint()..color = body,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(6, 7, 20, 12),
        const Radius.circular(3),
      ),
      Paint()..color = detail,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(12, 3, 8, 2),
        const Radius.circular(1),
      ),
      Paint()..color = light,
    );
    canvas.drawRect(
      const Rect.fromLTWH(2, 21, 28, 2),
      Paint()..color = light,
    );
    canvas.drawCircle(const Offset(8, 27), 2, Paint()..color = light);
    canvas.drawCircle(const Offset(24, 27), 2, Paint()..color = light);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StationTrainPainter oldDelegate) =>
      background != oldDelegate.background ||
      body != oldDelegate.body ||
      detail != oldDelegate.detail ||
      light != oldDelegate.light;
}
