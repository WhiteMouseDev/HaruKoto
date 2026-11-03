import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/current_account_provider.dart';

import '../../providers/lesson_activity_sync_provider.dart';

/// Also mounted on home: attendance-only tombstones remain reachable after the
/// graded lesson/checkpoint has completed or been explicitly restarted.
class LessonActivityPendingBanner extends ConsumerStatefulWidget {
  const LessonActivityPendingBanner({super.key});

  @override
  ConsumerState<LessonActivityPendingBanner> createState() =>
      _LessonActivityPendingBannerState();
}

class _LessonActivityPendingBannerState
    extends ConsumerState<LessonActivityPendingBanner>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(ref.read(lessonActivitySyncProvider.notifier).sync());
    }
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(currentAccountIdProvider);
    if (owner == null || ref.watch(currentAccountReaderProvider)() != owner) {
      return const SizedBox.shrink();
    }
    final status = ref.watch(lessonActivitySyncProvider);
    if (status.pendingCount == 0 && !status.storageError) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('lesson-activity-pending'),
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('학습일 저장 대기', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
            status.syncing
                ? '답변을 저장하고 있어요. 서버 확인 후 학습일에 반영해요.'
                : status.error ?? '저장된 답변으로 학습일 기록을 확인해 주세요.',
            style: theme.textTheme.bodySmall),
        const SizedBox(height: 6),
        if (status.syncing)
          const LinearProgressIndicator(semanticsLabel: '학습일 저장 확인 중')
        else
          TextButton(
              onPressed: () => unawaited(
                  ref.read(lessonActivitySyncProvider.notifier).sync()),
              child: const Text('같은 답변 다시 확인')),
      ]),
    );
  }
}
