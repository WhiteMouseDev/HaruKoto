import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../providers/my_provider.dart';

class SubscriptionManagePage extends ConsumerStatefulWidget {
  const SubscriptionManagePage({super.key});

  @override
  ConsumerState<SubscriptionManagePage> createState() =>
      _SubscriptionManagePageState();
}

class _SubscriptionManagePageState
    extends ConsumerState<SubscriptionManagePage> {
  bool _submitting = false;

  String _planLabel(String plan) {
    switch (plan.toUpperCase()) {
      case 'MONTHLY':
        return '월간 프리미엄';
      case 'YEARLY':
        return '연간 프리미엄';
      default:
        return '무료 플랜';
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '-';
    final date = DateTime.tryParse(iso);
    if (date == null) return '-';
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }

  Future<void> _resumeSubscription() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await ref.read(myRepositoryProvider).resumeSubscription();
      ref.invalidate(subscriptionStatusProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('구독이 재개되었습니다')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('구독 재개에 실패했습니다')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _cancelSubscription() async {
    if (_submitting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('구독을 취소하시겠습니까?'),
          content: const Text(
            '구독을 취소하면 현재 결제 기간이 끝날 때까지 프리미엄 기능을 계속 이용할 수 있습니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('유지하기'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error(Theme.of(context).brightness),
              ),
              child: const Text('구독 취소'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      await ref.read(myRepositoryProvider).cancelSubscription();
      ref.invalidate(subscriptionStatusProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('구독이 취소되었습니다')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('구독 취소에 실패했습니다')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subAsync = ref.watch(subscriptionStatusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('구독 관리')),
      body: subAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '구독 정보를 불러오지 못했습니다',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(subscriptionStatusProvider),
                icon: const Icon(LucideIcons.rotateCw, size: 16),
                label: const Text('재시도'),
              ),
            ],
          ),
        ),
        data: (status) {
          final sub = status.subscription;
          return ListView(
            padding: const EdgeInsets.all(AppSizes.md),
            children: [
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            sub.isPremium
                                ? LucideIcons.crown
                                : LucideIcons.sparkles,
                            size: 20,
                            color: sub.isPremium
                                ? AppColors.hkYellow(theme.brightness)
                                : theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _planLabel(sub.plan),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (sub.expiresAt != null)
                        Text(
                          sub.isCancelled
                              ? '만료 예정: ${_formatDate(sub.expiresAt)}'
                              : '다음 결제일: ${_formatDate(sub.expiresAt)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.65),
                          ),
                        ),
                      if (sub.isCancelled) ...[
                        const SizedBox(height: 6),
                        Text(
                          '취소됨 - 기간 만료 전까지 프리미엄 유지',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.warning(theme.brightness),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                ),
                child: Column(
                  children: [
                    ListTile(
                      onTap: () => context.push('/pricing'),
                      leading: Icon(
                        LucideIcons.badgeDollarSign,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      title: const Text(
                        '플랜 변경',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: const Text(
                        '월간/연간 플랜 비교 후 변경',
                        style: TextStyle(fontSize: 11),
                      ),
                      trailing: Icon(
                        LucideIcons.chevronRight,
                        size: 16,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      onTap: () => context.push('/my/payments'),
                      leading: Icon(
                        LucideIcons.creditCard,
                        size: 20,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      title: const Text(
                        '결제 내역',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: Icon(
                        LucideIcons.chevronRight,
                        size: 16,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              if (sub.isPremium) ...[
                const SizedBox(height: 16),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sub.isCancelled ? '구독 재개' : '구독 취소',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          sub.isCancelled
                              ? '만료 전에 재개하면 프리미엄이 유지됩니다.'
                              : '취소해도 현재 결제 기간이 끝날 때까지 프리미엄을 이용할 수 있습니다.',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.55),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: sub.isCancelled
                              ? ElevatedButton(
                                  onPressed:
                                      _submitting ? null : _resumeSubscription,
                                  style: ElevatedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _submitting
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('구독 재개'),
                                )
                              : OutlinedButton(
                                  onPressed:
                                      _submitting ? null : _cancelSubscription,
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: AppColors.error(theme.brightness),
                                    ),
                                    foregroundColor:
                                        AppColors.error(theme.brightness),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _submitting
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('구독 취소'),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
