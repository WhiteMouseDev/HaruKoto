import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/auth/current_account_provider.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../providers/lesson_session_provider.dart';
import '../data/models/lesson_models.dart';
import 'widgets/lesson_intro_steps.dart';
import 'widgets/lesson_step_content.dart';

/// 레슨 학습 플로우: 6-Step (상황 프리뷰 → 가이드 리딩 → 이해 체크 → 매칭 게임 → 문장 재구성 → 결과)
class LessonPage extends ConsumerStatefulWidget {
  final String lessonId;
  final TtsService? ttsService;
  const LessonPage({super.key, required this.lessonId, this.ttsService});

  @override
  ConsumerState<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends ConsumerState<LessonPage>
    with WidgetsBindingObserver {
  static const _totalSteps = 8;
  bool _exiting = false;
  bool _allowPop = false;
  TtsService get _tts => widget.ttsService ?? TtsService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _tts.stop(lessonId: widget.lessonId);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _tts.stop(lessonId: widget.lessonId);
      unawaited(
          ref.read(lessonSessionProvider(widget.lessonId).notifier).flush());
    }
  }

  Future<void> _exit() async {
    if (_exiting) return;
    _tts.stop(lessonId: widget.lessonId);
    setState(() => _exiting = true);
    final owner = ref.read(currentAccountReaderProvider)();
    final notifier =
        ref.read(lessonSessionProvider(widget.lessonId).notifier).actions;
    notifier.beginClosing();
    final saved = await notifier
        .flush()
        .timeout(const Duration(seconds: 3), onTimeout: () => false);
    if (!mounted || ref.read(currentAccountReaderProvider)() != owner) {
      notifier.cancelClosing();
      if (mounted) setState(() => _exiting = false);
      return;
    }
    if (!saved) {
      final leave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('최근 진행을 저장하지 못했어요'),
                content: const Text(
                    '이 기기의 저장 공간을 확인한 뒤 다시 시도해 주세요. 지금 나가면 최근 진행이 저장되지 않을 수 있어요.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('머무르기')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('저장 없이 나가기')),
                ],
              ));
      if (!mounted ||
          ref.read(currentAccountReaderProvider)() != owner ||
          leave != true) {
        notifier.cancelClosing();
        if (mounted) setState(() => _exiting = false);
        return;
      }
    }
    if (mounted) {
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ref.read(currentAccountReaderProvider)() == owner) {
          context.pop();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(lessonResumeDetailProvider(widget.lessonId));
    final session = ref.watch(lessonSessionProvider(widget.lessonId));
    final sessionNotifier =
        ref.read(lessonSessionProvider(widget.lessonId).notifier);

    final sessionActions = sessionNotifier.actions;

    ref.listen<LessonSessionState>(
      lessonSessionProvider(widget.lessonId),
      (previous, next) {
        if (previous != null && previous.step != next.step) {
          _tts.stop(lessonId: widget.lessonId);
        }
        final nextStartError = next.startErrorMessage;
        if (nextStartError != null &&
            nextStartError != previous?.startErrorMessage) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(content: Text(nextStartError)),
          );
          sessionNotifier.clearStartError();
          return;
        }

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
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (session.canPop ||
              session.result != null ||
              session.submissionPending ||
              session.serverRecorded) {
            unawaited(_exit());
          } else {
            _tts.stop(lessonId: widget.lessonId);
            sessionActions.goBack();
          }
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
            onPressed: () => unawaited(_exit()),
          ),
        ),
        body: AbsorbPointer(
            absorbing: _exiting,
            child: detailAsync.when(
              data: (detail) => Column(
                children: [
                  if (session.storageError)
                    MaterialBanner(
                      content: const Text('최근 진행이 기기에 저장되지 않았어요.'),
                      actions: [
                        TextButton(
                            onPressed: () => unawaited(sessionActions.flush()),
                            child: const Text('저장 재시도'))
                      ],
                    ),
                  if (session.notice != null)
                    Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.md, vertical: AppSizes.sm),
                        child: Text(session.notice!,
                            style: Theme.of(context).textTheme.bodySmall)),
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
                            onTap: () {
                              _tts.stop(lessonId: widget.lessonId);
                              unawaited(showLessonDialogueSheet(context, detail,
                                  ttsService: _tts));
                            },
                            child: const Icon(
                              LucideIcons.messageSquare,
                              size: 18,
                              color: AppColors.sakura,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: session.submissionPending || session.serverRecorded
                          ? _SubmissionStatus(
                              detail: detail,
                              session: session,
                              onCheck: () =>
                                  unawaited(sessionActions.checkSubmission()))
                          : LessonStepContent(
                              ttsService: _tts,
                              lessonId: widget.lessonId,
                              detail: detail,
                              session: session,
                              totalSteps: _totalSteps,
                              onExit: () {
                                if (sessionActions.isCurrent) {
                                  unawaited(_exit());
                                }
                              },
                            ),
                    ),
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                  child: Padding(
                      padding: const EdgeInsets.all(AppSizes.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(e is ApiException
                              ? e.userMessage
                              : '레슨과 저장된 진행을 불러오지 못했어요. 다시 시도해 주세요.'),
                          const SizedBox(height: AppSizes.md),
                          FilledButton(
                              onPressed: () => ref.invalidate(
                                  lessonResumeDetailProvider(widget.lessonId)),
                              child: const Text('다시 시도')),
                        ],
                      ))),
            )),
      ),
    );
  }
}

class _SubmissionStatus extends StatelessWidget {
  const _SubmissionStatus(
      {required this.detail, required this.session, required this.onCheck});
  final LessonDetailModel detail;
  final LessonSessionState session;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) => Center(
          child: Padding(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(
              session.serverRecorded
                  ? LucideIcons.checkCircle
                  : LucideIcons.cloud,
              size: 32),
          const SizedBox(height: AppSizes.md),
          Text(session.serverRecorded ? '서버의 학습 기록을 확인했어요' : '제출 결과 확인이 필요해요',
              style: Theme.of(context).textTheme.titleMedium),
          if (session.serverRecorded && session.serverProgress != null) ...[
            const SizedBox(height: AppSizes.sm),
            Text(
                '저장된 레슨 기록 · ${session.serverProgress!.scoreCorrect}/${session.serverProgress!.scoreTotal}문항'),
          ],
          const SizedBox(height: AppSizes.md),
          if (session.submissionPending)
            FilledButton(
              onPressed: session.submitting ? null : onCheck,
              child: Text(session.submitting ? '확인 중…' : '서버 기록 다시 확인'),
            ),
        ]),
      ));
}
