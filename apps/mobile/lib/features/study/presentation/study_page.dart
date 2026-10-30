import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/providers/user_preferences_provider.dart';
import '../../../shared/widgets/app_sheet_handle.dart';
import '../../home/data/models/dashboard_model.dart';
import '../../home/providers/home_provider.dart';
import '../../my/providers/settings_sync_provider.dart';
import '../data/models/review_summary_model.dart';
import '../domain/lesson_recommendation.dart';
import '../providers/lesson_pilot_telemetry_provider.dart';
import '../providers/study_provider.dart';
import '../providers/study_map_config.dart';
import 'quiz_launch.dart';
import 'study_map_colors.dart';
import 'widgets/lesson_chapter_list.dart';
import 'widgets/lesson_level_empty_state.dart';
import 'widgets/study_kana_section.dart';
import 'widgets/saved_lesson_section.dart';

/// Represents a study category tab.
enum StudyCategory {
  vocabulary('단어', 'VOCABULARY'),
  grammar('문법', 'GRAMMAR'),
  sentenceArrange('문장배열', 'SENTENCE'),
  kana('가나', 'KANA');

  final String label;
  final String apiType;
  const StudyCategory(this.label, this.apiType);
}

class StudyPage extends ConsumerStatefulWidget {
  const StudyPage({super.key});

  @override
  ConsumerState<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends ConsumerState<StudyPage> {
  final _trackedLessonListViews = <String>{};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mapEnabled = ref.watch(studyMapEnabledProvider);
    final preferences = ref.watch(userPreferencesProvider);

    final jlptLevel = preferences.jlptLevel;
    final showKana = preferences.showKana;

    // Watch review summary
    final reviewAsync = ref.watch(reviewSummaryProvider(jlptLevel));

    // Watch chapters for inline lesson list
    final chaptersAsync = ref.watch(chaptersProvider(jlptLevel));
    final recommendedLesson = chaptersAsync.hasValue
        ? findRecommendedLesson(chaptersAsync.value!.chapters)
        : null;
    final chapterList = chaptersAsync.hasValue ? chaptersAsync.value! : null;
    if (chapterList != null) {
      _trackLessonListViewedOnce(
        jlptLevel: jlptLevel,
        source: 'study_home',
        chapterCount: chapterList.chapters.length,
        lessonCount: chapterList.chapters.fold<int>(
          0,
          (total, chapter) => total + chapter.lessons.length,
        ),
        recommendedLessonId: recommendedLesson?.lesson.id,
      );
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: mapEnabled
              ? StudyMapColors.marker(theme.brightness)
              : theme.colorScheme.primary,
          onRefresh: () async {
            ref.invalidate(dashboardProvider);
            ref.invalidate(reviewSummaryProvider(jlptLevel));
            ref.invalidate(chaptersProvider(jlptLevel));
          },
          child: CustomScrollView(
            slivers: [
              // 1. App Bar area
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '학습',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      _JlptLevelChip(
                        level: jlptLevel,
                        mapEnabled: mapEnabled,
                        onChanged: (newLevel) async {
                          await ref
                              .read(settingsSyncServiceProvider)
                              .updateJlptLevel(newLevel);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // 2. SRS Review Card (hidden when no due items for existing users)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: reviewAsync.when(
                    data: (summary) {
                      final hasEverStudied =
                          summary.wordNew > 0 || summary.grammarNew > 0;
                      if (summary.totalDue > 0) {
                        return _ReviewDueCard(
                          summary: summary,
                          mapEnabled: mapEnabled,
                          jlptLevel: jlptLevel,
                          onReviewCtaClicked: () {
                            ref
                                .read(lessonPilotTelemetryProvider)
                                .trackReviewCtaClicked(
                                  jlptLevel: jlptLevel,
                                  totalDue: summary.totalDue,
                                  wordDue: summary.wordDue,
                                  grammarDue: summary.grammarDue,
                                  quizType: summary.grammarDue > summary.wordDue
                                      ? 'GRAMMAR'
                                      : 'VOCABULARY',
                                );
                          },
                        );
                      }
                      if (!hasEverStudied && recommendedLesson != null) {
                        return _ReviewIdleBar(
                          firstLessonId: recommendedLesson.lesson.id,
                          mapEnabled: mapEnabled,
                        );
                      }
                      return const SizedBox.shrink();
                    },
                    loading: () => Container(
                      height: 72,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      ),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // 3. Lesson Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Builder(builder: (context) {
                    final heading = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.bookOpen,
                            size: 20,
                            color: mapEnabled
                                ? StudyMapColors.icon(theme.brightness)
                                : theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          mapEnabled ? '학습 노선' : '체계적 학습',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    );
                    final allLessons = TextButton(
                      onPressed: () => context.push('/study/lessons'),
                      style: mapEnabled
                          ? TextButton.styleFrom(
                              foregroundColor:
                                  StudyMapColors.accent(theme.brightness),
                            )
                          : null,
                      child: const Text('전체 보기'),
                    );
                    return mapEnabled
                        ? SizedBox(
                            width: double.infinity,
                            child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 12,
                              children: [heading, allLessons],
                            ),
                          )
                        : Row(children: [heading, const Spacer(), allLessons]);
                  }),
                ),
              ),

              if (chapterList != null)
                SliverToBoxAdapter(
                  child: SavedLessonSection(
                      jlptLevel: jlptLevel,
                      recommendedLesson: recommendedLesson,
                      compact: true),
                ),

              // Inline chapter cards
              SliverToBoxAdapter(
                child: chaptersAsync.when(
                  data: (data) => data.chapters.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                          child: LessonLevelEmptyState(
                            jlptLevel: jlptLevel,
                            compact: true,
                            onSwitchToN5: jlptLevel == 'N5'
                                ? null
                                : () => ref
                                    .read(settingsSyncServiceProvider)
                                    .updateJlptLevel('N5'),
                          ),
                        )
                      : LessonChapterList(
                          chapters: data.chapters,
                          recommendedLessonId: recommendedLesson?.lesson.id,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                  loading: () => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: List.generate(
                        2,
                        (i) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHigh,
                              borderRadius:
                                  BorderRadius.circular(AppSizes.radiusMd),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  error: (_, __) => Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    child: Text(
                      '레슨을 불러올 수 없습니다',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // 4. Kana Card (conditional)
              if (showKana)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: StudyKanaSection(
                      dataBuilder: (progress) => _KanaBootcampCard(
                        progress: progress,
                        mapEnabled: mapEnabled,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _trackLessonListViewedOnce({
    required String jlptLevel,
    required String source,
    required int chapterCount,
    required int lessonCount,
    String? recommendedLessonId,
  }) {
    final key = [
      source,
      jlptLevel,
      chapterCount,
      lessonCount,
      recommendedLessonId,
    ].join(':');
    if (!_trackedLessonListViews.add(key)) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(lessonPilotTelemetryProvider).trackLessonListViewed(
            jlptLevel: jlptLevel,
            source: source,
            chapterCount: chapterCount,
            lessonCount: lessonCount,
            recommendedLessonId: recommendedLessonId,
          );
    });
  }
}

// ── SRS Review Card (due items) ──

class _ReviewDueCard extends StatelessWidget {
  final String jlptLevel;
  final ReviewSummaryModel summary;
  final bool mapEnabled;
  final VoidCallback onReviewCtaClicked;

  const _ReviewDueCard({
    required this.summary,
    required this.mapEnabled,
    required this.jlptLevel,
    required this.onReviewCtaClicked,
  });

  // Pick review category: prefer the one with more due items
  String get _reviewQuizType =>
      summary.grammarDue > summary.wordDue ? 'GRAMMAR' : 'VOCABULARY';

  void _openReview(BuildContext context) {
    onReviewCtaClicked();
    openReviewQuiz(
      context,
      quizType: _reviewQuizType,
      jlptLevel: jlptLevel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (mapEnabled) return _buildMapCard(context, theme);

    final subtext = mapEnabled && theme.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;
    final accent = mapEnabled
        ? StudyMapColors.accent(theme.brightness)
        : AppColors.primaryStrong;
    final isLight = theme.brightness == Brightness.light;
    final cardColor =
        isLight ? AppColors.cardWarm : theme.colorScheme.surfaceContainerLow;
    final borderColor =
        isLight ? AppColors.lightBorder : theme.colorScheme.outline;

    final dueBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: mapEnabled
            ? StudyMapColors.panel(theme.brightness)
            : AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '복습 ${summary.totalDue}개',
        style: theme.textTheme.labelMedium?.copyWith(
          color: mapEnabled
              ? StudyMapColors.accent(theme.brightness)
              : AppColors.primaryStrong,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    final reviewActions = <Widget>[
      _ReviewCountPill(
          label: '단어', count: summary.wordDue, mapEnabled: mapEnabled),
      if (!mapEnabled) const SizedBox(width: 8),
      _ReviewCountPill(
          label: '문법', count: summary.grammarDue, mapEnabled: mapEnabled),
      if (!mapEnabled) const Spacer(),
      FilledButton(
        onPressed: () => _openReview(context),
        style: FilledButton.styleFrom(
          backgroundColor: mapEnabled
              ? StudyMapColors.button(theme.brightness)
              : AppColors.primaryStrong,
          foregroundColor:
              mapEnabled ? StudyMapColors.onButton(theme.brightness) : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        child: const Text('복습하고 시작하기'),
      ),
    ];

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        onTap: () => _openReview(context),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            boxShadow: isLight
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: mapEnabled
                          ? StudyMapColors.panel(theme.brightness)
                          : AppColors.sakuraContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        LucideIcons.rotateCcw,
                        size: 22,
                        color: mapEnabled
                            ? StudyMapColors.icon(theme.brightness)
                            : AppColors.sakuraOn,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '오늘의 학습 루틴',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '복습하고 시작해요',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '어제 배운 단어와 문법을 먼저 확인해요',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: subtext,
                          ),
                        ),
                        if (mapEnabled) ...[
                          const SizedBox(height: 8),
                          dueBadge,
                        ],
                      ],
                    ),
                  ),
                  if (!mapEnabled) ...[
                    const SizedBox(width: 12),
                    dueBadge,
                  ],
                ],
              ),
              const SizedBox(height: 14),
              if (mapEnabled)
                Wrap(spacing: 8, runSpacing: 8, children: reviewActions)
              else
                Row(children: reviewActions),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapCard(BuildContext context, ThemeData theme) {
    final isLight = theme.brightness == Brightness.light;
    final subtext = isLight ? AppColors.lightSubtext : AppColors.darkSubtext;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isLight ? AppColors.cardWarm : AppColors.darkCard,
        border: Border.all(
          color: isLight ? AppColors.lightBorder : AppColors.darkBorder,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.rotateCcw,
                size: 20,
                color: StudyMapColors.icon(theme.brightness),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '오늘의 복습',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: subtext,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '복습할 표현 ${summary.totalDue}개',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '단어 ${summary.wordDue}개 · 문법 ${summary.grammarDue}개',
            style: theme.textTheme.bodyMedium?.copyWith(color: subtext),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _openReview(context),
              style: FilledButton.styleFrom(
                backgroundColor: StudyMapColors.button(theme.brightness),
                foregroundColor: StudyMapColors.onButton(theme.brightness),
                minimumSize: const Size.fromHeight(48),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                textStyle: theme.textTheme.labelLarge?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: Text('복습 시작하기', textAlign: TextAlign.center),
                  ),
                  SizedBox(width: 8),
                  Icon(LucideIcons.arrowRight, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCountPill extends StatelessWidget {
  final String label;
  final int count;
  final bool mapEnabled;

  const _ReviewCountPill({
    required this.label,
    required this.count,
    required this.mapEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtext = mapEnabled && theme.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $count',
        style: theme.textTheme.labelMedium?.copyWith(
          color: subtext,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── SRS Review Complete Bar ──

class _ReviewIdleBar extends StatelessWidget {
  final String? firstLessonId;

  final bool mapEnabled;

  const _ReviewIdleBar({this.firstLessonId, required this.mapEnabled});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = mapEnabled
        ? StudyMapColors.accent(theme.brightness)
        : AppColors.primaryStrong;
    final isLight = theme.brightness == Brightness.light;
    final cardColor =
        isLight ? AppColors.cardWarm : theme.colorScheme.surfaceContainerLow;
    final borderColor =
        isLight ? AppColors.lightBorder : theme.colorScheme.outline;

    return GestureDetector(
      onTap: firstLessonId != null
          ? () => context.push('/study/lessons/$firstLessonId')
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.sparkles, size: 20, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '첫 레슨을 시작해보세요',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: mapEnabled
                      ? theme.colorScheme.onSurface
                      : AppColors.neutralOn,
                ),
              ),
            ),
            if (firstLessonId != null)
              Icon(LucideIcons.arrowRight, size: 18, color: accent),
          ],
        ),
      ),
    );
  }
}

// ── Kana Bootcamp Card ──

class _KanaBootcampCard extends StatelessWidget {
  final KanaProgressData progress;

  final bool mapEnabled;

  const _KanaBootcampCard({required this.progress, required this.mapEnabled});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtext = mapEnabled && theme.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;
    final accent = mapEnabled
        ? StudyMapColors.accent(theme.brightness)
        : AppColors.primaryStrong;
    final isLight = theme.brightness == Brightness.light;
    final cardColor =
        isLight ? AppColors.cardWarm : theme.colorScheme.surfaceContainerLow;
    final borderColor =
        isLight ? AppColors.lightBorder : theme.colorScheme.outline;
    final learned = progress.hiragana.learned + progress.katakana.learned;
    final total = progress.hiragana.total + progress.katakana.total;
    final fraction = learned / total;

    final kanaButton = OutlinedButton(
      onPressed: () => context.push('/study/kana'),
      style: OutlinedButton.styleFrom(
        foregroundColor: accent,
        side: BorderSide(color: accent),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      child: const Text('계속하기'),
    );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        onTap: () => context.push('/study/kana'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: mapEnabled
                      ? StudyMapColors.panel(theme.brightness)
                      : AppColors.sakuraContainer,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    'あ',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: mapEnabled ? accent : AppColors.sakuraOn,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '가나 부트캠프',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '매일 5분이면 46자 금방 익혀요',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: subtext,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(AppSizes.progressRadius),
                            child: LinearProgressIndicator(
                              value: fraction,
                              minHeight: AppSizes.progressHeight,
                              backgroundColor: mapEnabled
                                  ? StudyMapColors.track(theme.brightness)
                                  : AppColors.sakuraTrack,
                              color: mapEnabled
                                  ? StudyMapColors.marker(theme.brightness)
                                  : AppColors.sakura,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$learned/$total',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: subtext,
                          ),
                        ),
                      ],
                    ),
                    if (mapEnabled) ...[
                      const SizedBox(height: 10),
                      kanaButton,
                    ],
                  ],
                ),
              ),
              if (!mapEnabled) const SizedBox(width: 8),
              if (!mapEnabled) kanaButton,
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact inline chip showing current JLPT level with dropdown.
class _JlptLevelChip extends StatelessWidget {
  final String level;
  final ValueChanged<String> onChanged;
  final bool mapEnabled;

  static const _levels = ['N5', 'N4', 'N3', 'N2', 'N1'];

  const _JlptLevelChip({
    required this.level,
    required this.onChanged,
    required this.mapEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = mapEnabled
        ? StudyMapColors.accent(theme.brightness)
        : AppColors.primaryStrong;

    return GestureDetector(
      onTap: () => _showLevelPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: mapEnabled
              ? StudyMapColors.panel(theme.brightness)
              : AppColors.sakuraTrack,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: mapEnabled
                ? StudyMapColors.track(theme.brightness)
                : AppColors.sakura.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              level,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: mapEnabled ? accent : AppColors.sakura,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              LucideIcons.chevronDown,
              size: 16,
              color: mapEnabled ? accent : theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  void _showLevelPicker(BuildContext context) {
    final theme = Theme.of(context);
    final accent = mapEnabled
        ? StudyMapColors.accent(theme.brightness)
        : theme.colorScheme.primary;

    showModalBottomSheet(
      context: context,
      shape: AppSizes.sheetShape,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSheetHandle(),
                const SizedBox(height: 16),
                Text(
                  'JLPT 레벨 선택',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ..._levels.map((l) {
                  final isSelected = l == level;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: isSelected
                          ? mapEnabled
                              ? StudyMapColors.panel(theme.brightness)
                              : theme.colorScheme.primary
                                  .withValues(alpha: 0.08)
                          : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.pop(ctx);
                          if (l != level) onChanged(l);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected
                                  ? accent
                                  : theme.colorScheme.outline,
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Text(
                                l,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? accent : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _levelDescription(l),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  LucideIcons.check,
                                  size: 20,
                                  color: accent,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  String _levelDescription(String l) {
    switch (l) {
      case 'N5':
        return '입문 · 기초 인사, 숫자, 간단한 문장';
      case 'N4':
        return '초급 · 일상회화, 기본 문법';
      case 'N3':
        return '중급 · 일상적 문맥 이해';
      case 'N2':
        return '중상급 · 신문, 뉴스 이해';
      case 'N1':
        return '고급 · 원어민 수준 이해';
      default:
        return '';
    }
  }
}
