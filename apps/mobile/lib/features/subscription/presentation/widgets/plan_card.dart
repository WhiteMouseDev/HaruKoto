import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../data/models/plan_model.dart';

class PlanCardWidget extends StatelessWidget {
  final PricingPlan plan;
  final String? currentPlan;
  final ValueChanged<PricingPlan> onSelect;

  const PlanCardWidget({
    super.key,
    required this.plan,
    this.currentPlan,
    required this.onSelect,
  });

  String _formatPrice(int price) {
    final str = price.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCurrent = currentPlan == plan.id;
    final isFree = plan.id == 'free';

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        side: plan.recommended
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                Row(
                  children: [
                    if (!isFree) ...[
                      Icon(
                        LucideIcons.crown,
                        size: 20,
                        color: AppColors.hkYellow(theme.brightness),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      plan.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Price
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    if (plan.originalPrice != null) ...[
                      Text(
                        '${_formatPrice(plan.originalPrice!)}원',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4),
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      plan.price == 0 ? '무료' : '${_formatPrice(plan.price)}원',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (plan.period.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        '/${plan.period}',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // Features
                ...plan.features.map((feature) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.check,
                          size: 16,
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
                  );
                }),
                const SizedBox(height: 8),

                // Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: plan.recommended
                      ? ElevatedButton(
                          onPressed:
                              isCurrent || isFree ? null : () => onSelect(plan),
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            isCurrent
                                ? '현재 플랜'
                                : isFree
                                    ? '현재 무료'
                                    : '구독하기',
                          ),
                        )
                      : OutlinedButton(
                          onPressed:
                              isCurrent || isFree ? null : () => onSelect(plan),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            isCurrent
                                ? '현재 플랜'
                                : isFree
                                    ? '현재 무료'
                                    : '구독하기',
                          ),
                        ),
                ),
              ],
            ),
          ),
          if (plan.recommended)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                  ),
                ),
                child: Text(
                  '추천',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
