import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/auth/current_account_provider.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/app_error_retry.dart';
import '../../study/data/models/quiz_result_model.dart';
import '../../study/presentation/quiz_result_page.dart';
import '../data/models/kana_stage_model.dart';
import '../providers/kana_provider.dart';
import '../providers/kana_completion_service.dart';
import 'widgets/kana_quiz_content.dart';
import 'widgets/kana_quiz_master_result.dart';
import 'widgets/kana_save_status.dart';

class KanaQuizPage extends ConsumerStatefulWidget {
  final String type;
  final String mode;
  final bool isMaster;

  const KanaQuizPage({
    super.key,
    required this.type,
    this.mode = 'recognition',
    this.isMaster = false,
  });

  @override
  ConsumerState<KanaQuizPage> createState() => _KanaQuizPageState();
}

class _KanaQuizPageState extends ConsumerState<KanaQuizPage> {
  bool _loading = false;
  late final String? _owner;
  bool _savingAnswer = false;
  bool _completing = false;
  String? _answerError;
  String? _completionError;
  bool _completionMayBeReplay = false;
  Timer? _advanceTimer;
  String? _error;
  String? _sessionId;
  List<QuizQuestion> _questions = [];
  int _currentIndex = 0;
  String? _selectedOption;
  bool _showFeedback = false;
  final List<_Answer> _answers = [];
  KanaMasterResult? _masterResult;

  String get kanaType => widget.type == 'katakana' ? 'KATAKANA' : 'HIRAGANA';
  String get label => kanaType == 'HIRAGANA' ? '히라가나' : '가타카나';

  @override
  void initState() {
    super.initState();
    _owner = ref.read(currentAccountReaderProvider)();
    _startQuiz();
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

  Future<void> _startQuiz() async {
    if (!_isCurrent || _loading || _sessionId != null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(kanaRepositoryProvider).startQuiz(
            kanaType: kanaType,
            quizMode: widget.mode,
            count: widget.isMaster ? 46 : 10,
          );
      if (!_isCurrent) return;
      if (res.sessionId == null || res.questions.isEmpty) {
        throw const ApiException(message: '출제할 문제가 없어요. 잠시 후 다시 시도해 주세요.');
      }
      setState(() {
        _sessionId = res.sessionId;
        _questions = List.of(res.questions);
        _currentIndex = 0;
        _selectedOption = null;
        _showFeedback = false;
        _answers.clear();
        _loading = false;
      });
    } catch (error) {
      if (!_isCurrent) return;
      setState(() {
        _error = kanaSaveErrorMessage(error);
        _loading = false;
      });
    }
  }

  Future<void> _handleSelect(String optionId) async {
    if (!_isCurrent ||
        _showFeedback ||
        _selectedOption != null ||
        _completing) {
      return;
    }
    setState(() => _selectedOption = optionId);
    await _saveAnswer();
  }

  Future<void> _saveAnswer() async {
    if (!_isCurrent ||
        _savingAnswer ||
        _showFeedback ||
        _sessionId == null ||
        _selectedOption == null) {
      return;
    }
    final current = _questions[_currentIndex];
    final optionId = _selectedOption!;
    setState(() {
      _savingAnswer = true;
      _answerError = null;
    });
    try {
      final result =
          await ref.read(kanaCompletionServiceProvider).answerQuestion(
                sessionId: _sessionId!,
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
        _questions[_currentIndex] = QuizQuestion(
          questionId: current.questionId,
          questionText: current.questionText,
          questionSubText: current.questionSubText,
          options: current.options,
          correctOptionId: result.correctOptionId,
        );
        _answers.add(_Answer(
          questionId: current.questionId,
          selectedOptionId: optionId,
          isCorrect: result.isCorrect,
        ));
        _savingAnswer = false;
        _showFeedback = true;
      });
      _advanceTimer = Timer(const Duration(seconds: 1), () {
        if (!_isCurrent) return;
        if (_currentIndex + 1 >= _questions.length) {
          unawaited(_handleComplete());
        } else {
          setState(() {
            _currentIndex++;
            _selectedOption = null;
            _showFeedback = false;
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

  Future<void> _handleComplete() async {
    if (!_isCurrent ||
        _masterResult != null ||
        _completing ||
        _sessionId == null) {
      return;
    }
    setState(() {
      _completing = true;
      _completionError = null;
    });
    try {
      final res = await ref
          .read(kanaCompletionServiceProvider)
          .completeQuiz(sessionId: _sessionId!);
      if (!mounted || !_isCurrent) return;
      final correct = _answers.where((answer) => answer.isCorrect).length;
      final total = _answers.length;
      if (widget.isMaster) {
        setState(() {
          _completing = false;
          _masterResult = KanaMasterResult(
            correct: correct,
            total: total,
            accuracy: res.accuracy,
            xpEarned: res.xpEarned,
            passed: res.accuracy >= 90,
            rewardConfirmed: !_completionMayBeReplay || res.xpEarned > 0,
          );
        });
        return;
      }
      unawaited(Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
        builder: (_) => QuizResultPage(
          rewardConfirmed: !_completionMayBeReplay || res.xpEarned > 0,
          result: QuizResultModel(
            correctCount: correct,
            totalQuestions: total,
            accuracy: res.accuracy,
            xpEarned: res.xpEarned,
            currentXp: res.currentXp,
            xpForNext: res.xpForNext,
            level: res.level,
            events: res.events,
          ),
          quizType: 'KANA',
          jlptLevel: 'N5',
          sessionId: _sessionId!,
        ),
      )));
    } catch (error) {
      if (!_isCurrent) return;
      setState(() {
        _completing = false;
        _completionMayBeReplay = true;
        _completionError = kanaSaveErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(currentAccountIdProvider);
    final theme = Theme.of(context);
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

    if (_loading) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                Container(
                  width: MediaQuery.sizeOf(context).width * 0.75,
                  height: 200,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: AppErrorRetry(
          onRetry: _startQuiz,
          message: _error,
        ),
      );
    }

    if (widget.isMaster && _masterResult != null) {
      return KanaQuizMasterResultView(
        label: label,
        result: _masterResult!,
        onRetry: () {
          setState(() {
            _masterResult = null;
            _sessionId = null;
            _questions = [];
            _completionError = null;
            _completionMayBeReplay = false;
          });
          _startQuiz();
        },
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
                  Text(
                    widget.isMaster ? '$label 마스터 퀴즈' : '$label 퀴즈',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.md),
              Expanded(
                child: SingleChildScrollView(
                    child: Column(children: [
                  KanaQuizContent(
                    question: _questions.isNotEmpty
                        ? _questions[_currentIndex]
                        : null,
                    currentIndex: _currentIndex,
                    totalCount: _questions.length,
                    selectedOption: _selectedOption,
                    showFeedback: _showFeedback,
                    locked: _selectedOption != null ||
                        _completing ||
                        _completionError != null,
                    onSelect: _handleSelect,
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
                      label:
                          _completing ? '퀴즈 결과를 저장하고 있어요' : '퀴즈 결과를 저장하지 못했어요',
                      error: _completionError,
                      onRetry: _completing ? null : _handleComplete,
                      retryLabel: '결과 저장 다시 시도',
                    ),
                ])),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Answer {
  final String questionId;
  final String selectedOptionId;
  final bool isCorrect;

  _Answer({
    required this.questionId,
    required this.selectedOptionId,
    required this.isCorrect,
  });
}
