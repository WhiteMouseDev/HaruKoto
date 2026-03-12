import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class AppErrorRetry extends StatelessWidget {
  final VoidCallback onRetry;
  final String? message;
  final String? submessage;

  const AppErrorRetry({
    super.key,
    required this.onRetry,
    this.message,
    this.submessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.cloudOff,
            size: 48,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            message ?? '데이터를 불러올 수 없습니다',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            submessage ?? '네트워크 연결을 확인해주세요',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(LucideIcons.rotateCw, size: 18),
            label: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}
