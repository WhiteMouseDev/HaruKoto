import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/recommendation_model.dart';
import '../quiz_launch.dart';
import '../wrong_answers_page.dart';
import 'recommendation_content.dart';
import 'recommendation_error_state.dart';

class RecommendTab extends StatelessWidget {
  final AsyncValue<RecommendationModel> recs;
  final VoidCallback onInvalidate;

  const RecommendTab({
    super.key,
    required this.recs,
    required this.onInvalidate,
  });

  @override
  Widget build(BuildContext context) {
    return recs.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => RecommendationErrorState(onRetry: onInvalidate),
      data: (data) => RecommendationContent(
        data: data,
        onStartReviewQuiz: () {
          openReviewQuiz(
            context,
            quizType: 'VOCABULARY',
            jlptLevel: 'N5',
          );
        },
        onStartNewWordsQuiz: () {
          openQuizPageForSession(
            context,
            quizType: 'VOCABULARY',
            jlptLevel: 'N5',
            count: 10,
          );
        },
        onOpenWrongAnswers: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const WrongAnswersPage(),
            ),
          );
        },
      ),
    );
  }
}
