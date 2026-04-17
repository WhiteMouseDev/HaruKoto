import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../providers/lesson_session_provider.dart';
import '../providers/study_provider.dart';
import 'widgets/lesson_intro_steps.dart';
import 'widgets/lesson_step_content.dart';

/// 레슨 학습 플로우: 6-Step (상황 프리뷰 → 가이드 리딩 → 이해 체크 → 매칭 게임 → 문장 재구성 → 결과)
class LessonPage extends ConsumerStatefulWidget {
  final String lessonId;
  const LessonPage({super.key, required this.lessonId});

  @override
  ConsumerState<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends ConsumerState<LessonPage> {
  static const _totalSteps = 8;

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(lessonDetailProvider(widget.lessonId));
    final session = ref.watch(lessonSessionProvider(widget.lessonId));
    final sessionNotifier =
        ref.read(lessonSessionProvider(widget.lessonId).notifier);

    ref.listen<LessonSessionState>(
      lessonSessionProvider(widget.lessonId),
      (previous, next) {
        final nextError = next.submissionErrorMessage;
        if (nextError == null ||
            nextError == previous?.submissionErrorMessage) {
          return;
        }
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(nextError)),
        );
        sessionNotifier.clearSubmissionError();
      },
    );

    return PopScope(
      canPop: session.canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          sessionNotifier.goBack();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: detailAsync.when(
            data: (d) => Text(d.title),
            loading: () => const Text('레슨'),
            error: (_, __) => const Text('레슨'),
          ),
          leading: IconButton(
            icon: const Icon(LucideIcons.x),
            onPressed: () => context.pop(),
          ),
        ),
        body: detailAsync.when(
          data: (detail) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.md,
                  vertical: AppSizes.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: LessonStepProgressBar(
                        currentStep: session.step.index,
                        totalSteps: _totalSteps,
                      ),
                    ),
                    if (session.showDialogueShortcut) ...[
                      const SizedBox(width: AppSizes.sm),
                      GestureDetector(
                        onTap: () => showLessonDialogueSheet(context, detail),
                        child: const Icon(
                          LucideIcons.messageSquare,
                          size: 18,
                          color: AppColors.primaryStrong,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: LessonStepContent(
                    lessonId: widget.lessonId,
                    detail: detail,
                    session: session,
                    totalSteps: _totalSteps,
                  ),
                ),
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('오류: $e')),
        ),
      ),
    );
  }
}
