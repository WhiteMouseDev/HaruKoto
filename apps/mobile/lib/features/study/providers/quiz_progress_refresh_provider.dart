import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'study_provider.dart';

final quizProgressRefreshProvider = Provider<QuizProgressRefresh>((ref) {
  return QuizProgressRefresh(ref);
});

/// Reload saved answers and the next quiz preview after leaving a quiz or
/// returning to the app. Home stays mounted underneath the quiz route.
class QuizProgressRefresh {
  const QuizProgressRefresh(this._ref);

  final Ref _ref;

  void refresh() {
    _ref.invalidate(incompleteQuizProvider);
    _ref.invalidate(smartPreviewProvider);
  }
}
