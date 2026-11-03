import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/wordbook_entry_model.dart';
import 'package:harukoto_mobile/features/study/domain/study_repository.dart';
import 'package:harukoto_mobile/features/study/presentation/wordbook_page.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/wordbook_loading_list.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';
import 'package:harukoto_mobile/shared/widgets/tts_play_button.dart';

void main() {
  testWidgets('opening the wordbook loads the saved conversation expression',
      (tester) async {
    final repository = _WordbookRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [studyRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: WordbookPage()),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(repository.fetchCalls, 1);
    expect(find.byType(WordbookLoadingList), findsNothing);
    expect(find.text('予約しています。'), findsOneWidget);
    expect(find.text('예약했어요.'), findsOneWidget);
    expect(find.text('旅行'), findsOneWidget);
    expect(find.text('りょこう'), findsOneWidget);
    // Wordbook rows do not expose vocabulary ids or audio URLs, even for
    // entries saved from a quiz. Do not offer playback with a private row id.
    expect(find.byType(TtsPlayButton), findsNothing);
  });
}

class _WordbookRepository implements StudyRepository {
  int fetchCalls = 0;

  @override
  Future<({List<WordbookEntryModel> entries, int total, int totalPages})>
      fetchWordbook({
    int page = 1,
    String sort = 'recent',
    String search = '',
    String filter = 'ALL',
    int limit = 20,
  }) async {
    fetchCalls++;
    return (
      entries: const [
        WordbookEntryModel(
          id: 'expression-id',
          word: '予約しています。',
          reading: '',
          meaningKo: '예약했어요.',
          source: 'CONVERSATION',
          createdAt: '2026-11-03T05:00:00Z',
        ),
        WordbookEntryModel(
          id: 'saved-quiz-row-id',
          word: '旅行',
          reading: 'りょこう',
          meaningKo: '여행',
          source: 'QUIZ',
          createdAt: '2026-11-03T05:00:00Z',
        ),
      ],
      total: 2,
      totalPages: 1,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
