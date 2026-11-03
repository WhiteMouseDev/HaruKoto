import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/chat_repository.dart';
import 'package:harukoto_mobile/features/study/data/study_repository.dart';

void main() {
  test(
      'stable id is reused for preparation, token, save-only and analysis retry',
      () async {
    final requests = <RequestOptions>[];
    final dio = Dio()
      ..interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        requests.add(options);
        final Map<String, dynamic> data;
        if (options.path == '/chat/live-session') {
          data = {'conversationId': 'stable-id', 'endedAt': null};
        } else if (options.path == '/chat/live-token') {
          data = {
            'token': 'token',
            'model': 'model',
            'wsUri': 'wss://example.test'
          };
        } else {
          data = {
            'conversationId': 'stable-id',
            'feedbackSummary': null,
            'feedbackError': null,
            'xpEarned': 0,
            'events': []
          };
        }
        handler.resolve(
            Response(requestOptions: options, data: data, statusCode: 200));
      }));
    addTearDown(dio.close);
    final repository = DioChatRepository(dio);
    await repository.createLiveSession(
        conversationId: 'stable-id', scenarioId: 'hotel-id');
    await repository.fetchLiveToken(
        conversationId: 'stable-id', scenarioId: 'hotel-id');
    await repository.sendLiveFeedback(
        conversationId: 'stable-id',
        transcript: const [],
        durationSeconds: 0,
        analysisEnabled: false);
    await repository.sendLiveFeedback(
        conversationId: 'stable-id',
        transcript: const [],
        durationSeconds: 0,
        analysisEnabled: true);
    expect(requests.map((r) => r.path), [
      '/chat/live-session',
      '/chat/live-token',
      '/chat/live-feedback',
      '/chat/live-feedback'
    ]);
    for (final request in requests) {
      expect((request.data as Map<String, dynamic>)['conversationId'],
          'stable-id');
    }
    expect(
        (requests[2].data as Map<String, dynamic>)['analysisEnabled'], isFalse);
    expect(
        (requests[3].data as Map<String, dynamic>)['analysisEnabled'], isTrue);
  });
  test('preparing an already-ended or mismatched id is rejected before a token',
      () async {
    for (final response in [
      {'conversationId': 'other-id', 'endedAt': null},
      {'conversationId': 'stable-id', 'endedAt': '2026-11-03T12:00:00Z'},
    ]) {
      final dio = Dio()
        ..interceptors.add(InterceptorsWrapper(
            onRequest: (options, handler) => handler
                .resolve(Response(requestOptions: options, data: response))));
      await expectLater(
          DioChatRepository(dio).createLiveSession(conversationId: 'stable-id'),
          throwsFormatException);
      dio.close();
    }
  });
  test(
      'wordbook expression save consumes preserveExisting without changing legacy saves',
      () async {
    final requests = <RequestOptions>[];
    final dio = Dio()
      ..interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        requests.add(options);
        handler.resolve(
            Response(requestOptions: options, data: <String, dynamic>{}));
      }));
    addTearDown(dio.close);
    final repository = ApiStudyRepository(dio);
    await repository.addWord(
        word: '予約しています。',
        reading: '',
        meaningKo: '예약했어요',
        source: 'CONVERSATION',
        preserveExisting: true);
    await repository.addWord(word: '予約', reading: 'よやく', meaningKo: '예약');
    expect(
        (requests[0].data as Map<String, dynamic>)['preserveExisting'], isTrue);
    expect(
        (requests[1].data as Map<String, dynamic>)
            .containsKey('preserveExisting'),
        isFalse);
  });
}
