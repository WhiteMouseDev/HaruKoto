import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/sizes.dart';
import '../../study/providers/study_provider.dart';
import '../../study/presentation/widgets/resume_banner.dart';
import '../../study/presentation/widgets/recommend_tab.dart';
import '../../study/presentation/widgets/free_tab.dart';
import '../../study/presentation/quiz_page.dart';

class PracticePage extends ConsumerStatefulWidget {
  const PracticePage({super.key});

  @override
  ConsumerState<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends ConsumerState<PracticePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Free tab state
  String _selectedLevel = 'N5';
  String _selectedType = 'VOCABULARY';
  String _quizMode = 'normal';

  static const _jlptLevels = ['N5', 'N4', 'N3', 'N2', 'N1'];
  static const _quizTypes = [
    ('VOCABULARY', '단어'),
    ('GRAMMAR', '문법'),
  ];

  static const _modeLabels = {
    'normal': '4지선다',
    'review': '복습 모드',
    'wrong': '오답 모드',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _startFreeQuiz() {
    Navigator.of(context, rootNavigator: true).push(
      quizRoute(QuizPage(
        quizType: _selectedType,
        jlptLevel: _selectedLevel,
        count: 10,
        mode: _quizMode != 'normal' ? _quizMode : null,
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final incompleteAsync = ref.watch(incompleteQuizProvider);
    final recsAsync = ref.watch(recommendationsProvider);
    final statsAsync = ref.watch(
      quizStatsProvider((level: _selectedLevel, type: _selectedType)),
    );

    final incompleteSession =
        incompleteAsync.hasValue ? incompleteAsync.value : null;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: theme.colorScheme.primary,
          onRefresh: () async {
            ref.invalidate(incompleteQuizProvider);
            ref.invalidate(recommendationsProvider);
            ref.invalidate(
              quizStatsProvider(
                  (level: _selectedLevel, type: _selectedType)),
            );
          },
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (incompleteSession != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child:
                                ResumeBanner(session: incompleteSession),
                          ),
                        Text(
                          '연습',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Shortcut chips
                        _ShortcutRow(
                          shortcuts: [
                            _Shortcut(
                              icon: LucideIcons.fileX,
                              label: '오답노트',
                              onTap: () =>
                                  context.push('/study/wrong-answers'),
                            ),
                            _Shortcut(
                              icon: LucideIcons.bookOpen,
                              label: '학습한 단어',
                              onTap: () =>
                                  context.push('/study/learned-words'),
                            ),
                            _Shortcut(
                              icon: LucideIcons.bookmark,
                              label: '단어장',
                              onTap: () =>
                                  context.push('/study/wordbook'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                // Tab bar
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabBarDelegate(
                    tabBar: TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(text: '추천'),
                        Tab(text: '자유 연습'),
                      ],
                      isScrollable: false,
                      labelStyle: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: theme.textTheme.bodySmall,
                      labelColor: theme.colorScheme.primary,
                      unselectedLabelColor: theme.colorScheme.onSurface
                          .withValues(alpha: 0.5),
                      indicatorColor: theme.colorScheme.primary,
                      indicatorSize: TabBarIndicatorSize.label,
                      dividerColor: theme.colorScheme.outline
                          .withValues(alpha: 0.3),
                    ),
                    backgroundColor: theme.scaffoldBackgroundColor,
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: 추천
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: RecommendTab(
                    recs: recsAsync,
                    onInvalidate: () =>
                        ref.invalidate(recommendationsProvider),
                  ),
                ),
                // Tab 2: 자유 연습
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: FreeTab(
                    selectedLevel: _selectedLevel,
                    selectedType: _selectedType,
                    quizMode: _quizMode,
                    modeLabel: _modeLabels[_quizMode] ?? '4지선다',
                    jlptLevels: _jlptLevels,
                    quizTypes: _quizTypes,
                    statsAsync: statsAsync,
                    onLevelChanged: (level) =>
                        setState(() => _selectedLevel = level),
                    onTypeChanged: (type) =>
                        setState(() => _selectedType = type),
                    onModeChanged: (mode) =>
                        setState(() => _quizMode = mode),
                    onStartQuiz: _startFreeQuiz,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Row of shortcut chips for quick access.
class _ShortcutRow extends StatelessWidget {
  final List<_Shortcut> shortcuts;

  const _ShortcutRow({required this.shortcuts});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: shortcuts
            .map((s) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _ShortcutChip(shortcut: s),
                ))
            .toList(),
      ),
    );
  }
}

class _Shortcut {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _Shortcut({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class _ShortcutChip extends StatelessWidget {
  final _Shortcut shortcut;

  const _ShortcutChip({required this.shortcut});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        onTap: shortcut.onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                shortcut.icon,
                size: 14,
                color: theme.colorScheme.onSurface
                    .withValues(alpha: 0.6),
              ),
              const SizedBox(width: 6),
              Text(
                shortcut.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface
                      .withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Delegate for pinning the tab bar during scroll.
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  _TabBarDelegate({required this.tabBar, required this.backgroundColor});

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: backgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}
