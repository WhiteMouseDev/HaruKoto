import 'package:flutter/material.dart';

import '../../data/models/quiz_question_model.dart';
import 'four_choice_quiz.dart';
import 'quiz_feedback_bar.dart';
import 'quiz_header.dart';
import 'quiz_progress_bar.dart';

class QuizStandardModeContent extends StatelessWidget {
  const QuizStandardModeContent({
    super.key,
    required this.title,
    required this.currentQuestion,
    required this.totalQuestions,
    required this.question,
    required this.progress,
    required this.streak,
    required this.selectedOptionId,
    required this.answered,
    required this.isCorrect,
    required this.isLastQuestion,
    required this.showFurigana,
    required this.onBack,
    required this.onAnswer,
    required this.onNext,
  });

  final String title;
  final int currentQuestion;
  final int totalQuestions;
  final QuizQuestionModel question;
  final double progress;
  final int streak;
  final String? selectedOptionId;
  final bool answered;
  final bool isCorrect;
  final bool isLastQuestion;
  final bool showFurigana;
  final VoidCallback onBack;
  final ValueChanged<String> onAnswer;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final promptInset =
        (MediaQuery.sizeOf(context).height - 650).clamp(20.0, 100.0);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            QuizHeader(title: title, onBack: onBack),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: QuizProgressBar(
                progress: progress,
                currentQuestion: currentQuestion,
                totalQuestions: totalQuestions,
                streak: streak,
                showStreak: answered,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: ValueKey('quiz-options-${question.questionId}'),
                padding: EdgeInsets.fromLTRB(20, promptInset, 20, 16),
                child: FourChoiceQuiz(
                  question: question,
                  questionNumber: currentQuestion,
                  selectedOptionId: selectedOptionId,
                  answered: answered,
                  isCorrect: isCorrect,
                  showFurigana: showFurigana,
                  onSelect: onAnswer,
                ),
              ),
            ),
            QuizFeedbackBar(
              question: question,
              answered: answered,
              isCorrect: isCorrect,
              isLastQuestion: isLastQuestion,
              onNext: onNext,
            ),
          ],
        ),
      ),
    );
  }
}
