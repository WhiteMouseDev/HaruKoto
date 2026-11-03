import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../study/domain/study_repository.dart';
import '../../study/providers/study_provider.dart';

final conversationExpressionServiceProvider =
    Provider<ConversationExpressionService>(
  (ref) => ConversationExpressionService(ref.watch(studyRepositoryProvider)),
);

class ConversationExpressionService {
  const ConversationExpressionService(this._repository);

  final StudyRepository _repository;

  /// Avoid replacing an existing wordbook meaning or personal note.
  /// Returns false when the exact expression is already in the wordbook.
  Future<bool> save(
      {required String expression, required String meaning}) async {
    final existing = await _repository.fetchWordbook(
      search: expression,
      limit: 100,
    );
    if (existing.entries.any((entry) => entry.word == expression)) {
      return false;
    }
    await _repository.addWord(
      word: expression,
      reading: '',
      meaningKo: meaning,
      source: 'CONVERSATION',
      preserveExisting: true,
    );
    return true;
  }
}
