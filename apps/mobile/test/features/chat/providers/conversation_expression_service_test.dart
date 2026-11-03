import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/providers/conversation_expression_service.dart';
import 'package:harukoto_mobile/features/study/domain/study_repository.dart';
import 'package:harukoto_mobile/features/study/data/models/wordbook_entry_model.dart';

void main() {
  test(
      'new expression requests atomic preservation of an existing personal entry',
      () async {
    final repository = _WordbookRepository();
    expect(
        await ConversationExpressionService(repository)
            .save(expression: '予約しています。', meaning: '예약했어요'),
        isTrue);
    expect(repository.fetchCalls, 1);
    expect(repository.savedWord, '予約しています。');
    expect(repository.source, 'CONVERSATION');
    expect(repository.preserveExisting, isTrue);
  });
  test('exact existing expression is acknowledged without overwriting it',
      () async {
    final repository = _WordbookRepository()..existing = true;
    expect(
        await ConversationExpressionService(repository)
            .save(expression: '予約しています。', meaning: '다른 뜻'),
        isFalse);
    expect(repository.savedWord, isNull);
  });
}

class _WordbookRepository implements StudyRepository {
  bool existing = false;
  int fetchCalls = 0;
  String? savedWord;
  String? source;
  bool? preserveExisting;
  @override
  Future<({List<WordbookEntryModel> entries, int total, int totalPages})>
      fetchWordbook(
          {int page = 1,
          String sort = 'recent',
          String search = '',
          String filter = 'ALL',
          int limit = 20}) async {
    fetchCalls++;
    return (
      entries: existing
          ? [
              const WordbookEntryModel(
                  id: '1',
                  word: '予約しています。',
                  reading: 'my-reading',
                  meaningKo: 'my-meaning',
                  source: 'MANUAL',
                  note: 'personal-note',
                  createdAt: '2026-11-03')
            ]
          : <WordbookEntryModel>[],
      total: existing ? 1 : 0,
      totalPages: 200
    );
  }

  @override
  Future<void> addWord(
      {required String word,
      required String reading,
      required String meaningKo,
      String source = 'MANUAL',
      String? note,
      bool preserveExisting = false}) async {
    savedWord = word;
    this.source = source;
    this.preserveExisting = preserveExisting;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
