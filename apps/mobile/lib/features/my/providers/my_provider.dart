import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/dio_provider.dart';
import '../data/my_repository.dart';
import '../data/models/profile_detail_model.dart';
import '../data/models/subscription_model.dart';

final myRepositoryProvider = Provider((ref) {
  return MyRepository(ref.watch(dioProvider));
});

final profileDetailProvider =
    FutureProvider.autoDispose<ProfileDetailModel>((ref) {
  return ref.watch(myRepositoryProvider).fetchProfileDetail();
});

final subscriptionStatusProvider =
    FutureProvider.autoDispose<SubscriptionStatus>((ref) {
  return ref.watch(myRepositoryProvider).fetchSubscriptionStatus();
});
