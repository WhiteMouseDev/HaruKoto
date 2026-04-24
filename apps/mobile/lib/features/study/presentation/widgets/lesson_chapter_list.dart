import 'package:flutter/material.dart';

import '../../data/models/lesson_models.dart';
import 'lesson_chapter_card.dart';

export 'lesson_chapter_card.dart';
export 'lesson_tile.dart';

/// Reusable chapter list widget used both inline in StudyPage
/// and in the standalone LessonListPage.
class LessonChapterList extends StatefulWidget {
  final List<ChapterModel> chapters;
  final EdgeInsetsGeometry padding;
  final String? recommendedLessonId;

  const LessonChapterList({
    super.key,
    required this.chapters,
    this.padding = const EdgeInsets.all(16),
    this.recommendedLessonId,
  });

  @override
  State<LessonChapterList> createState() => _LessonChapterListState();
}

class _LessonChapterListState extends State<LessonChapterList> {
  String? _expandedChapterId;

  @override
  void initState() {
    super.initState();
    _expandedChapterId = _findDefaultExpanded();
  }

  @override
  void didUpdateWidget(covariant LessonChapterList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chapters != widget.chapters) {
      _expandedChapterId = _findDefaultExpanded();
    }
  }

  /// Find the chapter to expand by default:
  /// 1. First chapter with IN_PROGRESS lessons
  /// 2. First chapter that's not fully complete
  /// 3. First chapter
  String? _findDefaultExpanded() {
    // 1. In-progress chapter
    for (final ch in widget.chapters) {
      if (ch.lessons.any((l) => l.status == 'IN_PROGRESS')) return ch.id;
    }
    // 2. First incomplete chapter
    for (final ch in widget.chapters) {
      if (ch.completedLessons < ch.totalLessons) return ch.id;
    }
    // 3. First chapter
    return widget.chapters.isNotEmpty ? widget.chapters.first.id : null;
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: widget.padding,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.chapters.length,
      itemBuilder: (context, index) {
        final chapter = widget.chapters[index];
        return ChapterCard(
          chapter: chapter,
          recommendedLessonId: widget.recommendedLessonId,
          isExpanded: _expandedChapterId == chapter.id,
          onToggle: () {
            setState(() {
              _expandedChapterId =
                  _expandedChapterId == chapter.id ? null : chapter.id;
            });
          },
        );
      },
    );
  }
}
