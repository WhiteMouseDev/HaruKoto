import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models/lesson_models.dart';
import '../providers/study_provider.dart';

/// 레슨 상세: 대화문 읽기 → 퀴즈 풀기 → 결과 확인
class LessonPage extends ConsumerStatefulWidget {
  final String lessonId;
  const LessonPage({super.key, required this.lessonId});

  @override
  ConsumerState<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends ConsumerState<LessonPage> {
  // 단계: 0=대화문, 1=퀴즈, 2=결과
  int _phase = 0;
  int _currentQuestion = 0;
  final List<Map<String, dynamic>> _answers = [];
  LessonSubmitResultModel? _result;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(lessonDetailProvider(widget.lessonId));

    return PopScope(
      canPop: _phase == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _phase > 0) {
          setState(() {
            if (_phase == 2) {
              _phase = 0;
            } else {
              _phase--;
            }
          });
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
            icon: const Icon(Icons.close),
            onPressed: () => context.pop(),
          ),
        ),
        body: detailAsync.when(
          data: (detail) => _buildPhase(detail),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('오류: $e')),
        ),
      ),
    );
  }

  Widget _buildPhase(LessonDetailModel detail) {
    switch (_phase) {
      case 0:
        return _ReadingPhase(
          detail: detail,
          onNext: () => _startQuiz(detail),
        );
      case 1:
        return _QuizPhase(
          questions: detail.content.questions,
          currentIndex: _currentQuestion,
          onAnswer: (answer) => _handleAnswer(detail, answer),
        );
      case 2:
        return _ResultPhase(
          result: _result!,
          detail: detail,
          onRetry: () => _retry(),
          onDone: () => context.pop(),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _startQuiz(LessonDetailModel detail) async {
    // 레슨 시작 API 호출
    try {
      await ref.read(studyRepositoryProvider).startLesson(detail.id);
    } catch (_) {
      // 이미 시작된 경우 무시
    }
    setState(() {
      _phase = 1;
      _currentQuestion = 0;
      _answers.clear();
    });
  }

  void _handleAnswer(LessonDetailModel detail, Map<String, dynamic> answer) {
    _answers.add(answer);
    if (_currentQuestion < detail.content.questions.length - 1) {
      setState(() => _currentQuestion++);
    } else {
      _submitAnswers(detail);
    }
  }

  Future<void> _submitAnswers(LessonDetailModel detail) async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      final result = await ref
          .read(studyRepositoryProvider)
          .submitLesson(detail.id, _answers);
      setState(() {
        _result = result;
        _phase = 2;
        _submitting = false;
      });
      ref.invalidate(chaptersProvider('N5'));
    } catch (e) {
      setState(() => _submitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('제출 실패: $e')),
        );
      }
    }
  }

  void _retry() {
    setState(() {
      _phase = 0;
      _currentQuestion = 0;
      _answers.clear();
      _result = null;
    });
  }
}

// ── Phase 0: 대화문 읽기 ──

class _ReadingPhase extends StatelessWidget {
  final LessonDetailModel detail;
  final VoidCallback onNext;
  const _ReadingPhase({required this.detail, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reading = detail.content.reading;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 상황 설명
              if (reading.scene != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.place,
                          size: 16, color: theme.colorScheme.outline),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(reading.scene!,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.outline)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 대화문
              ...reading.script.map((line) => _DialogueBubble(line: line)),

              const SizedBox(height: 24),

              // 단어 목록
              if (detail.vocabItems.isNotEmpty) ...[
                Text('단어', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: detail.vocabItems
                      .map((v) => Chip(
                            label: Text('${v.word} (${v.reading})',
                                style: theme.textTheme.bodySmall),
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
              ],

              // 문법
              if (detail.grammarItems.isNotEmpty) ...[
                Text('문법', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                ...detail.grammarItems.map((g) => Card(
                      child: ListTile(
                        title: Text(g.pattern,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(g.meaningKo),
                      ),
                    )),
              ],
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onNext,
                icon: const Icon(Icons.quiz),
                label: const Text('확인 문제 풀기'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DialogueBubble extends StatelessWidget {
  final ScriptLineModel line;
  const _DialogueBubble({required this.line});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(line.speaker,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.text,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontSize: 18, height: 1.5)),
                if (line.translation != null) ...[
                  const SizedBox(height: 4),
                  Text(line.translation!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Phase 1: 퀴즈 ──

class _QuizPhase extends StatelessWidget {
  final List<LessonQuestionModel> questions;
  final int currentIndex;
  final ValueChanged<Map<String, dynamic>> onAnswer;
  const _QuizPhase({
    required this.questions,
    required this.currentIndex,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = questions[currentIndex];

    return Column(
      children: [
        // 진행 바
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text('${currentIndex + 1}/${questions.length}',
                  style: theme.textTheme.bodySmall),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (currentIndex + 1) / questions.length,
                    minHeight: 6,
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: q.type == 'SENTENCE_REORDER'
              ? _SentenceReorderQuiz(question: q, onAnswer: onAnswer)
              : _MultipleChoiceQuiz(question: q, onAnswer: onAnswer),
        ),
      ],
    );
  }
}

class _MultipleChoiceQuiz extends StatefulWidget {
  final LessonQuestionModel question;
  final ValueChanged<Map<String, dynamic>> onAnswer;
  const _MultipleChoiceQuiz({required this.question, required this.onAnswer});

  @override
  State<_MultipleChoiceQuiz> createState() => _MultipleChoiceQuizState();
}

class _MultipleChoiceQuizState extends State<_MultipleChoiceQuiz> {
  String? _selected;
  late List<QuizOptionModel> _shuffledOptions;

  @override
  void initState() {
    super.initState();
    _shuffleOptions();
  }

  @override
  void didUpdateWidget(covariant _MultipleChoiceQuiz oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question.order != widget.question.order) {
      _selected = null;
      _shuffleOptions();
    }
  }

  void _shuffleOptions() {
    _shuffledOptions = List.of(widget.question.options ?? [])
      ..shuffle(Random());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.question.prompt,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          ..._shuffledOptions.map((opt) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _selected != null ? null : () => _select(opt.id),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      side: BorderSide(
                        color: _selected == opt.id
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                      backgroundColor: _selected == opt.id
                          ? theme.colorScheme.primaryContainer
                          : null,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(opt.text, style: theme.textTheme.bodyLarge),
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  void _select(String id) {
    setState(() => _selected = id);
    Future.delayed(const Duration(milliseconds: 400), () {
      widget.onAnswer({
        'order': widget.question.order,
        'selectedAnswer': _selected,
        'responseMs': 0,
      });
    });
  }
}

class _SentenceReorderQuiz extends StatefulWidget {
  final LessonQuestionModel question;
  final ValueChanged<Map<String, dynamic>> onAnswer;
  const _SentenceReorderQuiz({required this.question, required this.onAnswer});

  @override
  State<_SentenceReorderQuiz> createState() => _SentenceReorderQuizState();
}

class _SentenceReorderQuizState extends State<_SentenceReorderQuiz> {
  late List<String> _available;
  final List<String> _selected = [];

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(covariant _SentenceReorderQuiz oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question.order != widget.question.order) {
      _reset();
    }
  }

  void _reset() {
    _available = List.of(widget.question.tokens ?? [])..shuffle(Random());
    _selected.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.question.prompt,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),

          // 선택된 토큰
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selected
                  .map((t) => ActionChip(
                        label: Text(t, style: const TextStyle(fontSize: 16)),
                        onPressed: () {
                          setState(() {
                            _selected.remove(t);
                            _available.add(t);
                          });
                        },
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),

          // 남은 토큰
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _available
                .map((t) => ActionChip(
                      label: Text(t, style: const TextStyle(fontSize: 16)),
                      onPressed: () {
                        setState(() {
                          _available.remove(t);
                          _selected.add(t);
                        });
                        // 전부 선택하면 자동 제출
                        if (_available.isEmpty) {
                          Future.delayed(const Duration(milliseconds: 400), () {
                            widget.onAnswer({
                              'order': widget.question.order,
                              'submittedOrder': List<String>.from(_selected),
                              'responseMs': 0,
                            });
                          });
                        }
                      },
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ── Phase 2: 결과 ──

class _ResultPhase extends StatelessWidget {
  final LessonSubmitResultModel result;
  final LessonDetailModel detail;
  final VoidCallback onRetry;
  final VoidCallback onDone;
  const _ResultPhase({
    required this.result,
    required this.detail,
    required this.onRetry,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = result.scoreTotal > 0
        ? (result.scoreCorrect / result.scoreTotal * 100).round()
        : 0;
    final isPerfect = result.scoreCorrect == result.scoreTotal;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 24),
              Center(
                child: Text(
                  isPerfect ? '🎉' : '📝',
                  style: const TextStyle(fontSize: 48),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  '$score%',
                  style: theme.textTheme.displaySmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Center(
                child: Text(
                  '${result.scoreCorrect}/${result.scoreTotal} 정답',
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
              const SizedBox(height: 24),

              // 문제별 결과
              ...result.results.map((r) {
                final q = detail.content.questions.firstWhere(
                  (q) => q.order == r.order,
                  orElse: () => detail.content.questions.first,
                );
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      r.isCorrect ? Icons.check_circle : Icons.cancel,
                      color: r.isCorrect ? Colors.green : Colors.red,
                    ),
                    title: Text(q.prompt, style: theme.textTheme.bodyMedium),
                    subtitle: r.explanation != null
                        ? Text(r.explanation!,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.outline))
                        : null,
                  ),
                );
              }),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onRetry,
                    child: const Text('다시 풀기'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: onDone,
                    child: const Text('완료'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
