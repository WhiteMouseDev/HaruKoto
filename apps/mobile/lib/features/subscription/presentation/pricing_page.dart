import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/sizes.dart';
import '../data/models/plan_model.dart';
import '../providers/subscription_provider.dart';
import 'widgets/plan_card.dart';
import 'widgets/feature_comparison.dart';
import 'checkout_page.dart';

class PricingPage extends ConsumerWidget {
  const PricingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final subAsync = ref.watch(subscriptionPricingProvider);
    final currentPlan = subAsync.value?.subscription.plan;

    return Scaffold(
      appBar: AppBar(title: const Text('프리미엄 플랜')),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.md),
        children: [
          // Plan Cards
          ...pricingPlans.map((plan) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: PlanCardWidget(
                plan: plan,
                currentPlan: currentPlan,
                onSelect: (selectedPlan) {
                  if (selectedPlan.id == 'free') return;
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => CheckoutPage(planId: selectedPlan.id),
                    ),
                  );
                },
              ),
            );
          }),

          const SizedBox(height: 8),

          // Feature Comparison
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '기능 비교',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const FeatureComparison(),
          const SizedBox(height: 24),

          // Footer
          Text(
            '구독은 언제든 취소할 수 있으며, 현재 결제 기간이 끝날 때까지 프리미엄 기능을 이용할 수 있습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
