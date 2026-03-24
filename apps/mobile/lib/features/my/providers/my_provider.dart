import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/dio_provider.dart';
import '../../../core/providers/user_preferences_provider.dart';
import '../data/my_repository.dart';
import '../data/models/achievement_model.dart';
import '../data/models/profile_detail_model.dart';
import '../data/models/subscription_model.dart';

final myRepositoryProvider = Provider((ref) {
  return MyRepository(ref.watch(dioProvider));
});

final profileDetailProvider =
    FutureProvider.autoDispose<ProfileDetailModel>((ref) {
  return ref.watch(myRepositoryProvider).fetchProfileDetail().then((detail) {
    final profile = detail.profile;
    unawaited(
      ref.read(userPreferencesProvider.notifier).syncFromServer(
            showFurigana: profile.showFurigana,
            showKana: profile.showKana,
            dailyGoal: profile.dailyGoal,
            jlptLevel: profile.jlptLevel,
            callSettings: profile.callSettings,
          ),
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
