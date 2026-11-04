import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/auth/current_account_provider.dart';
import '../../../core/network/api_exception.dart';
import '../../home/providers/home_provider.dart';
import '../data/models/kana_character_model.dart';
import '../data/models/kana_stage_model.dart';
import '../providers/kana_provider.dart';
import '../providers/kana_completion_service.dart';
import 'widgets/stage_intro.dart';
import 'widgets/stage_practice.dart';
import 'widgets/stage_quiz.dart';
import 'widgets/stage_review.dart';
import 'widgets/stage_complete.dart';
import 'widgets/kana_save_status.dart';

enum _Phase { intro, practice, quiz, review, complete }

class KanaStagePage extends ConsumerStatefulWidget {
  final String type;
  final int stageNumber;

  const KanaStagePage({
    super.key,
    required this.type,
    required this.stageNumber,
  });

  @override
  ConsumerState<KanaStagePage> createState() => _KanaStagePageState();
}

class _KanaStagePageState extends ConsumerState<KanaStagePage> {
  _Phase _phase = _Phase.intro;
  late final String? _owner;
  bool _startingQuiz = false;
  String? _startError;
  bool _savingAnswer = false;
  String? _answerError;
  bool _completing = false;
  String? _completionError;
  bool _completionMayBeReplay = false;
  String? _quizStageId;
  CompleteQuizResponse? _quizCompletion;
  Timer? _advanceTimer;
  int _introIndex = 0;
  int _practiceIndex = 0;
  int _reviewIndex = 0;

  List<QuizQuestion> _quizQuestions = [];
  String? _quizSessionId;
  int _quizCurrentIndex = 0;
  String? _quizSelectedOption;
  bool _quizShowFeedback = false;
  final List<_QuizAnswer> _quizAnswers = [];

  int _quizCorrect = 0;
  int _quizTotal = 0;
  int _xpEarned = 0;
  List<KanaCharacterModel> _reviewCharacters = [];

  String get kanaType => widget.type == 'katakana' ? 'KATAKANA' : 'HIRAGANA';

  @override
  void initState() {
    super.initState();
    _owner = ref.read(currentAccountReaderProvider)();
  }

  bool get _isCurrent =>
      mounted &&
      _owner != null &&
      ref.read(currentAccountReaderProvider)() == _owner &&
      ref.read(currentAccountIdProvider) == _owner;

  @override
  void dispose() {
    _advanceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(currentAccountIdProvider);
    if (!_isCurrent) {
      return Scaffold(
          body: SafeArea(
              child: Center(
                  child: Text(
        const ApiException(message: '학습 계정이 변경되었어요. 학습 화면에서 다시 시작해 주세요.')
            .userMessage,
        textAlign: TextAlign.center,
      ))));
    }
    final stagesAsync = ref.watch(kanaStagesProvider(kanaType));
    final charsAsync = ref.watch(kanaCharactersProvider(kanaType));
    final theme = Theme.of(context);

    // Multi-provider composition: manual AsyncValue handling is used instead
    // of .when() because loading state combines two independent providers.
    final isLoading = stagesAsync.isLoading || charsAsync.isLoading;
    if (isLoading) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 180,
                  height: 28,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final stages = stagesAsync.value ?? [];
    final allChars = charsAsync.value ?? [];
    final stage =
        stages.where((s) => s.stageNumber == widget.stageNumber).firstOrNull;

    if (stage == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('존재하지 않는 단계입니다.', style: theme.textTheme.bodyLarge),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => context.pop(),
                  child: const Text('돌아가기'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final stageChars =
        allChars.where((c) => stage.characters.contains(c.character)).toList();

    if (stageChars.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('이 단계의 문자를 불러올 수 없습니다.', style: theme.textTheme.bodyLarge),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => context.pop(),
                  child: const Text('돌아가기'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.arrowLeft, size: 20),
                    onPressed: () => context.pop(),
                    visualDensity: VisualDensity.compact,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stage ${widget.stageNumber}: ${stage.title}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          stage.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.md),
              Expanded(
                child: _buildPhaseContent(context, stage, stageChars, theme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhaseContent(
    BuildContext context,
    KanaStageModel stage,
    List<KanaCharacterModel> stageChars,
    ThemeData theme,
  ) {
    switch (_phase) {
      case _Phase.intro:
        if (_introIndex >= stageChars.length) {
          return const SizedBox.shrink();
        }
        return StageIntro(
          character: stageChars[_introIndex],
          currentIndex: _introIndex,
          totalCount: stageChars.length,
          onNext: () {
            if (!_isCurrent) return;
            unawaited(_recordProgress(stageChars[_introIndex].id));
            if (_introIndex < stageChars.length - 1) {
              setState(() => _introIndex++);
            } else {
              setState(() {
                _practiceIndex = 0;
                _phase = _Phase.practice;
              });
            }
          },
        );
      case _Phase.practice:
        if (_practiceIndex >= stageChars.length) {
          return const SizedBox.shrink();
        }
        final char = stageChars[_practiceIndex];
        return StagePractice(
          character: char,
          currentIndex: _practiceIndex,
          totalCount: stageChars.length,
          onKnow: () {
            if (!_isCurrent) return;
            unawaited(_recordProgress(char.id));
            _advancePractice(stageChars);
          },
          onDontKnow: () => _advancePractice(stageChars),
        );
      case _Phase.quiz:
        return SingleChildScrollView(
            child: Column(children: [
          if (_quizSessionId == null)
            KanaSaveStatus(
              key: const ValueKey('kana-start-status'),
              label: _startingQuiz ? '퀴즈를 준비하고 있어요' : '퀴즈를 시작하지 못했어요',
              error: _startError,
              onRetry: _startingQuiz ? null : _startQuiz,
              retryLabel: '퀴즈 시작 다시 시도',
            )
          else ...[
            StageQuiz(
              question: _quizQuestions[_quizCurrentIndex],
              currentIndex: _quizCurrentIndex,
              totalCount: _quizQuestions.length,
              selectedOption: _quizSelectedOption,
              showFeedback: _quizShowFeedback,
              locked: _quizSelectedOption != null ||
                  _completing ||
                  _completionError != null,
              onSelect: (optionId) => _handleQuizSelect(optionId),
            ),
            if (_savingAnswer || _answerError != null)
              KanaSaveStatus(
                key: const ValueKey('kana-answer-status'),
                label: _savingAnswer ? '답안을 저장하고 있어요' : '답안을 저장하지 못했어요',
                error: _answerError,
                onRetry: _savingAnswer ? null : _saveAnswer,
                retryLabel: '답안 저장 다시 시도',
              ),
            if (_completing || _completionError != null)
              KanaSaveStatus(
                key: const ValueKey('kana-completion-status'),
                label: _completing ? '학습 결과를 저장하고 있어요' : '학습 결과를 저장하지 못했어요',
                error: _completionError,
                onRetry: _completing ? null : _handleQuizComplete,
                retryLabel:
                    _quizCompletion == null ? '결과 저장 다시 시도' : '단계 저장 다시 시도',
              ),
          ],
        ]));
      case _Phase.review:
        if (_reviewCharacters.isEmpty) {
          return const SizedBox.shrink();
        }
        return StageReview(
          character: _reviewCharacters[_reviewIndex],
          currentIndex: _reviewIndex,
          totalCount: _reviewCharacters.length,
          onAdvance: _advanceReview,
        );
      case _Phase.complete:
        return StageComplete(
          stageTitle: stage.title,
          quizCorrect: _quizCorrect,
          quizTotal: _quizTotal,
          xpEarned: _xpEarned,
          rewardConfirmed:
              !_completionMayBeReplay || (_quizCompletion?.xpEarned ?? 0) > 0,
          kanaType: widget.type,
        );
    }
  }

  void _advancePractice(List<KanaCharacterModel> chars) {
    if (!_isCurrent) return;
    if (_practiceIndex < chars.length - 1) {
      setState(() => _practiceIndex++);
    } else {
      _startQuiz();
    }
  }

  Future<void> _startQuiz() async {
    if (!_isCurrent || _startingQuiz || _quizSessionId != null) return;
    _quizStageId ??= ref
        .read(kanaStagesProvider(kanaType))
        .value
        ?.where((stage) => stage.stageNumber == widget.stageNumber)
        .firstOrNull
        ?.id;
    setState(() {
      _phase = _Phase.quiz;
      _startingQuiz = true;
      _startError = null;
    });
    try {
      final res = await ref.read(kanaRepositoryProvider).startQuiz(
            kanaType: kanaType,
            stageNumber: widget.stageNumber,
            quizMode: 'recognition',
            count: 5,
          );
      if (!_isCurrent) return;
      if (res.sessionId == null || res.questions.isEmpty) {
        throw const ApiException(message: '출제할 문제가 없어요. 잠시 후 다시 시도해 주세요.');
      }
      setState(() {
        _quizSessionId = res.sessionId;
        _quizQuestions = List.of(res.questions);
        _quizCurrentIndex = 0;
        _quizSelectedOption = null;
        _quizShowFeedback = false;
        _quizAnswers.clear();
        _startingQuiz = false;
      });
    } catch (error) {
      if (!_isCurrent) return;
      setState(() {
        _startingQuiz = false;
        _startError = kanaSaveErrorMessage(error);
      });
    }
  }

  Future<void> _handleQuizSelect(String optionId) async {
    if (!_isCurrent ||
        _quizShowFeedback ||
        _quizSelectedOption != null ||
        _completing) {
      return;
    }
    setState(() => _quizSelectedOption = optionId);
    await _saveAnswer();
  }

  Future<void> _saveAnswer() async {
    if (!_isCurrent ||
        _savingAnswer ||
        _quizShowFeedback ||
        _quizSessionId == null ||
        _quizSelectedOption == null) {
      return;
    }
    final current = _quizQuestions[_quizCurrentIndex];
    final optionId = _quizSelectedOption!;
    setState(() {
      _savingAnswer = true;
      _answerError = null;
    });
    try {
      final result =
          await ref.read(kanaCompletionServiceProvider).answerQuestion(
                sessionId: _quizSessionId!,
                questionId: current.questionId,
                selectedOptionId: optionId,
              );
      if (!_isCurrent) return;
      if (!current.options
              .any((option) => option.id == result.correctOptionId) ||
          result.isCorrect != (optionId == result.correctOptionId)) {
        throw const FormatException('Invalid kana answer acknowledgement');
      }
      setState(() {
        _quizQuestions[_quizCurrentIndex] = QuizQuestion(
          questionId: current.questionId,
          questionText: current.questionText,
          questionSubText: current.questionSubText,
          options: current.options,
          correctOptionId: result.correctOptionId,
        );
        _quizAnswers.add(_QuizAnswer(
          questionId: current.questionId,
          selectedOptionId: optionId,
          isCorrect: result.isCorrect,
        ));
        _savingAnswer = false;
        _quizShowFeedback = true;
      });
      _advanceTimer = Timer(const Duration(seconds: 1), () {
        if (!_isCurrent) return;
        if (_quizCurrentIndex + 1 >= _quizQuestions.length) {
          unawaited(_handleQuizComplete());
        } else {
          setState(() {
            _quizCurrentIndex++;
            _quizSelectedOption = null;
            _quizShowFeedback = false;
          });
        }
      });
    } catch (error) {
      if (!_isCurrent) return;
      setState(() {
        _savingAnswer = false;
        _answerError = kanaSaveErrorMessage(error);
      });
    }
  }

  Future<void> _handleQuizComplete() async {
    if (!_isCurrent ||
        _phase != _Phase.quiz ||
        _completing ||
        _quizSessionId == null) {
      return;
    }
    setState(() {
      _completing = true;
      _completionError = null;
    });
    try {
      // Keep the successful receipt while retrying stage persistence: completing
      // the quiz again returns a replay with zero newly earned XP.
      final service = ref.read(kanaCompletionServiceProvider);
      if (_quizCompletion == null) {
        final result = await service.completeQuiz(sessionId: _quizSessionId!);
        if (!_isCurrent) return;
        _quizCompletion = result;
      }
      final stageId = _quizStageId;
      if (stageId == null) {
        throw const ApiException(message: '단계 정보를 확인하지 못했어요. 잠시 후 다시 시도해 주세요.');
      }
      await service.completeStage(
          stageId: stageId, quizScore: _quizCompletion!.accuracy);
      if (!_isCurrent) return;
      final correct = _quizAnswers.where((answer) => answer.isCorrect).length;
      final wrongIds = _quizAnswers
          .where((answer) => !answer.isCorrect)
          .map((answer) => answer.questionId)
          .toSet();
      final wrongCharacters =
          (ref.read(kanaCharactersProvider(kanaType)).value ??
                  <KanaCharacterModel>[])
              .where((character) => wrongIds.contains(character.id))
              .toList();
      setState(() {
        _quizCorrect = correct;
        _quizTotal = _quizAnswers.length;
        _xpEarned = _quizCompletion!.xpEarned;
        _completing = false;
        if (wrongCharacters.isNotEmpty) {
          _reviewCharacters = wrongCharacters;
          _reviewIndex = 0;
          _phase = _Phase.review;
        } else {
          _phase = _Phase.complete;
        }
      });
    } catch (error) {
      if (!_isCurrent) return;
      setState(() {
        _completing = false;
        _completionMayBeReplay =
            _quizCompletion == null || _completionMayBeReplay;
        _completionError = kanaSaveErrorMessage(error);
      });
    }
  }

  void _advanceReview() {
    if (!_isCurrent) return;
    if (_reviewIndex < _reviewCharacters.length - 1) {
      setState(() => _reviewIndex++);
    } else {
      setState(() => _phase = _Phase.complete);
    }
  }

  Future<void> _recordProgress(String kanaId) async {
    if (!_isCurrent) return;
    try {
      await ref
          .read(kanaRepositoryProvider)
          .updateProgress(kanaId: kanaId, learned: true);
      if (_isCurrent) ref.invalidate(dashboardProvider);
    } catch (error) {
      if (!mounted || !_isCurrent) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(kanaSaveErrorMessage(error))));
    }
  }
}

class _QuizAnswer {
  final String questionId;
  final String selectedOptionId;
  final bool isCorrect;

  _QuizAnswer({
    required this.questionId,
    required this.selectedOptionId,
    required this.isCorrect,
  });
}
