import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../stats/providers/stats_provider.dart';
import 'home_provider.dart';

final studyActivityRefreshProvider = Provider<StudyActivityRefresh>((ref) {
  return StudyActivityRefresh(ref);
});

/// Reload server-owned activity after a successful completion or return home.
class StudyActivityRefresh {
  const StudyActivityRefresh(this._ref);

  final Ref _ref;

  void refresh() {
    if (!_ref.mounted) return;
    _ref.invalidate(dashboardProvider);
    _ref.invalidate(statsHistoryProvider);
    _ref.invalidate(statsMonthHistoryProvider);
    _ref.invalidate(heatmapProvider);
  }
}
