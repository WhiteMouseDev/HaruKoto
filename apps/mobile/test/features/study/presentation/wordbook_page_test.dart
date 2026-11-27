import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/core/network/api_exception.dart';
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
    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(find.text('뜻'), findsOneWidget);
    expect(find.textContaining('메모'), findsNothing);
  });

  testWidgets(
      'add form validates whitespace and falls back to word for reading',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final repository = _WordbookRepository(entries: const []);
    await _pumpPage(tester, repository, dark: true, textScale: 1.5);
    await tester.tap(find.text('단어 추가'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    final save = find.widgetWithText(FilledButton, '추가');
    await tester.ensureVisible(fields.at(0));
    await tester.enterText(fields.at(0), '  ');
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repository.added, isNull);
    expect(find.text('단어를 입력해 주세요.'), findsOneWidget);
    expect(find.text('뜻을 입력해 주세요.'), findsOneWidget);
    await tester.ensureVisible(fields.at(0));
    await tester.enterText(fields.at(0), ' 食べる ');
    await tester.ensureVisible(fields.at(2));
    await tester.enterText(fields.at(2), ' 먹다 ');
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repository.added, ('食べる', '食べる', '먹다'));
    expect(find.byType(AlertDialog), findsNothing);
    expect(repository.fetchCalls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'detail shows the supplied example and saved note for quiz entries',
      (tester) async {
    final repository = _WordbookRepository();
    await _pumpPage(tester, repository);
    await tester.tap(find.text('旅行'));
    await tester.pumpAndSettle();

    expect(repository.openedIds, ['saved-quiz-row-id']);
    expect(find.text('단어장'), findsOneWidget);
    expect(find.text('旅行'), findsOneWidget);
    expect(find.text('여행'), findsOneWidget);
    expect(find.text('旅行に行きます。'), findsOneWidget);
    expect(find.text('여행을 갑니다.'), findsOneWidget);
    expect(find.text('다시 복습하기'), findsOneWidget);
    expect(find.text('수정'), findsNothing);
    expect(find.text('삭제'), findsOneWidget);
  });

  testWidgets(
      'editing uses three fields, retries a duplicate, and refreshes the filtered list',
      (tester) async {
    final repository =
        _WordbookRepository(entries: [_manualEntry], duplicateFirstEdit: true);
    await _pumpPage(tester, repository);
    final filters = find.byType(WordbookFilterChips);
    await tester
        .tap(find.descendant(of: filters, matching: find.text('직접 추가')));
    await tester.enterText(find.byType(TextField), '연습');
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pumpAndSettle();
    await tester.tap(find.text('練習'));
    await tester.pumpAndSettle();
    expect(find.text('예문'), findsNothing);
    expect(find.text('메모'), findsNothing);
    await tester.tap(find.text('수정'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(3));
    expect(tester.widget<TextFormField>(fields.first).controller?.text, '練習');
    expect(find.textContaining('메모'), findsNothing);
    await tester.enterText(fields.first, ' 勉強 ');
    await tester.enterText(fields.at(1), ' ');
    final save = find.widgetWithText(FilledButton, '저장');
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('이미 단어장에 있는 단어예요.'), findsOneWidget);
    expect(repository.edits, [('manual-id', '勉強', '勉強', '연습')]);
    repository.pendingEdit = Completer<void>();
    await tester.tap(save);
    await tester.tap(save);
    await tester.pump();
    expect(find.text('저장 중'), findsOneWidget);
    expect(repository.edits.length, 2);
    repository.pendingEdit!.complete();
    await tester.pumpAndSettle();
    expect(find.text('단어장'), findsOneWidget);
    expect(find.text('勉強'), findsNWidgets(2));
    expect(repository.openedIds, ['manual-id', 'manual-id']);
    await tester.tap(find.text('勉強').first);
    await tester.pumpAndSettle();
    expect(find.text('단어장'), findsOneWidget);
    expect(find.text('勉強'), findsNWidgets(2));
    expect(find.text('수정'), findsNothing);
    expect(repository.lastFilter, 'MANUAL');
    expect(repository.lastSearch, '연습');
  });

  testWidgets('detail delete confirms then refreshes the list', (tester) async {
    final repository = _WordbookRepository(entries: [_manualEntry]);
    await _pumpPage(tester, repository);
    await tester.tap(find.text('練習'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(find.text('단어를 삭제할까요?'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(repository.deletedIds, isEmpty);
    expect(find.text('단어장'), findsOneWidget);
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('삭제')),
    );
    await tester.pumpAndSettle();
    expect(repository.deletedIds, ['manual-id']);
    expect(repository.fetchCalls, 2);
    expect(find.text('단어장에 단어가 없어요.'), findsOneWidget);
  });

  testWidgets('a detail read failure can be retried then collapsed',
      (tester) async {
    final repository = _WordbookRepository(
      detailError: const ApiException(message: 'offline'),
    );
    await _pumpPage(tester, repository);
    await tester.tap(find.text('旅行'));
    await tester.pumpAndSettle();
    expect(find.text('단어를 불러올 수 없어요.'), findsOneWidget);
    await tester.tap(find.text('다시 시도하기'));
    await tester.pumpAndSettle();
    expect(repository.openedIds, ['saved-quiz-row-id', 'saved-quiz-row-id']);
    expect(find.text('旅行に行きます。'), findsOneWidget);
    await tester.tap(find.text('旅行'));
    await tester.pumpAndSettle();
    expect(find.text('予約しています。'), findsOneWidget);
    expect(find.text('旅行に行きます。'), findsNothing);
  });

  testWidgets('a missing detail is inline and opening another row replaces it',
      (tester) async {
    final repository = _WordbookRepository(
      detailError: const ApiException(message: 'missing', statusCode: 404),
    );
    await _pumpPage(tester, repository);
    await tester.tap(find.text('旅行'));
    await tester.pumpAndSettle();
    expect(find.text('저장된 단어를 찾을 수 없어요.'), findsOneWidget);
    expect(find.text('다시 시도하기'), findsNothing);
    await tester.tap(find.text('予約しています。'));
    await tester.pumpAndSettle();
    expect(find.text('저장된 단어를 찾을 수 없어요.'), findsNothing);
    expect(find.text('삭제'), findsOneWidget);
    expect(find.text('수정'), findsNothing);
    expect(repository.openedIds, ['saved-quiz-row-id', 'expression-id']);
  });

  testWidgets('wordbook sort resets pagination and keeps the filtered count',
      (tester) async {
    final repository = _WordbookRepository(serverTotal: 42, serverPages: 3);
    await _pumpPage(tester, repository);
    final filters = find.byType(WordbookFilterChips);
    await tester.tap(find.descendant(of: filters, matching: find.text('퀴즈')));
    await tester.enterText(find.byType(TextField), '여행');
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pumpAndSettle();
    expect(find.text('42개'), findsOneWidget);
    expect(repository.lastSort, 'recent');

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(repository.lastPage, 2);
    await tester.tap(find.text('旅行'));
    await tester.pumpAndSettle();
    expect(find.text('예문'), findsOneWidget);
    await tester.tap(find.text('최근 추가순'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('많이 틀린 순'));
    await tester.pumpAndSettle();

    expect(repository.lastSort, 'most-wrong');
    expect(repository.lastPage, 1);
    expect(repository.lastFilter, 'QUIZ');
    expect(repository.lastSearch, '여행');
    expect(find.text('많이 틀린 순'), findsOneWidget);
    expect(find.text('42개'), findsOneWidget);
    expect(find.text('예문'), findsNothing);
  });

  testWidgets('swiping keeps the list usable after removal', (tester) async {
    final repository = _WordbookRepository(entries: [_manualEntry]);
    await _pumpPage(tester, repository);
    await tester.drag(find.text('練習'), const Offset(-700, 0));
    await tester.pumpAndSettle();
    expect(repository.deletedIds, ['manual-id']);
    expect(repository.fetchCalls, 2);
    expect(find.text('단어장에 단어가 없어요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
    overrides: [
      currentAccountIdProvider.overrideWithValue('owner'),
      currentAccountReaderProvider.overrideWithValue(() => 'owner'),
      studyRepositoryProvider.overrideWithValue(repository),
    ],
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

const _manualEntry = WordbookEntryModel(
  id: 'manual-id',
  word: '練習',
  reading: 'れんしゅう',
  meaningKo: '연습',
  source: 'MANUAL',
  note: '  ',
  createdAt: '2026-11-03T05:00:00Z',
);

class _WordbookRepository implements StudyRepository {
  _WordbookRepository({
    List<WordbookEntryModel> entries = _savedEntries,
    this.failFirstRead = false,
    this.duplicateFirstEdit = false,
    this.detailError,
    this.serverTotal,
    this.serverPages = 1,
  }) : entries = entries.toList();

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
      note: '다시 복습하기',
      exampleSentence: '旅行に行きます。',
      exampleTranslation: '여행을 갑니다.',
      createdAt: '2026-11-03T05:00:00Z',
    ),
  ];

  final List<WordbookEntryModel> entries;
  final bool failFirstRead;
  final bool duplicateFirstEdit;
  final int? serverTotal;
  final int serverPages;
  ApiException? detailError;
  Completer<void>? pendingEdit;
  final openedIds = <String>[];
  final deletedIds = <String>[];
  final edits = <(String, String, String, String)>[];
  (String, String, String)? added;
  String? lastFilter;
  String? lastSearch;
  String? lastSort;
  int? lastPage;
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
    lastFilter = filter;
    lastSearch = search;
    lastSort = sort;
    lastPage = page;
    if (failFirstRead && fetchCalls == 1) {
      throw StateError('Temporary fixture error');
    }
    final results = entries.where((entry) {
      return (filter == 'ALL' || entry.source == filter) &&
          (search.isEmpty ||
              entry.word.contains(search) ||
              entry.reading.contains(search) ||
              entry.meaningKo.contains(search));
    }).toList();
    return (
      entries: results,
      total: serverTotal ?? results.length,
      totalPages: serverPages,
    );
  }

  @override
  Future<WordbookEntryModel> fetchWordbookEntry(String id) async {
    openedIds.add(id);
    if (detailError case final error?) {
      detailError = null;
      throw error;
    }
    return entries.singleWhere((entry) => entry.id == id);
  }

  @override
  Future<void> addWord({
    required String word,
    required String reading,
    required String meaningKo,
    String source = 'MANUAL',
    bool preserveExisting = false,
    String? note,
  }) async {
    added = (word, reading, meaningKo);
    expect(preserveExisting, isTrue);
    expect(note, isNull);
  }

  @override
  Future<void> updateWordbookEntry(
    String id, {
    required String word,
    required String reading,
    required String meaningKo,
  }) async {
    edits.add((id, word, reading, meaningKo));
    if (duplicateFirstEdit && edits.length == 1) {
      throw const ApiException(message: 'duplicate', statusCode: 409);
    }
    await pendingEdit?.future;
    final index = entries.indexWhere((entry) => entry.id == id);
    final entry = entries[index];
    entries[index] = WordbookEntryModel(
      id: entry.id,
      word: word,
      reading: reading,
      meaningKo: meaningKo,
      source: entry.source,
      note: entry.note,
      createdAt: entry.createdAt,
    );
  }

  @override
  Future<void> deleteWord(String id) async {
    deletedIds.add(id);
    entries.removeWhere((entry) => entry.id == id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
