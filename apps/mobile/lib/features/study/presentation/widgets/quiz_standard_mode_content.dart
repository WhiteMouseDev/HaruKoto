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
    required this.count,
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
  final String count;
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
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                QuizHeader(
                  title: title,
                  count: count,
                  onBack: onBack,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: QuizProgressBar(
                    progress: progress,
                    streak: streak,
                    showStreak: answered,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FourChoiceQuiz(
                      question: question,
                      selectedOptionId: selectedOptionId,
                      answered: answered,
                      isCorrect: isCorrect,
                      showFurigana: showFurigana,
                      onSelect: onAnswer,
                    ),
                  ),
                ),
              ],
            ),
            if (answered)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: QuizFeedbackBar(
                  question: question,
                  isCorrect: isCorrect,
                  streak: streak,
                  isLastQuestion: isLastQuestion,
                  onNext: onNext,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
