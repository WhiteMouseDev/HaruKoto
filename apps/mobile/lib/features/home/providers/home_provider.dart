import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/dio_provider.dart';
import '../data/home_repository.dart';
import '../data/models/dashboard_model.dart';
import '../data/models/mission_model.dart';
import '../data/models/user_profile_model.dart';

final homeRepositoryProvider = Provider((ref) {
  return HomeRepository(ref.watch(dioProvider));
});

final dashboardProvider = FutureProvider.autoDispose<DashboardModel>((ref) async {
  return await ref.watch(homeRepositoryProvider).fetchDashboard();
});

final profileProvider = FutureProvider.autoDispose<UserProfileModel>((ref) {
  return ref.watch(homeRepositoryProvider).fetchProfile();
});

final missionsProvider =
    FutureProvider.autoDispose<List<MissionModel>>((ref) {
  return ref.watch(homeRepositoryProvider).fetchTodayMissions();
});
