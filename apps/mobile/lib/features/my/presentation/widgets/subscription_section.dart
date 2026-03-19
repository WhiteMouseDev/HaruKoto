import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../shared/widgets/app_section_header.dart';
import '../../providers/my_provider.dart';

class SubscriptionSection extends ConsumerWidget {
  final VoidCallback? onNavigateToPricing;
  final VoidCallback? onNavigateToManage;
  final VoidCallback? onNavigateToPayments;

  const SubscriptionSection({
    super.key,
    this.onNavigateToPricing,
    this.onNavigateToManage,
    this.onNavigateToPayments,
  });

  String _planLabel(String plan) {
    switch (plan.toUpperCase()) {
      case 'MONTHLY':
        return '월간 프리미엄';
      case 'YEARLY':
        return '연간 프리미엄';
      default:
        return '무료';
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '-';
    final date = DateTime.tryParse(iso);
    if (date == null) return '-';
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final subAsync = ref.watch(subscriptionStatusProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(label: '구독'),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          ),
          clipBehavior: Clip.antiAlias,
          child: subAsync.when(
            loading: () => Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            error: (err, __) => Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(LucideIcons.wifiOff,
                      size: 24,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                  const SizedBox(height: 8),
                  Text(
                    '구독 정보를 불러올 수 없습니다',
                    style: TextStyle(
                        fontSize: 13,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ),
            data: (status) {
              final sub = status.subscription;
              return Column(
                children: [
                  // Current Plan
                  if (!sub.isPremium)
                    ListTile(
                      onTap: onNavigateToPricing,
                      leading: Icon(
                        LucideIcons.sparkles,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      title: const Text(
                        '프리미엄으로 업그레이드',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      subtitle: const Text(
                        'AI 회화 무제한 · 모든 퀴즈 모드',
                        style: TextStyle(fontSize: 11),
                      ),
                      trailing: Icon(
                        LucideIcons.chevronRight,
                        size: 16,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    )
                  else
                    ListTile(
                      onTap: onNavigateToPricing,
                      leading: Icon(
                        LucideIcons.crown,
                        size: 20,
                        color: AppColors.hkYellow(theme.brightness),
                      ),
                      title: Text(
                        _planLabel(sub.plan),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (sub.expiresAt != null)
                            Text(
                              '${sub.isCancelled ? '만료 예정: ' : '다음 결제: '}${_formatDate(sub.expiresAt)}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          if (sub.isCancelled)
                            Text(
                              '취소됨 - ${_formatDate(sub.expiresAt)}까지 이용 가능',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.warning(theme.brightness),
                              ),
                            ),
                          if (!sub.isCancelled)
                            Text(
                              '탭하여 플랜 변경',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                        ],
                      ),
                      trailing: Icon(
                        LucideIcons.chevronRight,
                        size: 16,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),

                  if (sub.isPremium) ...[
                    const Divider(height: 1),
                    ListTile(
                      onTap: onNavigateToManage,
                      leading: Icon(
                        LucideIcons.settings,
                        size: 20,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      title: const Text(
                        '구독 관리',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        sub.isCancelled
                            ? '구독 재개 또는 만료일 확인'
                            : '플랜 변경, 취소/재개, 상태 확인',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: Icon(
                        LucideIcons.chevronRight,
                        size: 16,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],

                  const Divider(height: 1),

                  // Payment History
                  ListTile(
                    onTap: onNavigateToPayments,
                    leading: Icon(
                      LucideIcons.creditCard,
                      size: 20,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    title: const Text(
                      '결제 내역',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    trailing: Icon(
                      LucideIcons.chevronRight,
                      size: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
