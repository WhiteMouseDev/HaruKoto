import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/network/api_exception.dart';
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

  test('updates word fields without a note and rejects legacy no-op responses',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final entry = <String, Object?>{
      'id': 'word-id',
      'word': '預ける',
      'reading': 'あずける',
      'meaningKo': '맡기다',
      'source': 'MANUAL',
      'note': '호텔에서 본 단어',
      'createdAt': '2026-11-26T00:00:00Z',
    };
    final patches = <Map<String, dynamic>>[];
    Map<String, dynamic>? duplicateAdd;
    var legacyServer = true;
    final subscription = server.listen((request) async {
      if (request.method == 'POST' && request.uri.path == '/wordbook/') {
        duplicateAdd = jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, dynamic>;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(entry));
      } else if (request.uri.path != '/wordbook/word-id') {
        request.response.statusCode = HttpStatus.notFound;
      } else {
        if (request.method == 'PATCH') {
          final patch = jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>;
          patches.add(patch);
          if (!legacyServer) entry.addAll(patch);
        }
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          ...entry,
          if (!legacyServer && request.method == 'GET') ...{
            'exampleSentence': '荷物を預ける。',
            'exampleTranslation': '짐을 맡기다.',
          },
        }));
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

    Future<void> updateEntry() => repository.updateWordbookEntry(
          'word-id',
          word: '預ける',
          reading: 'あずける',
          meaningKo: '짐을 맡기다',
        );

    expect((await repository.fetchWordbookEntry('word-id')).exampleSentence,
        isNull);
    await expectLater(
      repository.addWord(
        word: '預ける',
        reading: 'あずける',
        meaningKo: '짐을 맡기다',
        preserveExisting: true,
      ),
      throwsA(isA<ApiException>().having(
        (error) => error.statusCode,
        'status code',
        HttpStatus.conflict,
      )),
    );
    expect(duplicateAdd?['preserveExisting'], true);
    expect(duplicateAdd?.containsKey('note'), false);
    await expectLater(
      updateEntry(),
      throwsA(isA<ApiException>().having(
        (error) => error.errorCode,
        'error code',
        'WORDBOOK_EDIT_UNAVAILABLE',
      )),
    );

    legacyServer = false;
    await updateEntry();
    final saved = await repository.fetchWordbookEntry('word-id');
    expect(saved.meaningKo, '짐을 맡기다');
    expect(saved.note, '호텔에서 본 단어');
    expect(saved.exampleSentence, '荷物を預ける。');
    expect(saved.exampleTranslation, '짐을 맡기다.');
    expect(patches, [
      {'word': '預ける', 'reading': 'あずける', 'meaningKo': '짐을 맡기다'},
      {'word': '預ける', 'reading': 'あずける', 'meaningKo': '짐을 맡기다'},
    ]);
  });
}
