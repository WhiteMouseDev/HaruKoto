import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/wordbook_entry_model.dart';
import 'package:harukoto_mobile/features/study/domain/study_repository.dart';
import 'package:harukoto_mobile/features/study/presentation/wordbook_page.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/wordbook_filter_chips.dart';
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

  testWidgets('empty wordbook uses the dedicated design and opens word entry',
      (tester) async {
    final repository = _WordbookRepository(entries: const []);
    await _pumpPage(tester, repository);

    expect(find.text('단어장'), findsOneWidget);
    expect(find.text('단어장에 단어가 없어요.'), findsOneWidget);
    expect(find.text('단어를 추가해 보세요!'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('단어 추가'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('뜻'), findsOneWidget);
  });

  testWidgets('initial error separates retry from the empty wordbook',
      (tester) async {
    final repository = _WordbookRepository(failFirstRead: true);
    await _pumpPage(tester, repository);

    expect(find.text('단어장을 불러올 수 없습니다.'), findsOneWidget);
    expect(find.text('네트워크 연결을 확인해 주세요.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('단어 추가'), findsNothing);

    await tester.tap(find.text('다시 시도하기'));
    await tester.pumpAndSettle();
    expect(repository.fetchCalls, 2);
    expect(find.text('旅行'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('filter with no rows keeps controls to clear the selection',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _WordbookRepository();
    await _pumpPage(tester, repository, dark: true, textScale: 2);

    final filters = find.byType(WordbookFilterChips);
    final manual = find.descendant(of: filters, matching: find.text('직접 추가'));
    await tester.ensureVisible(manual);
    await tester.tap(manual);
    await tester.pumpAndSettle();
    expect(find.text('검색 결과가 없어요'), findsOneWidget);
    expect(find.text('단어장에 단어가 없어요.'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);

    final all = find.descendant(of: filters, matching: find.text('전체'));
    await tester.ensureVisible(all);
    await tester.tap(all);
    await tester.pumpAndSettle();
    expect(find.text('旅行'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpPage(
  WidgetTester tester,
  _WordbookRepository repository, {
  bool dark = false,
  double textScale = 1,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [studyRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      theme: dark ? ThemeData.dark() : ThemeData.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: const WordbookPage(),
    ),
  ));
  await tester.pumpAndSettle();
}

class _WordbookRepository implements StudyRepository {
  _WordbookRepository({
    this.entries = _savedEntries,
    this.failFirstRead = false,
  });

  static const _savedEntries = [
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
  ];

  final List<WordbookEntryModel> entries;
  final bool failFirstRead;
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
    if (failFirstRead && fetchCalls == 1) {
      throw StateError('Temporary fixture error');
    }
    final results = filter == 'ALL'
        ? entries
        : entries.where((entry) => entry.source == filter).toList();
    return (
      entries: results,
      total: results.length,
      totalPages: 1,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
