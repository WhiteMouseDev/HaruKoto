import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/sizes.dart';
import '../../home/providers/home_provider.dart';
import '../../kana/presentation/kana_hub_page.dart';
import 'widgets/study_tab_content.dart';
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

class _StudyPageState extends ConsumerState<StudyPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<StudyCategory> _tabs = [];

  @override
  void initState() {
    super.initState();
    _tabs = [StudyCategory.vocabulary, StudyCategory.grammar, StudyCategory.sentenceArrange];
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Rebuild tab list based on kana state from dashboard.
  void _updateTabs({
    required bool showKana,
    required bool kanaCompleted,
    required bool kanaManuallyReEnabled,
  }) {
    final newTabs = <StudyCategory>[];

    // If showKana is true AND kana not completed -> kana FIRST
    if (showKana && !kanaCompleted && !kanaManuallyReEnabled) {
      newTabs.add(StudyCategory.kana);
    }

    newTabs.addAll([
      StudyCategory.vocabulary,
      StudyCategory.grammar,
      StudyCategory.sentenceArrange,
    ]);

    // If manually re-enabled in settings -> kana LAST
    if (kanaManuallyReEnabled) {
      newTabs.add(StudyCategory.kana);
    }

    if (_tabs.length != newTabs.length ||
        !_listsEqual(_tabs, newTabs)) {
      setState(() {
        final oldIndex = _tabController.index;
        _tabs = newTabs;
        _tabController.dispose();
        _tabController = TabController(
          length: _tabs.length,
          vsync: this,
          initialIndex: oldIndex.clamp(0, _tabs.length - 1),
        );
      });
    }
  }

  bool _listsEqual(List<StudyCategory> a, List<StudyCategory> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dashboardAsync = ref.watch(dashboardProvider);
    final profileAsync = ref.watch(profileProvider);

    // Multi-provider composition: manual AsyncValue handling is used instead
    // of .when() because loading/error states are combined across 2 providers.

    // Determine kana tab visibility from dashboard data
    final dashboard = dashboardAsync.hasValue ? dashboardAsync.value : null;
    final profile = profileAsync.hasValue ? profileAsync.value : null;

    if (dashboard != null && profile != null) {
      final showKana = dashboard.showKana;
      final kanaCompleted = dashboard.kanaProgress?.completed ?? false;
      // "Manually re-enabled" means showKana is true but kana is already completed
      final kanaManuallyReEnabled = showKana && kanaCompleted;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _updateTabs(
            showKana: showKana,
            kanaCompleted: kanaCompleted,
            kanaManuallyReEnabled: kanaManuallyReEnabled,
          );
        }
      });
    }

    final jlptLevel = profile != null ? profile.jlptLevel : 'N5';

    final isLoading = dashboardAsync.isLoading && !dashboardAsync.hasValue;
    if (isLoading) {
      return const Scaffold(body: SafeArea(child: StudySkeleton()));
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: theme.colorScheme.primary,
          onRefresh: () async {
            ref.invalidate(dashboardProvider);
            ref.invalidate(profileProvider);
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
                        Text(
                          'JLPT 학습',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Current JLPT level display (task 1-10)
                        _JlptLevelBadge(
                          level: jlptLevel,
                          onTap: () => context.push('/my'),
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
                      tabs: _tabs.map((t) => Tab(text: t.label)).toList(),
                      isScrollable: false,
                      labelStyle: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: theme.textTheme.bodySmall,
                      labelColor: theme.colorScheme.primary,
                      unselectedLabelColor:
                          theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      indicatorColor: theme.colorScheme.primary,
                      indicatorSize: TabBarIndicatorSize.label,
                      dividerColor: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                    backgroundColor: theme.scaffoldBackgroundColor,
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: _tabs.map((tab) {
                if (tab == StudyCategory.kana) {
                  return const KanaHubPage();
                }
                return StudyTabContent(
                  category: tab,
                  jlptLevel: jlptLevel,
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows the current JLPT level with a tap-to-change action.
class _JlptLevelBadge extends StatelessWidget {
  final String level;
  final VoidCallback onTap;

  const _JlptLevelBadge({required this.level, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.graduationCap,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              '현재 레벨: $level',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '(변경 →)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ],
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
