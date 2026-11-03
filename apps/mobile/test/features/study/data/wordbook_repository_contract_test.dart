import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/study_repository.dart';

void main() {
  test('wordbook lookup and expression save use the canonical HTTP route',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <String>[];
    Map<String, String>? query;
    Map<String, dynamic>? saved;
    final subscription = server.listen((request) async {
      requests.add('${request.method} ${request.uri.path}');
      if (request.uri.path == '/wordbook') {
        request.response.statusCode = HttpStatus.temporaryRedirect;
        request.response.headers.set(HttpHeaders.locationHeader, '/wordbook/');
      } else if (request.uri.path == '/wordbook/') {
        request.response.headers.contentType = ContentType.json;
        if (request.method == 'GET') {
          query = request.uri.queryParameters;
          request.response.write(jsonEncode({
            'entries': <Object>[],
            'total': 0,
            'totalPages': 1,
          }));
        } else if (request.method == 'POST') {
          saved = jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>;
          request.response.write(jsonEncode({'id': 'expression-id'}));
        }
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
    });
    final dio = Dio(BaseOptions(
      baseUrl: 'http://127.0.0.1:${server.port}',
      receiveTimeout: const Duration(seconds: 3),
    ));
    addTearDown(() async {
      dio.close(force: true);
      await server.close(force: true);
      await subscription.cancel();
    });
    final repository = ApiStudyRepository(dio);
    final result = await repository.fetchWordbook(
        search: '予約しています。', filter: 'CONVERSATION');
    expect(result.entries, isEmpty);
    await repository.addWord(
      word: '予約しています。',
      reading: '',
      meaningKo: '예약했어요.',
      source: 'CONVERSATION',
      preserveExisting: true,
    );

    expect(requests, ['GET /wordbook/', 'POST /wordbook/']);
    expect(query?['search'], '予約しています。');
    expect(query?['source'], 'CONVERSATION');
    expect(saved, {
      'word': '予約しています。',
      'reading': '',
      'meaningKo': '예약했어요.',
      'source': 'CONVERSATION',
      'preserveExisting': true,
    });
  });
}
