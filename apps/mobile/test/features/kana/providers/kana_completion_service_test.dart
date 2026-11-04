import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/core/network/api_exception.dart';
import 'package:harukoto_mobile/features/home/data/models/user_profile_model.dart';
import 'package:harukoto_mobile/features/home/providers/home_provider.dart';
import 'package:harukoto_mobile/features/home/providers/study_activity_refresh_provider.dart';
import 'package:harukoto_mobile/features/kana/data/kana_repository.dart';
import 'package:harukoto_mobile/features/kana/data/models/kana_stage_model.dart';
import 'package:harukoto_mobile/features/kana/providers/kana_completion_service.dart';
import 'package:harukoto_mobile/features/kana/providers/kana_provider.dart';

enum _Operation { answer, quiz, stage }

void main() {
  for (final operation in _Operation.values) {
    group(operation.name, () {
      for (final identity in [
        (name: 'signed out', reader: null, provider: null),
        (name: 'session missing', reader: null, provider: 'learner-a'),
        (name: 'identity missing', reader: 'learner-a', provider: null),
        (
          name: 'identity disagrees',
          reader: 'learner-a',
          provider: 'learner-b'
        ),
      ]) {
        test('rejects ${identity.name} before sending a mutation', () async {
          final fixture = _Fixture(
            readerOwner: identity.reader,
            providerOwner: identity.provider,
          );
          addTearDown(fixture.dispose);
          await fixture.observeProfile();

          await expectLater(
            fixture.perform(operation),
            throwsA(isA<ApiException>()
                .having((error) => error.statusCode, 'statusCode', 401)),
          );

          expect(fixture.repository.requests, isEmpty);
          expect(fixture.refresh.calls, 0);
          await fixture.container.pump();
          expect(fixture.profileReads, 1);
        });
      }

      test('refreshes once only after the current account receives ACK',
          () async {
        final fixture = _Fixture();
        addTearDown(fixture.dispose);
        await fixture.observeProfile();
        fixture.repository.gate = Completer<void>();

        final pending = fixture.perform(operation);
        expect(fixture.repository.requests, [_payload(operation)]);
        expect(fixture.refresh.calls, 0);
        expect(fixture.profileReads, 1);

        fixture.repository.gate!.complete();
        _expectResponse(operation, await pending, fixture.repository);
        await fixture.container.pump();
        expect(fixture.refresh.calls, 1);
        expect(fixture.profileReads, operation == _Operation.answer ? 2 : 1);
      });

      test('propagates a save failure without refreshing either cache',
          () async {
        final fixture = _Fixture();
        addTearDown(fixture.dispose);
        await fixture.observeProfile();
        const failure =
            ApiException(message: 'temporary failure', statusCode: 503);
        fixture.repository.failure = failure;

        await expectLater(fixture.perform(operation), throwsA(same(failure)));

        expect(fixture.repository.requests, [_payload(operation)]);
        expect(fixture.refresh.calls, 0);
        await fixture.container.pump();
        expect(fixture.profileReads, 1);
      });

      for (final change in [
        (
          name: 'session changes first',
          reader: 'learner-b',
          provider: 'learner-a'
        ),
        (
          name: 'provider changes first',
          reader: 'learner-a',
          provider: 'learner-b'
        ),
        (
          name: 'both switch accounts',
          reader: 'learner-b',
          provider: 'learner-b'
        ),
        (name: 'account signs out', reader: null, provider: null),
      ]) {
        test('late ACK cannot refresh another account when ${change.name}',
            () async {
          final fixture = _Fixture();
          addTearDown(fixture.dispose);
          await fixture.observeProfile();
          fixture.repository.gate = Completer<void>();
          final pending = fixture.perform(operation);
          expect(fixture.repository.requests, [_payload(operation)]);

          fixture.changeAccount(
              reader: change.reader, provider: change.provider);
          fixture.repository.gate!.complete();
          _expectResponse(operation, await pending, fixture.repository);
          await fixture.container.pump();

          expect(fixture.repository.requests, hasLength(1));
          expect(fixture.refresh.calls, 0);
          expect(fixture.profileReads, 1);
        });
      }

      test('late ACK after disposal returns without accessing disposed state',
          () async {
        final fixture = _Fixture();
        await fixture.observeProfile();
        fixture.repository.gate = Completer<void>();
        final pending = fixture.perform(operation);
        fixture.dispose();

        fixture.repository.gate!.complete();
        _expectResponse(operation, await pending, fixture.repository);

        expect(fixture.refresh.calls, 0);
        expect(fixture.profileReads, 1);
      });
    });
  }
}

Map<String, Object> _payload(_Operation operation) => switch (operation) {
      _Operation.answer => {
          'operation': 'answer',
          'sessionId': 'saved-session',
          'questionId': 'question-2',
          'selectedOptionId': 'option-a',
        },
      _Operation.quiz => {'operation': 'quiz', 'sessionId': 'saved-session'},
      _Operation.stage => {
          'operation': 'stage',
          'stageId': 'stage-1',
          'quizScore': 80,
        },
    };

void _expectResponse(
    _Operation operation, Object? result, _Repository repository) {
  switch (operation) {
    case _Operation.answer:
      expect(result, (isCorrect: false, correctOptionId: 'option-b'));
    case _Operation.quiz:
      expect(result, same(repository.quizResponse));
    case _Operation.stage:
      expect(result, isNull);
  }
}

class _Fixture {
  _Fixture({this.readerOwner = 'learner-a', this.providerOwner = 'learner-a'}) {
    container = ProviderContainer(overrides: [
      currentAccountReaderProvider.overrideWithValue(() => readerOwner),
      currentAccountIdProvider.overrideWith((ref) => providerOwner),
      kanaRepositoryProvider.overrideWithValue(repository),
      studyActivityRefreshProvider.overrideWithValue(refresh),
      profileProvider.overrideWith((ref) async {
        profileReads++;
        return UserProfileModel.fromJson({});
      }),
    ]);
  }

  String? readerOwner;
  String? providerOwner;
  late final ProviderContainer container;
  final repository = _Repository();
  final refresh = _Refresh();
  int profileReads = 0;
  ProviderSubscription<AsyncValue<UserProfileModel>>? _profileSubscription;

  Future<void> observeProfile() async {
    _profileSubscription = container.listen(profileProvider, (_, __) {});
    await container.read(profileProvider.future);
  }

  void changeAccount({required String? reader, required String? provider}) {
    readerOwner = reader;
    providerOwner = provider;
    container.invalidate(currentAccountIdProvider);
  }

  Future<Object?> perform(_Operation operation) {
    final service = container.read(kanaCompletionServiceProvider);
    return switch (operation) {
      _Operation.answer => service.answerQuestion(
          sessionId: 'saved-session',
          questionId: 'question-2',
          selectedOptionId: 'option-a',
        ),
      _Operation.quiz => service.completeQuiz(sessionId: 'saved-session'),
      _Operation.stage =>
        service.completeStage(stageId: 'stage-1', quizScore: 80),
    };
  }

  void dispose() {
    _profileSubscription?.close();
    container.dispose();
  }
}

class _Refresh extends Fake implements StudyActivityRefresh {
  int calls = 0;

  @override
  void refresh() => calls++;
}

class _Repository extends Fake implements KanaRepository {
  final requests = <Map<String, Object>>[];
  Completer<void>? gate;
  ApiException? failure;
  final quizResponse = const CompleteQuizResponse(
    accuracy: 80,
    xpEarned: 27,
    currentXp: 127,
    xpForNext: 200,
    level: 2,
    events: [],
  );

  Future<void> _acknowledge(Map<String, Object> request) async {
    requests.add(request);
    await gate?.future;
    if (failure != null) throw failure!;
  }

  @override
  Future<({bool isCorrect, String correctOptionId})> answerQuestion({
    required String sessionId,
    required String questionId,
    required String selectedOptionId,
  }) async {
    await _acknowledge({
      'operation': 'answer',
      'sessionId': sessionId,
      'questionId': questionId,
      'selectedOptionId': selectedOptionId,
    });
    return (isCorrect: false, correctOptionId: 'option-b');
  }

  @override
  Future<CompleteQuizResponse> completeQuiz({required String sessionId}) async {
    await _acknowledge({'operation': 'quiz', 'sessionId': sessionId});
    return quizResponse;
  }

  @override
  Future<void> completeStage({required String stageId, int? quizScore}) =>
      _acknowledge({
        'operation': 'stage',
        'stageId': stageId,
        if (quizScore != null) 'quizScore': quizScore,
      });
}
