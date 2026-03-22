import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../../../shared/widgets/app_sheet_handle.dart';
import '../../home/data/models/dashboard_model.dart';
import '../../home/providers/home_provider.dart';
import '../data/models/review_summary_model.dart';
import '../providers/study_provider.dart';
import 'quiz_page.dart';
import 'widgets/lesson_chapter_list.dart';
import 'widgets/study_skeleton.dart';

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
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dashboardAsync = ref.watch(dashboardProvider);
    final profileAsync = ref.watch(profileProvider);

    final dashboard = dashboardAsync.hasValue ? dashboardAsync.value : null;
    final profile = profileAsync.hasValue ? profileAsync.value : null;

    final jlptLevel = profile != null ? profile.jlptLevel : 'N5';

    final isLoading = dashboardAsync.isLoading && !dashboardAsync.hasValue;
    if (isLoading) {
      return const Scaffold(body: SafeArea(child: StudySkeleton()));
    }

    // Kana visibility
    final showKana = dashboard?.showKana ?? false;
    final kanaCompleted = dashboard?.kanaProgress?.completed ?? false;
    final showKanaCard = showKana && !kanaCompleted;

    // Watch review summary
    final reviewAsync = ref.watch(reviewSummaryProvider(jlptLevel));

    // Watch chapters for inline lesson list
    final chaptersAsync = ref.watch(chaptersProvider(jlptLevel));

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: theme.colorScheme.primary,
          onRefresh: () async {
            ref.invalidate(dashboardProvider);
            ref.invalidate(profileProvider);
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
                        onChanged: (newLevel) async {
                          await ref
                              .read(homeRepositoryProvider)
                              .updateJlptLevel(newLevel);
                          ref.invalidate(profileProvider);
                          ref.invalidate(dashboardProvider);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // 2. SRS Review Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: reviewAsync.when(
                    data: (summary) => summary.totalDue > 0
                        ? _ReviewDueCard(summary: summary, jlptLevel: jlptLevel)
                        : _ReviewIdleBar(
                            hasEverStudied:
                                summary.wordNew > 0 || summary.grammarNew > 0),
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
                  child: Row(
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
                      const Spacer(),
                      TextButton(
                        onPressed: () => context.push('/study/lessons'),
                        child: const Text('전체 보기'),
                      ),
                    ],
                  ),
                ),
              ),

              // Inline chapter cards
              SliverToBoxAdapter(
                child: chaptersAsync.when(
                  data: (data) => data.chapters.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          child: Text(
                            '준비 중인 콘텐츠입니다',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        )
                      : LessonChapterList(
                          chapters: data.chapters,
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
              if (showKanaCard)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _KanaBootcampCard(dashboard: dashboard!),
                  ),
                ),

              if (showKanaCard)
                // Bottom padding
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── SRS Review Card (due items) ──

class _ReviewDueCard extends StatelessWidget {
  final String jlptLevel;
  final ReviewSummaryModel summary;

  const _ReviewDueCard({required this.summary, required this.jlptLevel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        onTap: () => Navigator.of(context, rootNavigator: true).push(
          quizRoute(QuizPage(
              quizType: 'VOCABULARY', jlptLevel: jlptLevel, mode: 'review')),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryStrong.withValues(alpha: 0.16),
                AppColors.primary.withValues(alpha: 0.10),
              ],
            ),
            border: Border.all(
              color: AppColors.primaryStrong.withValues(alpha: 0.40),
            ),
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryStrong.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    LucideIcons.rotateCcw,
                    size: 22,
                    color: AppColors.primaryStrong,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '복습 대기 ${summary.totalDue}개',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '단어 ${summary.wordDue} · 문법 ${summary.grammarDue}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.lightSubtext,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).push(
                  quizRoute(QuizPage(
                      quizType: 'VOCABULARY',
                      jlptLevel: jlptLevel,
                      mode: 'review')),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryStrong,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                child: const Text('복습 시작'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── SRS Review Complete Bar ──

class _ReviewIdleBar extends StatelessWidget {
  final bool hasEverStudied;

  const _ReviewIdleBar({required this.hasEverStudied});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final message = hasEverStudied ? '오늘 복습 완료' : '첫 레슨을 시작해보세요';
    final iconData =
        hasEverStudied ? LucideIcons.checkCircle2 : LucideIcons.sparkles;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: [
          Icon(iconData, size: 20, color: AppColors.primaryStrong),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.primaryStrong,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Kana Bootcamp Card ──

class _KanaBootcampCard extends StatelessWidget {
  final DashboardModel dashboard;

  const _KanaBootcampCard({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kana = dashboard.kanaProgress;
    final learned =
        (kana?.hiragana.learned ?? 0) + (kana?.katakana.learned ?? 0);
    final total = (kana?.hiragana.total ?? 0) + (kana?.katakana.total ?? 0);
    final progress = total > 0 ? learned / total : 0.0;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        onTap: () => context.push('/study/kana'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.07),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.22),
            ),
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    'あ',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryStrong,
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
                        color: AppColors.lightSubtext,
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
                              value: progress,
                              minHeight: AppSizes.progressHeight,
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.12),
                              color: AppColors.primaryStrong,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$learned/$total',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.lightSubtext,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => context.push('/study/kana'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryStrong,
                  side: const BorderSide(color: AppColors.primaryStrong),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                child: const Text('계속하기'),
              ),
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

  static const _levels = ['N5', 'N4', 'N3', 'N2', 'N1'];

  const _JlptLevelChip({required this.level, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => _showLevelPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              level,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              LucideIcons.chevronDown,
              size: 16,
              color: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  void _showLevelPicker(BuildContext context) {
    final theme = Theme.of(context);

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
                          ? theme.colorScheme.primary.withValues(alpha: 0.08)
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
                                  ? theme.colorScheme.primary
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
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : null,
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
                                  color: theme.colorScheme.primary,
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
