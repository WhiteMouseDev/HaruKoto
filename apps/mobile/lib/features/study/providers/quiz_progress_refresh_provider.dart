import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/providers/home_provider.dart';
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
    if (!_ref.mounted) return;
    _ref.invalidate(incompleteQuizProvider);
    _ref.invalidate(smartPreviewProvider);
    // Saved answers contribute before the quiz is completed. Home remains
    // mounted under the quiz route, so it must reload on a saved-answer exit.
    _ref.invalidate(dashboardProvider);
  }
}
