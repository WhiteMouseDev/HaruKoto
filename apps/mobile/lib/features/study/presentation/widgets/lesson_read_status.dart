import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/network/api_exception.dart';

/// Lesson catalogue failures do not block the independent review/kana sections.
class LessonReadStatus extends StatelessWidget {
  const LessonReadStatus({
    super.key,
    this.loading = false,
    this.error,
    this.onRetry,
  });

  final bool loading;
  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final failure = error is DioException
        ? ApiException.fromDioException(error! as DioException)
        : error is ApiException
            ? error! as ApiException
            : const ApiException(message: '잠시 후 다시 시도해 주세요.');

    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.light
              ? AppColors.cardWarm
              : theme.colorScheme.surfaceContainerLow,
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loading ? '레슨을 불러오고 있어요.' : '레슨을 불러오지 못했어요.',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            if (loading)
              const LinearProgressIndicator(semanticsLabel: '레슨 불러오는 중')
            else
              Text(failure.userMessage, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Text('다른 학습은 계속할 수 있어요.', style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('lesson-catalogue-retry'),
              onPressed: loading ? null : onRetry,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                foregroundColor: theme.colorScheme.primary,
              ),
              icon: const Icon(LucideIcons.refreshCw, size: 18),
              label: const Text('다시 불러오기', semanticsLabel: '레슨 다시 불러오기'),
            ),
          ],
        ),
      ),
    );
  }
}
