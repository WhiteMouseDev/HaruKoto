import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/network/api_exception.dart';
import '../../../home/data/models/dashboard_model.dart';
import '../../../home/providers/home_provider.dart';

class StudyKanaSection extends ConsumerWidget {
  const StudyKanaSection({super.key, required this.dataBuilder});

  final Widget Function(KanaProgressData progress) dataBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    final Widget child;

    // Refreshes can retain a previous value or error. Never present that
    // progress as current while its new read is pending or has failed.
    if (dashboard.isLoading) {
      child = const _KanaReadStatus(loading: true);
    } else if (dashboard.hasError) {
      child = _KanaReadStatus(
        error: dashboard.error,
        onRetry: () => _retry(ref),
      );
    } else {
      final progress = dashboard.value?.kanaProgress;
      if (progress == null ||
          progress.hiragana.total <= 0 ||
          progress.katakana.total <= 0) {
        child = _KanaReadStatus(unavailable: true, onRetry: () => _retry(ref));
      } else if (progress.completed) {
        return const SizedBox.shrink();
      } else {
        child = dataBuilder(progress);
      }
    }

    return Padding(padding: const EdgeInsets.only(bottom: 40), child: child);
  }

  void _retry(WidgetRef ref) {
    if (ref.read(dashboardProvider).isLoading) return;
    ref.invalidate(dashboardProvider);
  }
}

class _KanaReadStatus extends StatelessWidget {
  const _KanaReadStatus({
    this.loading = false,
    this.unavailable = false,
    this.error,
    this.onRetry,
  });

  final bool loading;
  final bool unavailable;
  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cause = error is DioException ? (error as DioException).error : error;
    final message = cause is ApiException
        ? cause.userMessage
        : const ApiException(message: '잠시 후 다시 시도해 주세요.').userMessage;

    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.light
              ? AppColors.cardWarm
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text('가나 학습 현황', style: theme.textTheme.titleSmall),
            ),
            const SizedBox(height: 8),
            Text(
              loading
                  ? '가나 학습 현황을 불러오고 있어요.'
                  : unavailable
                      ? '가나 진도를 확인할 수 없어요.'
                      : '가나 학습 현황을 불러오지 못했어요.',
              style: theme.textTheme.bodyMedium,
            ),
            if (loading) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                semanticsLabel: '가나 학습 현황 불러오는 중',
                color: theme.colorScheme.onSurface,
              ),
            ] else ...[
              const SizedBox(height: 4),
              Text(message, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            Text('레슨 학습은 계속할 수 있어요.', style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: loading ? null : onRetry,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurface,
                    minimumSize: const Size(0, 48),
                  ),
                  icon: const Icon(LucideIcons.refreshCw, size: 18),
                  label: const Text(
                    '다시 불러오기',
                    semanticsLabel: '가나 학습 현황 다시 불러오기',
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/study/kana'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.sakuraOn,
                    backgroundColor: AppColors.sakuraContainer,
                    minimumSize: const Size(0, 48),
                  ),
                  child: const Text('가나 학습 열기'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
