import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../data/models/plan_model.dart';
import '../providers/subscription_provider.dart';
import 'widgets/feature_comparison.dart';

class PricingPage extends ConsumerStatefulWidget {
  const PricingPage({super.key});

  @override
  ConsumerState<PricingPage> createState() => _PricingPageState();
}

class _PricingPageState extends ConsumerState<PricingPage> {
  String _selectedPlanId = 'yearly';
  bool _didInteract = false;
  bool _showComparison = false;

  String _normalizePlanId(String? plan) {
    switch (plan?.toUpperCase()) {
      case 'MONTHLY':
        return 'monthly';
      case 'YEARLY':
        return 'yearly';
      default:
        return 'free';
    }
  }

  String _formatPrice(int price) {
    final str = price.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  List<String> _premiumBenefits(String selectedPlanId) {
    final monthly =
        pricingPlans.firstWhere((plan) => plan.id == 'monthly').features;
    if (selectedPlanId == 'yearly') {
      return [...monthly, '연간 결제로 32% 절약'];
    }
    return monthly;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subAsync = ref.watch(subscriptionPricingProvider);
    final currentPlanId = _normalizePlanId(subAsync.value?.subscription.plan);
    final isPremium = subAsync.value?.subscription.isPremium ?? false;

    final selectedPlanId = _didInteract &&
            (_selectedPlanId == 'monthly' || _selectedPlanId == 'yearly')
        ? _selectedPlanId
        : (currentPlanId == 'monthly' || currentPlanId == 'yearly'
            ? currentPlanId
            : _selectedPlanId);

    final selectedPlan =
        pricingPlans.firstWhere((plan) => plan.id == selectedPlanId);
    final isCurrentPlan = isPremium && currentPlanId == selectedPlanId;
    final monthlyPlan = pricingPlans.firstWhere((plan) => plan.id == 'monthly');
    final yearlyPlan = pricingPlans.firstWhere((plan) => plan.id == 'yearly');
    final yearlyMonthlyEquivalent = (yearlyPlan.price / 12).round();

    final ctaLabel = isCurrentPlan
        ? '현재 이용 중'
        : isPremium
            ? (selectedPlanId == 'yearly' ? '연간으로 변경하기' : '월간으로 변경하기')
            : '프리미엄 시작하기';

    return Scaffold(
      appBar: AppBar(title: const Text('프리미엄 플랜')),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.md),
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        LucideIcons.crown,
                        size: 22,
                        color: AppColors.hkYellow(theme.brightness),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '프리미엄으로 업그레이드',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'AI 회화 무제한, 모든 캐릭터 해금, 광고 제거',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  if (isPremium) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        currentPlanId == 'yearly' ? '현재 연간 이용 중' : '현재 월간 이용 중',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: _PlanToggleButton(
                    selected: selectedPlanId == 'monthly',
                    label: '월간',
                    subLabel: '${_formatPrice(monthlyPlan.price)}원/월',
                    onTap: () {
                      setState(() {
                        _didInteract = true;
                        _selectedPlanId = 'monthly';
                      });
                    },
                  ),
                ),
                Expanded(
                  child: _PlanToggleButton(
                    selected: selectedPlanId == 'yearly',
                    label: '연간',
                    subLabel: '32% 할인',
                    badge: '추천',
                    onTap: () {
                      setState(() {
                        _didInteract = true;
                        _selectedPlanId = 'yearly';
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.cardRadius),
              side: BorderSide(
                color: theme.colorScheme.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        selectedPlan.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (selectedPlanId == 'yearly') ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryStrong.withValues(
                              alpha: 0.15,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            '월 3,325원',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryStrong,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${_formatPrice(selectedPlan.price)}원',
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          selectedPlanId == 'yearly' ? '/년' : '/월',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (selectedPlanId == 'yearly') ...[
                    const SizedBox(height: 6),
                    Text(
                      '월간 대비 연 ${_formatPrice(monthlyPlan.price * 12 - yearlyPlan.price)}원 절약',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 6),
                    Text(
                      '연간 결제 시 월 ${_formatPrice(yearlyMonthlyEquivalent)}원',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ..._premiumBenefits(selectedPlanId).map(
                    (feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            LucideIcons.checkCircle2,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              feature,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _PrimaryCtaButton(
                    enabled: !isCurrentPlan,
                    label: ctaLabel,
                    onTap: () {
                      if (isCurrentPlan) return;
                      context.push(
                        '/subscription/checkout?planId=$selectedPlanId',
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  title: const Text(
                    '무료 vs 프리미엄 비교',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    '필요한 경우에만 확인하세요',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: Icon(
                    _showComparison
                        ? LucideIcons.chevronUp
                        : LucideIcons.chevronDown,
                  ),
                  onTap: () =>
                      setState(() => _showComparison = !_showComparison),
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 220),
                  crossFadeState: _showComparison
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  firstChild: const Padding(
                    padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: FeatureComparison(),
                  ),
                  secondChild: const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '구독은 언제든 구독 관리에서 변경/취소할 수 있으며, 현재 결제 기간 종료 시점까지 프리미엄 기능이 유지됩니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _PlanToggleButton extends StatelessWidget {
  const _PlanToggleButton({
    required this.selected,
    required this.label,
    required this.subLabel,
    required this.onTap,
    this.badge,
  });

  final bool selected;
  final String label;
  final String subLabel;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: selected ? theme.colorScheme.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge!,
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(
                subLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryCtaButton extends StatelessWidget {
  const _PrimaryCtaButton({
    required this.enabled,
    required this.label,
    required this.onTap,
  });

  final bool enabled;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [
                AppColors.primaryStrong,
                theme.colorScheme.primary,
              ],
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: enabled ? onTap : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  LucideIcons.lock,
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
