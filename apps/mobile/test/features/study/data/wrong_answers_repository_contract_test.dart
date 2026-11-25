import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/word_entry_model.dart';
import 'package:harukoto_mobile/features/study/data/study_repository.dart';

void main() {
  test('wrong-answer reads use optional filters and parse the capability',
      () async {
    final requests = <RequestOptions>[];
    final dio = Dio();
    addTearDown(dio.close);
    dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      requests.add(request);
      handler.resolve(Response<Map<String, dynamic>>(
        requestOptions: request,
        data: {
          'entries': [],
          'total': 7,
          'totalPages': 2,
          'summary': {'totalWrong': 40, 'mastered': 20, 'remaining': 20},
          if (requests.length != 1) 'supportsSearchAndStatus': true,
        },
      ));
    }));
    final repository = ApiStudyRepository(dio);

    final legacy = await repository.fetchWrongAnswers(search: '  ');
    expect(requests[0].method, 'GET');
    expect(requests[0].path, '/study/wrong-answers');
    expect(requests[0].queryParameters, {
      'page': 1,
      'sort': 'most-wrong',
      'limit': 20,
    });
    expect(legacy.supportsSearchAndStatus, isFalse);
    expect(legacy.summary.totalWrong, 40);

    final filtered = await repository.fetchWrongAnswers(
      page: 2,
      sort: 'recent',
      search: ' 食べる ',
      status: WrongAnswerStatus.learning,
      limit: 5,
    );
    expect(requests[1].queryParameters, {
      'page': 2,
      'sort': 'recent',
      'limit': 5,
      'search': '食べる',
      'status': 'LEARNING',
    });
    expect(filtered.supportsSearchAndStatus, isTrue);
    expect(filtered.total, 7);
    expect(filtered.totalPages, 2);
    expect(filtered.summary.totalWrong, 40);

    await repository.fetchWrongAnswers(status: WrongAnswerStatus.mastered);
    expect(requests[2].queryParameters['status'], 'MASTERED');
    expect(requests[2].queryParameters.containsKey('search'), isFalse);
  });
}
