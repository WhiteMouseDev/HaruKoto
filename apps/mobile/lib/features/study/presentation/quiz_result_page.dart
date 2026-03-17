import 'dart:async';
import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../../../core/constants/colors.dart';
import '../data/models/quiz_result_model.dart';
import '../providers/study_provider.dart';
import 'quiz_page.dart';
import 'widgets/result_score_display.dart';
import 'widgets/wrong_answer_list.dart';

class QuizResultPage extends ConsumerStatefulWidget {
  final QuizResultModel result;
  final String quizType;
  final String jlptLevel;
  final String sessionId;

  const QuizResultPage({
    super.key,
    required this.result,
    required this.quizType,
    required this.jlptLevel,
    required this.sessionId,
  });

  @override
  ConsumerState<QuizResultPage> createState() => _QuizResultPageState();
}

class _QuizResultPageState extends ConsumerState<QuizResultPage> {
  List<WrongAnswerModel> _wrongAnswers = [];
  final Set<String> _savedWords = {};
  bool _loadingWrong = true;
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    if (widget.result.accuracy >= 80) {
      _confettiController.play();
    }
    _loadWrongAnswers();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadWrongAnswers() async {
    if (widget.result.totalQuestions - widget.result.correctCount <= 0) {
      setState(() => _loadingWrong = false);
      return;
    }
    final repo = ref.read(studyRepositoryProvider);
    try {
      final answers = await repo.fetchWrongAnswersBySession(widget.sessionId);
      setState(() {
        _wrongAnswers = answers;
        _loadingWrong = false;
      });
    } catch (e, stackTrace) {
      unawaited(Sentry.captureException(e, stackTrace: stackTrace));
      setState(() => _loadingWrong = false);
    }
  }

  Future<void> _saveToWordbook(WrongAnswerModel item) async {
    if (_savedWords.contains(item.questionId)) return;
    final repo = ref.read(studyRepositoryProvider);
    try {
      await repo.addWord(
        word: item.word,
        reading: item.reading ?? item.word,
        meaningKo: item.meaningKo,
        source: 'QUIZ',
      );
      setState(() => _savedWords.add(item.questionId));
    } catch (e, stackTrace) {
      unawaited(Sentry.captureException(e, stackTrace: stackTrace));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('단어장에 저장하지 못했습니다')),
        );
      }
    }
  }

  Future<void> _saveAllToWordbook() async {
    final unsaved =
        _wrongAnswers.where((w) => !_savedWords.contains(w.questionId));
    for (final item in unsaved) {
      await _saveToWordbook(item);
    }
  }

  String get _resultMessage {
    if (widget.result.accuracy >= 80) return '훌륭해요!';
    if (widget.result.accuracy >= 50) return '잘 하셨어요!';
    return '다음엔 더 잘할 수 있어요!';
  }

  IconData get _resultIcon {
    if (widget.result.accuracy >= 80) return LucideIcons.partyPopper;
    if (widget.result.accuracy >= 50) return LucideIcons.thumbsUp;
    return LucideIcons.dumbbell;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = widget.result;
    final wrongCount = r.totalQuestions - r.correctCount;

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 24),

                // Icon & message
                Center(
                  child: Column(
                    children: [
                      Icon(
                        _resultIcon,
                        size: 56,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _resultMessage,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Score display
                ResultScoreDisplay(
                  accuracy: r.accuracy,
                  correct: r.correctCount,
                  total: r.totalQuestions,
                  xpEarned: r.xpEarned,
                  currentXp: r.currentXp,
                  xpForNext: r.xpForNext,
                ),
                const SizedBox(height: 16),

                // Wrong answers
                if (!_loadingWrong && _wrongAnswers.isNotEmpty)
                  WrongAnswerList(
                    wrongAnswers: _wrongAnswers,
                    quizType: widget.quizType,
                    savedWords: _savedWords,
                    onSaveToWordbook: _saveToWordbook,
                    onSaveAll: _saveAllToWordbook,
                  ),
                const SizedBox(height: 16),

                // Next recommendations
                if (wrongCount > 0) ...[
                  Text(
                    '다음에 이걸 해보세요',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Material(
                    color: AppColors.error(theme.brightness)
                        .withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.of(context, rootNavigator: true)
                            .pushReplacement(
                          quizRoute(QuizPage(
                            quizType: widget.quizType,
                            jlptLevel: widget.jlptLevel,
                            count: 10,
                            mode: 'review',
                          )),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.error(theme.brightness)
                                .withValues(alpha: 0.3),
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(LucideIcons.fileX,
                                    size: 16,
                                    color: AppColors.error(theme.brightness)),
                                const SizedBox(width: 8),
                                Text(
                                  '이번에 틀린 단어 복습',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$wrongCount개 단어',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '오답 복습 →',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.error(theme.brightness),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Action buttons
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        quizRoute(QuizPage(
                          quizType: widget.quizType,
                          jlptLevel: widget.jlptLevel,
                          count: 10,
                        )),
                      );
                    },
                    icon: const Icon(LucideIcons.rotateCcw, size: 16),
                    label:
                        const Text('한 번 더 도전', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    icon: const Icon(LucideIcons.home, size: 16),
                    label:
                        const Text('홈으로 돌아가기', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2,
              blastDirectionality: BlastDirectionality.explosive,
              maxBlastForce: 20,
              minBlastForce: 8,
              emissionFrequency: 0.05,
              numberOfParticles: 25,
              gravity: 0.1,
              colors: const [
                Color(0xFFFF6B6B),
                Color(0xFFFFD93D),
                Color(0xFF6BCB77),
                Color(0xFF4D96FF),
                Color(0xFFFF85B3),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
