import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/current_account_provider.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers/dio_provider.dart';
import '../../../core/providers/study_clock_provider.dart';
import '../../../core/providers/user_preferences_provider.dart';
import '../data/home_repository.dart';
import '../data/models/dashboard_model.dart';
import '../data/models/mission_model.dart';
import '../data/models/user_profile_model.dart';

final homeRepositoryProvider = Provider((ref) {
  return HomeRepository(ref.watch(dioProvider));
});

final dashboardProvider =
    FutureProvider.autoDispose<DashboardModel>((ref) async {
  ref.watch(currentAccountIdProvider);
  ref.watch(studyDateProvider);
  return await ref.watch(homeRepositoryProvider).fetchDashboard();
});

final profileProvider = FutureProvider.autoDispose<UserProfileModel>((ref) {
  ref.watch(currentAccountIdProvider);
  final preferences = ref.read(userPreferencesProvider.notifier);
  final scope = preferences.requestScope;
  return ref.watch(homeRepositoryProvider).fetchProfile().then((profile) async {
    if (!ref.mounted ||
        !preferences.isCurrent(scope) ||
        (profile.userId != null && profile.userId != scope.owner)) {
      throw const ApiException(message: '계정이나 목표가 변경되어 프로필을 다시 확인해주세요.');
    }
    await preferences.syncFromServer(
      scope: scope,
      showFurigana: profile.showFurigana,
      showKana: profile.showKana,
      dailyGoal: profile.dailyGoalConfirmed ? profile.dailyGoal : null,
      jlptLevel: profile.jlptLevel,
    );
    return profile;
  });
});

final missionsProvider = FutureProvider.autoDispose<List<MissionModel>>((ref) {
  return ref.watch(homeRepositoryProvider).fetchTodayMissions();
});
