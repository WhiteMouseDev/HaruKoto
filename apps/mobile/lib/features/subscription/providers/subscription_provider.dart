import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/dio_provider.dart';
import '../../my/data/models/subscription_model.dart';
import '../data/subscription_repository.dart';

final subscriptionRepositoryProvider = Provider((ref) {
  return SubscriptionRepository(ref.watch(dioProvider));
});

final subscriptionPricingProvider =
    FutureProvider.autoDispose<SubscriptionStatus>((ref) {
  return ref.watch(subscriptionRepositoryProvider).fetchStatus();
});
