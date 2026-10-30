import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/study_clock_provider.dart';
import '../../features/home/providers/study_activity_refresh_provider.dart';
import '../../features/study/providers/quiz_progress_refresh_provider.dart';
import 'bottom_nav.dart';
import 'offline_banner.dart';

class MainShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _refreshActivity() {
    ref.read(quizProgressRefreshProvider).refresh();
    ref.read(studyDateProvider.notifier).refresh();
    ref.read(studyActivityRefreshProvider).refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshActivity();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(studyDateProvider);
    final navigationShell = widget.navigationShell;
    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: BottomNav(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) {
          if (index == 0) _refreshActivity();
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
      ),
      extendBody: true,
    );
  }
}
