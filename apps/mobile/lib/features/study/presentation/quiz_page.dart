import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/quiz_settings_provider.dart';
import '../data/models/quiz_question_model.dart';
import '../providers/study_provider.dart';
import 'quiz_result_page.dart';
import 'widgets/four_choice_quiz.dart';
import 'widgets/matching_quiz.dart';
import 'widgets/cloze_quiz.dart';
import 'widgets/sentence_arrange_quiz.dart';
import 'widgets/typing_quiz.dart';
import 'widgets/quiz_progress_bar.dart';
import 'widgets/quiz_header.dart';
import 'widgets/quiz_feedback_bar.dart';

class QuizPage extends ConsumerStatefulWidget {
  final String quizType;
  final String jlptLevel;
  final int count;
  final String? mode;
  final String? resumeSessionId;

  const QuizPage({
    super.key,
    this.quizType = 'VOCABULARY',
    this.jlptLevel = 'N5',
    this.count = 10,
    this.mode,
    this.resumeSessionId,
  });

  @override
  ConsumerState<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends ConsumerState<QuizPage> {
  String? _sessionId;
  List<QuizQuestionModel> _questions = [];
  int _currentIndex = 0;
  String? _selectedOptionId;
  bool _answered = false;
  bool _isCorrect = false;
  bool _loading = true;
  int _streak = 0;
  String? _resolvedMode;
  Timer? _timer;
  int _timeSpent = 0;

  @override
  void initState() {
    super.initState();
    _resolvedMode = widget.mode;
    _initQuiz();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initQuiz() async {
    final repo = ref.read(studyRepositoryProvider);
    try {
      if (widget.resumeSessionId != null) {
        final data = await repo
            .resumeQuiz(widget.resumeSessionId!);
        setState(() {
          _sessionId = data.sessionId;
          _questions = data.questions;
          _currentIndex =
              data.answeredQuestionIds.length;
          if (data.quizType != null) {
            final modeMap = {
              'CLOZE': 'cloze',
              'SENTENCE_ARRANGE': 'arrange',
              'TYPING': 'typing',
              'MATCHING': 'matching',
            };
            if (modeMap.containsKey(data.quizType)) {
              _resolvedMode = modeMap[data.quizType];
            }
          }
        });
      } else {
        final data = await repo.startQuiz(
          quizType: widget.quizType,
          jlptLevel: widget.jlptLevel,
          count: widget.count,
          mode: widget.mode,
        );
        setState(() {
          _sessionId = data.sessionId;
          _questions = data.questions;
        });
      }
    } catch (e) {
      debugPrint('Failed to init quiz: $e');
    } finally {
      setState(() => _loading = false);
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timeSpent = 0;
    _timer = Timer.periodic(
        const Duration(seconds: 1), (_) {
      _timeSpent++;
    });
  }

  Future<void> _handleAnswer(String optionId) async {
    if (_answered || _sessionId == null) return;
    _timer?.cancel();

    final question = _questions[_currentIndex];
    final isCorrect =
        optionId == question.correctOptionId;

    setState(() {
      _selectedOptionId = optionId;
      _answered = true;
      _isCorrect = isCorrect;
      _streak = isCorrect ? _streak + 1 : 0;
    });

    final repo = ref.read(studyRepositoryProvider);
    repo.answerQuestion(
      sessionId: _sessionId!,
      questionId: question.questionId,
      selectedOptionId: optionId,
      isCorrect: isCorrect,
      timeSpentSeconds: _timeSpent,
      questionType: widget.quizType,
    );
  }

  Future<void> _handleNext() async {
    if (_currentIndex + 1 >= _questions.length) {
      await _completeQuiz();
      return;
    }

    setState(() {
      _currentIndex++;
      _selectedOptionId = null;
      _answered = false;
      _isCorrect = false;
    });
    _startTimer();
  }

  Future<void> _completeQuiz() async {
    if (_sessionId == null) return;
    final repo = ref.read(studyRepositoryProvider);
    try {
      final result =
          await repo.completeQuiz(_sessionId!);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => QuizResultPage(
            result: result,
            quizType: widget.quizType,
            jlptLevel: widget.jlptLevel,
            sessionId: _sessionId!,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Failed to complete quiz: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('퀴즈 결과 저장에 실패했어요.')),
        );
      }
    }
  }

  Future<bool> _onWillPop() async {
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('나가시겠어요?'),
        content: const Text('나가면 진행 상황이 저장돼요.'),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(true),
            child: const Text('나가기'),
          ),
        ],
      ),
    );
    return shouldPop ?? false;
  }

  String get _headerTitle => _resolvedMode == 'review'
      ? '오답 복습'
      : '${widget.jlptLevel} ${widget.quizType == 'VOCABULARY' ? '단어' : '문법'} 퀴즈';

  String get _headerCount =>
      '${_currentIndex + 1}/${_questions.length}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return _buildLoadingState(theme);
    }

    if (_questions.isEmpty) {
      return _buildEmptyState(theme);
    }

    final unanswered =
        _questions.sublist(_currentIndex);

    if (_resolvedMode == 'matching') {
      final showFurigana = ref.watch(quizSettingsProvider).showFurigana;
      return _buildSpecialMode(
        MatchingQuiz(
          questions: unanswered,
          showFurigana: showFurigana,
          onMatchResult: (qId, isCorrect) {
            _submitSpecialAnswer(
                qId, isCorrect, widget.quizType);
          },
          onComplete: _completeQuiz,
        ),
      );
    }

    if (_resolvedMode == 'cloze') {
      return _buildSpecialMode(
        ClozeQuiz(
          questions: unanswered,
          onAnswer: (qId, optionId, isCorrect) {
            _submitSpecialAnswer(
                qId, isCorrect, 'CLOZE',
                optionId: optionId);
          },
          onComplete: _completeQuiz,
        ),
      );
    }

    if (_resolvedMode == 'arrange') {
      return _buildSpecialMode(
        SentenceArrangeQuiz(
          questions: unanswered,
          onAnswer: (qId, isCorrect) {
            _submitSpecialAnswer(
                qId, isCorrect, 'SENTENCE_ARRANGE');
          },
          onComplete: _completeQuiz,
        ),
      );
    }

    if (_resolvedMode == 'typing') {
      return _buildSpecialMode(
        TypingQuiz(
          questions: unanswered,
          onAnswer: (qId, isCorrect) {
            _submitSpecialAnswer(
                qId, isCorrect, 'VOCABULARY');
          },
          onComplete: _completeQuiz,
        ),
      );
    }

    return _buildDefaultQuiz(theme);
  }

  void _submitSpecialAnswer(
    String qId,
    bool isCorrect,
    String questionType, {
    String? optionId,
  }) {
    if (_sessionId == null) return;
    final repo = ref.read(studyRepositoryProvider);
    final q = _questions
        .firstWhere((q) => q.questionId == qId);
    repo.answerQuestion(
      sessionId: _sessionId!,
      questionId: qId,
      selectedOptionId: optionId ??
          (isCorrect ? q.correctOptionId : 'wrong'),
      isCorrect: isCorrect,
      timeSpentSeconds: 0,
      questionType: questionType,
    );
  }

  Widget _buildPopScope({required Widget child}) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: child,
    );
  }

  Widget _buildSpecialMode(Widget quizWidget) {
    return _buildPopScope(
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              QuizHeader(
                title: _headerTitle,
                count: _headerCount,
                onBack: () async {
                  final shouldPop =
                      await _onWillPop();
                  if (shouldPop && mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: quizWidget,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
                color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              '퀴즈를 준비하고 있어요...',
              style:
                  theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface
                    .withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _resolvedMode == 'review'
                  ? Icons.celebration
                  : Icons.sentiment_dissatisfied,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              _resolvedMode == 'review'
                  ? '복습할 문제가 없어요!'
                  : '이 레벨의 콘텐츠를 준비하고 있어요',
              style:
                  theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () =>
                  Navigator.of(context).pop(),
              child: const Text('학습으로 돌아가기'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultQuiz(ThemeData theme) {
    final question = _questions[_currentIndex];
    final progress =
        (_currentIndex + 1) / _questions.length;

    return _buildPopScope(
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              QuizHeader(
                title: _headerTitle,
                count: _headerCount,
                onBack: () async {
                  final shouldPop =
                      await _onWillPop();
                  if (shouldPop && mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16),
                child: QuizProgressBar(
                  progress: progress,
                  streak: _streak,
                  showStreak: _answered,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(
                          horizontal: 16),
                  child: FourChoiceQuiz(
                    question: question,
                    selectedOptionId:
                        _selectedOptionId,
                    answered: _answered,
                    isCorrect: _isCorrect,
                    showFurigana: ref.watch(quizSettingsProvider).showFurigana,
                    onSelect: _handleAnswer,
                  ),
                ),
              ),
              if (_answered)
                QuizFeedbackBar(
                  question: question,
                  isCorrect: _isCorrect,
                  streak: _streak,
                  isLastQuestion:
                      _currentIndex + 1 >=
                          _questions.length,
                  onNext: _handleNext,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
