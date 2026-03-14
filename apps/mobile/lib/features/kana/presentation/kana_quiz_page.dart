import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/sizes.dart';
import '../../../shared/widgets/app_error_retry.dart';
import '../../study/data/models/quiz_result_model.dart';
import '../../study/presentation/quiz_result_page.dart';
import '../data/models/kana_stage_model.dart';
import '../providers/kana_provider.dart';
import 'widgets/kana_quiz_content.dart';
import 'widgets/kana_quiz_master_result.dart';

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
  ConsumerState<KanaQuizPage> createState() =>
      _KanaQuizPageState();
}

class _KanaQuizPageState
    extends ConsumerState<KanaQuizPage> {
  bool _loading = true;
  String? _error;
  String? _sessionId;
  List<QuizQuestion> _questions = [];
  int _currentIndex = 0;
  String? _selectedOption;
  bool _showFeedback = false;
  final List<_Answer> _answers = [];
  KanaMasterResult? _masterResult;

  String get kanaType =>
      widget.type == 'katakana' ? 'KATAKANA' : 'HIRAGANA';
  String get label =>
      kanaType == 'HIRAGANA' ? '히라가나' : '가타카나';

  @override
  void initState() {
    super.initState();
    _startQuiz();
  }

  Future<void> _startQuiz() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(kanaRepositoryProvider);
      final res = await repo.startQuiz(
        kanaType: kanaType,
        quizMode: widget.mode,
        count: widget.isMaster ? 46 : 10,
      );

      if (res.sessionId == null ||
          res.questions.isEmpty) {
        setState(() {
          _error =
              res.message ?? '출제할 문제가 없습니다';
          _loading = false;
        });
      } else {
        setState(() {
          _sessionId = res.sessionId;
          _questions = res.questions;
          _currentIndex = 0;
          _selectedOption = null;
          _showFeedback = false;
          _answers.clear();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[KanaQuizPage] Failed to start quiz: $e');
      setState(() {
        _error = '퀴즈를 시작할 수 없습니다';
        _loading = false;
      });
    }
  }

  void _handleSelect(String optionId) {
    if (_showFeedback) return;
    final current = _questions[_currentIndex];

    setState(() {
      _selectedOption = optionId;
      _showFeedback = true;
    });

    final isCorrect =
        optionId == current.correctOptionId;
    _answers.add(_Answer(
      questionId: current.questionId,
      selectedOptionId: optionId,
      isCorrect: isCorrect,
    ));

    if (_sessionId != null) {
      ref.read(kanaRepositoryProvider).answerQuestion(
            sessionId: _sessionId!,
            questionId: current.questionId,
            selectedOptionId: optionId,
          );
    }

    Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      final nextIndex = _currentIndex + 1;
      if (nextIndex >= _questions.length) {
        _handleComplete();
      } else {
        setState(() {
          _currentIndex = nextIndex;
          _selectedOption = null;
          _showFeedback = false;
        });
      }
    });
  }

  Future<void> _handleComplete() async {
    final correct =
        _answers.where((a) => a.isCorrect).length;
    final total = _answers.length;

    if (_sessionId != null) {
      try {
        final res = await ref
            .read(kanaRepositoryProvider)
            .completeQuiz(sessionId: _sessionId!);

        if (widget.isMaster) {
          final accuracy =
              (correct / total * 100).round();
          setState(() {
            _masterResult = KanaMasterResult(
              correct: correct,
              total: total,
              accuracy: accuracy,
              xpEarned: res.xpEarned,
              passed: accuracy >= 90,
            );
          });
          return;
        }

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => QuizResultPage(
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
            ),
          );
        }
      } catch (e) {
        debugPrint('[KanaQuizPage] Failed to complete quiz: $e');
        if (mounted) context.go('/study/kana');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                    color: theme.colorScheme
                        .surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(
                        AppSizes.radiusSm),
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                Container(
                  width: MediaQuery.sizeOf(context)
                          .width *
                      0.75,
                  height: 200,
                  decoration: BoxDecoration(
                    color: theme.colorScheme
                        .surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(
                        AppSizes.cardRadius),
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
                    icon: const Icon(
                        LucideIcons.arrowLeft,
                        size: 20),
                    onPressed: () => context.pop(),
                    visualDensity:
                        VisualDensity.compact,
                  ),
                  Text(
                    widget.isMaster
                        ? '$label 마스터 퀴즈'
                        : '$label 퀴즈',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.md),
              Expanded(
                child: KanaQuizContent(
                  question: _questions.isNotEmpty
                      ? _questions[_currentIndex]
                      : null,
                  currentIndex: _currentIndex,
                  totalCount: _questions.length,
                  selectedOption: _selectedOption,
                  showFeedback: _showFeedback,
                  onSelect: _handleSelect,
                ),
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
