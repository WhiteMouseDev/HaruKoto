import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/auth/current_account_provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/providers/user_preferences_provider.dart';
import '../../../core/theme/text_theme.dart';
import '../../../shared/widgets/app_sheet_handle.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../home/data/models/dashboard_model.dart';
import '../../home/providers/home_provider.dart';
import '../../my/providers/settings_sync_provider.dart';
import '../data/models/lesson_models.dart';
import '../domain/lesson_recommendation.dart';
import '../providers/lesson_pilot_telemetry_provider.dart';
import '../providers/study_provider.dart';
import '../providers/study_map_config.dart';
import 'study_map_colors.dart';
import 'widgets/lesson_chapter_list.dart';
import 'widgets/lesson_level_empty_state.dart';
import 'widgets/lesson_read_status.dart';
import 'widgets/lesson_station_list.dart';
import 'widgets/study_kana_section.dart';
import 'widgets/study_review_section.dart';
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
    final owner = ref.watch(currentAccountIdProvider);
    final accountCurrent = _isCurrent(owner);

    final jlptLevel = preferences.jlptLevel;
    final showKana = preferences.showKana;

    // Watch chapters for inline lesson list
    final chaptersAsync = ref.watch(chaptersProvider(jlptLevel));
    final chaptersLoading = !accountCurrent || chaptersAsync.isLoading;
    // Refreshes retain old data/errors. Display only the current successful
    // read so a pending/error state cannot expose a stale lesson action.
    final chapterList = !chaptersLoading && !chaptersAsync.hasError
        ? chaptersAsync.value
        : null;
    final recommendedLesson = chapterList == null
        ? null
        : findRecommendedLesson(chapterList.chapters);
    final savedLessons = chapterList == null
        ? null
        : SliverToBoxAdapter(
            child: SavedLessonSection(
              jlptLevel: jlptLevel,
              recommendedLesson: recommendedLesson,
              compact: true,
              redesigned: mapEnabled,
            ),
          );
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
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            '학습',
                            style: mapEnabled
                                ? TextStyle(
                                    fontFamily: redesignFontFamily,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                    letterSpacing: -0.5,
                                    color: theme.brightness == Brightness.light
                                        ? AppColors.redesignForeground
                                        : theme.colorScheme.onSurface,
                                  )
                                : theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                          ),
                        ),
                      ),
                      _JlptLevelChip(
                        level: jlptLevel,
                        mapEnabled: mapEnabled,
                        onChanged: (newLevel) async {
                          if (!_isCurrent(owner) ||
                              ref.read(userPreferencesProvider).jlptLevel !=
                                  jlptLevel) {
                            return;
                          }
                          try {
                            await ref
                                .read(settingsSyncServiceProvider)
                                .updateJlptLevel(newLevel);
                          } catch (_) {
                            if (context.mounted && _isCurrent(owner)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('학습 급수를 변경하지 못했어요. 다시 시도해주세요.'),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // 2. Review reads and retries stay independent of lesson reads.
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: StudyReviewSection(
                    key: ValueKey('review-section-$jlptLevel'),
                    jlptLevel: jlptLevel,
                    mapEnabled: mapEnabled,
                    redesigned: mapEnabled,
                  ),
                ),
              ),

              SliverToBoxAdapter(child: SizedBox(height: mapEnabled ? 40 : 24)),

              if (mapEnabled && savedLessons != null) savedLessons,

              // 3. Lesson Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: mapEnabled
                      ? _StudyRouteHeading(
                          chapters: chapterList,
                          loading: chaptersLoading,
                        )
                      : Row(children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.bookOpen,
                                  size: 20, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                '체계적 학습',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => context.push('/study/lessons'),
                            child: const Text('전체 보기'),
                          ),
                        ]),
                ),
              ),

              if (!mapEnabled && savedLessons != null) savedLessons,

              // Inline chapter cards
              SliverToBoxAdapter(
                child: chaptersLoading
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: mapEnabled
                            ? const LessonStationListSkeleton()
                            : const LessonReadStatus(loading: true),
                      )
                    : chaptersAsync.hasError
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: LessonReadStatus(
                              error: chaptersAsync.error,
                              onRetry: () => _retryLessons(owner, jlptLevel),
                            ),
                          )
                        : chapterList!.chapters.isEmpty
                            ? Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 8, 20, 8),
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
                                chapters: chapterList.chapters,
                                redesigned: mapEnabled,
                                recommendedLessonId:
                                    recommendedLesson?.lesson.id,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
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

  bool _isCurrent(String? owner) =>
      mounted &&
      owner != null &&
      ref.read(currentAccountIdProvider) == owner &&
      ref.read(currentAccountReaderProvider)() == owner;

  void _retryLessons(String? owner, String level) {
    if (!_isCurrent(owner) ||
        ref.read(userPreferencesProvider).jlptLevel != level ||
        ref.read(chaptersProvider(level)).isLoading) {
      return;
    }
    ref.invalidate(chaptersProvider(level));
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

// ── Kana Bootcamp Card ──

class _StudyRouteHeading extends StatelessWidget {
  const _StudyRouteHeading({required this.chapters, required this.loading});

  final ChapterListModel? chapters;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final stations = chapters?.chapters ?? const <ChapterModel>[];
    final completed = stations.where((chapter) => chapter.isComplete).length;

    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          Semantics(
            header: true,
            child: Text('학습 노선',
                style: TextStyle(
                  fontFamily: redesignFontFamily,
                  fontSize: 16,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: light
                      ? AppColors.redesignForeground
                      : theme.colorScheme.onSurface,
                )),
          ),
          if (loading)
            AppSkeletonBlock(
              width: 88,
              height: MediaQuery.textScalerOf(context).scale(12) * 1.4 + 12,
              radius: AppSizes.radiusFull,
            )
          else if (stations.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: light
                    ? AppColors.redesignSurface
                    : theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              ),
              child: Text('$completed/${stations.length}개역 완료',
                  semanticsLabel: '${stations.length}개 역 중 $completed개 완료',
                  style: TextStyle(
                    fontFamily: redesignFontFamily,
                    fontSize: 12,
                    height: 1.4,
                    color: light
                        ? AppColors.redesignMutedForeground
                        : theme.colorScheme.onSurfaceVariant,
                  )),
            ),
        ],
      ),
    );
  }
}

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
  final Future<void> Function(String) onChanged;
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
    final light = theme.brightness == Brightness.light;
    final title = level == 'ABSOLUTE_ZERO' ? '첫걸음' : level;
    final foreground =
        light ? AppColors.redesignForeground : theme.colorScheme.onSurface;
    final chevron =
        light ? const Color(0xFF545461) : theme.colorScheme.onSurfaceVariant;

    void openLevelPicker() => _showLevelPicker(context);

    return Semantics(
      button: true,
      label: '학습 급수 $title, 변경',
      onTap: openLevelPicker,
      excludeSemantics: true,
      child: OutlinedButton(
        onPressed: openLevelPicker,
        style: OutlinedButton.styleFrom(
          backgroundColor:
              mapEnabled ? theme.colorScheme.surface : AppColors.sakuraTrack,
          foregroundColor: mapEnabled ? foreground : AppColors.primaryStrong,
          side: BorderSide(
            color: mapEnabled
                ? (light
                    ? AppColors.redesignOutline
                    : theme.colorScheme.outline)
                : AppColors.sakura.withValues(alpha: 0.35),
          ),
          shape: const StadiumBorder(),
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          tapTargetSize: MaterialTapTargetSize.padded,
          textStyle: const TextStyle(
            fontFamily: redesignFontFamily,
            fontSize: 14,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title),
            const SizedBox(width: 4),
            Icon(
              LucideIcons.chevronDown,
              size: 14,
              color: mapEnabled ? chevron : theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLevelPicker(BuildContext context) async {
    final theme = Theme.of(context);
    final accent = mapEnabled
        ? StudyMapColors.accent(theme.brightness)
        : theme.colorScheme.primary;

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: AppSizes.sheetShape,
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
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
                        onTap: () => Navigator.pop(ctx, l),
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
    if (context.mounted && selected != null && selected != level) {
      await onChanged(selected);
    }
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
