import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/sizes.dart';
import '../data/models/kana_character_model.dart';
import '../data/models/kana_stage_model.dart';
import '../providers/kana_provider.dart';
import 'widgets/stage_intro.dart';
import 'widgets/stage_practice.dart';
import 'widgets/stage_quiz.dart';
import 'widgets/stage_review.dart';
import 'widgets/stage_complete.dart';

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

  String get kanaType =>
      widget.type == 'katakana' ? 'KATAKANA' : 'HIRAGANA';

  @override
  Widget build(BuildContext context) {
    final stagesAsync = ref.watch(kanaStagesProvider(kanaType));
    final charsAsync = ref.watch(kanaCharactersProvider(kanaType));
    final theme = Theme.of(context);

    final isLoading =
        stagesAsync.isLoading || charsAsync.isLoading;
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
                    borderRadius: BorderRadius.circular(
                        AppSizes.radiusSm),
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color:
                          theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(
                          AppSizes.cardRadius),
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
    final stage = stages
        .where((s) => s.stageNumber == widget.stageNumber)
        .firstOrNull;

    if (stage == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('존재하지 않는 단계입니다.',
                    style: theme.textTheme.bodyLarge),
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

    final stageChars = allChars
        .where((c) => stage.characters.contains(c.character))
        .toList();

    if (stageChars.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('이 단계의 문자를 불러올 수 없습니다.',
                    style: theme.textTheme.bodyLarge),
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
                    icon: const Icon(
                        LucideIcons.arrowLeft, size: 20),
                    onPressed: () => context.pop(),
                    visualDensity: VisualDensity.compact,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stage ${widget.stageNumber}: ${stage.title}',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          stage.description,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(
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
                child: _buildPhaseContent(
                    context, stage, stageChars, theme),
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
            _recordProgress(stageChars[_introIndex].id);
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
            _recordProgress(char.id);
            _advancePractice(stageChars);
          },
          onDontKnow: () => _advancePractice(stageChars),
        );
      case _Phase.quiz:
        return StageQuiz(
          question: _quizQuestions.isNotEmpty
              ? _quizQuestions[_quizCurrentIndex]
              : null,
          currentIndex: _quizCurrentIndex,
          totalCount: _quizQuestions.length,
          selectedOption: _quizSelectedOption,
          showFeedback: _quizShowFeedback,
          onSelect: (optionId) => _handleQuizSelect(
              optionId, _quizQuestions[_quizCurrentIndex]),
        );
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
          kanaType: widget.type,
        );
    }
  }

  void _advancePractice(List<KanaCharacterModel> chars) {
    if (_practiceIndex < chars.length - 1) {
      setState(() => _practiceIndex++);
    } else {
      _startQuiz();
    }
  }

  Future<void> _startQuiz() async {
    try {
      final repo = ref.read(kanaRepositoryProvider);
      final res = await repo.startQuiz(
        kanaType: kanaType,
        stageNumber: widget.stageNumber,
        quizMode: 'recognition',
        count: 5,
      );
      if (res.sessionId != null && res.questions.isNotEmpty) {
        setState(() {
          _quizSessionId = res.sessionId;
          _quizQuestions = res.questions;
          _quizCurrentIndex = 0;
          _quizSelectedOption = null;
          _quizShowFeedback = false;
          _quizAnswers.clear();
          _phase = _Phase.quiz;
        });
      } else {
        setState(() => _phase = _Phase.complete);
      }
    } catch (e) {
      debugPrint('[KanaStagePage] Failed to start quiz: $e');
      setState(() => _phase = _Phase.complete);
    }
  }

  void _handleQuizSelect(
      String optionId, QuizQuestion current) {
    if (_quizShowFeedback) return;

    setState(() {
      _quizSelectedOption = optionId;
      _quizShowFeedback = true;
    });

    final isCorrect = optionId == current.correctOptionId;
    _quizAnswers.add(_QuizAnswer(
      questionId: current.questionId,
      selectedOptionId: optionId,
      isCorrect: isCorrect,
    ));

    if (_quizSessionId != null) {
      ref.read(kanaRepositoryProvider).answerQuestion(
            sessionId: _quizSessionId!,
            questionId: current.questionId,
            selectedOptionId: optionId,
          );
    }

    Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      final nextIndex = _quizCurrentIndex + 1;
      if (nextIndex >= _quizQuestions.length) {
        _handleQuizComplete();
      } else {
        setState(() {
          _quizCurrentIndex = nextIndex;
          _quizSelectedOption = null;
          _quizShowFeedback = false;
        });
      }
    });
  }

  Future<void> _handleQuizComplete() async {
    final correct =
        _quizAnswers.where((a) => a.isCorrect).length;
    final total = _quizAnswers.length;
    final wrongIds = _quizAnswers
        .where((a) => !a.isCorrect)
        .map((a) => a.questionId)
        .toList();

    setState(() {
      _quizCorrect = correct;
      _quizTotal = total;
    });

    if (_quizSessionId != null) {
      try {
        final res = await ref
            .read(kanaRepositoryProvider)
            .completeQuiz(sessionId: _quizSessionId!);
        setState(() => _xpEarned = res.xpEarned);
      } catch (e) {
        debugPrint('[KanaStagePage] Failed to complete quiz: $e');
      }
    }

    final stagesAsync =
        ref.read(kanaStagesProvider(kanaType));
    final stages = stagesAsync.value ?? [];
    final stage = stages
        .where((s) => s.stageNumber == widget.stageNumber)
        .firstOrNull;
    if (stage != null) {
      final score = (correct / total * 100).round();
      ref.read(kanaRepositoryProvider).completeStage(
            stageId: stage.id,
            quizScore: score,
          );
    }

    if (wrongIds.isNotEmpty) {
      final charsAsync =
          ref.read(kanaCharactersProvider(kanaType));
      final allChars = charsAsync.value ?? [];
      final wrongChars = allChars
          .where((c) => wrongIds.contains(c.id))
          .toList();
      if (wrongChars.isNotEmpty) {
        setState(() {
          _reviewCharacters = wrongChars;
          _reviewIndex = 0;
          _phase = _Phase.review;
        });
        return;
      }
    }

    setState(() => _phase = _Phase.complete);
  }

  void _advanceReview() {
    if (_reviewIndex < _reviewCharacters.length - 1) {
      setState(() => _reviewIndex++);
    } else {
      setState(() => _phase = _Phase.complete);
    }
  }

  void _recordProgress(String kanaId) {
    ref
        .read(kanaRepositoryProvider)
        .updateProgress(kanaId: kanaId, learned: true);
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
