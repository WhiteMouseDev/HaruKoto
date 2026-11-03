import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/current_account_provider.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers/dio_provider.dart';
import '../../../core/providers/user_preferences_provider.dart';
import '../data/my_repository.dart';
import '../data/models/achievement_model.dart';
import '../data/models/profile_detail_model.dart';
import '../data/models/subscription_model.dart';

final myRepositoryProvider = Provider((ref) {
  final repository = MyRepository(ref.watch(dioProvider),
      currentOwner: ref.watch(currentAccountReaderProvider));
  ref.onDispose(repository.dispose);
  return repository;
});

final profileDetailProvider =
    FutureProvider.autoDispose<ProfileDetailModel>((ref) {
  ref.watch(currentAccountIdProvider);
  final preferences = ref.read(userPreferencesProvider.notifier);
  final scope = preferences.requestScope;
  return ref
      .watch(myRepositoryProvider)
      .fetchProfileDetail()
      .then((detail) async {
    if (!ref.mounted ||
        !preferences.isCurrent(scope) ||
        (detail.profile.id.isNotEmpty && detail.profile.id != scope.owner)) {
      throw const ApiException(message: '계정이나 목표가 변경되어 프로필을 다시 확인해주세요.');
    }
    final profile = detail.profile;
    await preferences.syncFromServer(
      scope: scope,
      showFurigana: profile.showFurigana,
      showKana: profile.showKana,
      dailyGoal: profile.dailyGoalConfirmed ? profile.dailyGoal : null,
      jlptLevel: profile.jlptLevel,
      callSettings: profile.callSettings,
    );
    return detail;
  });
});

final achievementsProvider =
    FutureProvider.autoDispose<List<AchievementItem>>((ref) {
  return ref.watch(myRepositoryProvider).fetchAchievements();
});

final subscriptionStatusProvider =
    FutureProvider.autoDispose<SubscriptionStatus>((ref) {
  return ref.watch(myRepositoryProvider).fetchSubscriptionStatus();
});
