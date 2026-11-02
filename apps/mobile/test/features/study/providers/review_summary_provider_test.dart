import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/features/study/data/models/review_summary_model.dart';
import 'package:harukoto_mobile/features/study/domain/study_repository.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';

void main() {
  test('unknown or already-switched account does not read review data',
      () async {
    for (final (stream, current) in [(null, null), ('before', 'after')]) {
      final repository = _Repository();
      final container = ProviderContainer(retry: (_, __) => null, overrides: [
        currentAccountIdProvider.overrideWithValue(stream),
        currentAccountReaderProvider.overrideWithValue(() => current),
        studyRepositoryProvider.overrideWithValue(repository),
      ]);
      await expectLater(
          container.read(reviewSummaryProvider('N5').future), throwsStateError);
      expect(repository.levels, isEmpty);
      container.dispose();
    }
  });

  test('response from an account changed during the read is rejected',
      () async {
    var current = 'before';
    final repository = _Repository();
    final container = ProviderContainer(retry: (_, __) => null, overrides: [
      currentAccountIdProvider.overrideWithValue('before'),
      currentAccountReaderProvider.overrideWithValue(() => current),
      studyRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    final subscription =
        container.listen(reviewSummaryProvider('N5'), (_, __) {});
    addTearDown(subscription.close);
    final future = container.read(reviewSummaryProvider('N5').future);
    final rejected = expectLater(future, throwsStateError);
    current = 'after';
    repository.responses.single.complete(_summary(12));
    await rejected;
    expect(container.read(reviewSummaryProvider('N5')).hasError, isTrue);
    expect(container.read(reviewSummaryProvider('N5')).hasValue, isFalse);
    expect(repository.levels, ['N5']);
  });

  test('new account rebuild ignores late results from the previous read',
      () async {
    var current = 'before';
    var stream = 'before';
    final repository = _Repository();
    final container = ProviderContainer(retry: (_, __) => null, overrides: [
      currentAccountIdProvider.overrideWith((ref) => stream),
      currentAccountReaderProvider.overrideWithValue(() => current),
      studyRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    final subscription =
        container.listen(reviewSummaryProvider('N5'), (_, __) {});
    addTearDown(subscription.close);
    container.read(reviewSummaryProvider('N5'));
    final old = repository.responses.single;
    current = stream = 'after';
    container.invalidate(currentAccountIdProvider);
    final next = container.read(reviewSummaryProvider('N5').future);
    expect(repository.responses, hasLength(2));
    repository.responses.last.complete(_summary(2));
    expect((await next).wordDue, 2);
    old.complete(_summary(12));
    await container.pump();
    expect(container.read(reviewSummaryProvider('N5')).requireValue.wordDue, 2);
    expect(repository.levels, ['N5', 'N5']);
  });

  test('different levels retain their own request and counts', () async {
    final repository = _Repository();
    final container = ProviderContainer(retry: (_, __) => null, overrides: [
      currentAccountIdProvider.overrideWithValue('same-account'),
      currentAccountReaderProvider.overrideWithValue(() => 'same-account'),
      studyRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    final n5 = container.read(reviewSummaryProvider('N5').future);
    final n4 = container.read(reviewSummaryProvider('N4').future);
    repository.responses[0].complete(_summary(2));
    repository.responses[1].complete(_summary(8));
    expect((await n5).wordDue, 2);
    expect((await n4).wordDue, 8);
    expect(repository.levels, ['N5', 'N4']);
  });
}

ReviewSummaryModel _summary(int words) => ReviewSummaryModel(
    wordDue: words, grammarDue: 0, totalDue: words, wordNew: 0, grammarNew: 0);

class _Repository extends Fake implements StudyRepository {
  final levels = <String>[];
  final responses = <Completer<ReviewSummaryModel>>[];

  @override
  Future<ReviewSummaryModel> fetchReviewSummary(String jlptLevel) {
    levels.add(jlptLevel);
    final response = Completer<ReviewSummaryModel>();
    responses.add(response);
    return response.future;
  }
}
