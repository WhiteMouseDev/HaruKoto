import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/network/network_base.dart';
import 'package:harukoto_mobile/features/my/data/my_repository.dart';

void main() {
  test('queued profile PATCH cannot dispatch for another account', () async {
    var owner = 'a';
    final release = Completer<void>();
    final started = Completer<void>();
    final dio = Dio();
    dio.interceptors
        .add(InterceptorsWrapper(onRequest: (options, handler) async {
      started.complete();
      await release.future;
      handler.next(options);
    }));
    final repository = MyRepository(dio, currentOwner: () => owner);
    addTearDown(repository.dispose);
    var dispatches = 0;
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      dispatches++;
      handler.resolve(
          Response(requestOptions: options, data: <String, dynamic>{}));
    }));
    final pending = repository.updateProfile({'dailyGoal': 30});
    final assertion = expectLater(pending, throwsA(isA<DioException>()));
    await started.future;
    owner = 'b';
    release.complete();
    await assertion;
    expect(dispatches, 0);
  });

  test('profile PATCH owns retry and retains the existing payload', () async {
    final dio = Dio();
    final repository = MyRepository(dio, currentOwner: () => 'a');
    addTearDown(repository.dispose);
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      expect(options.path, '/user/profile');
      expect(options.data, {'dailyGoal': 30});
      expect(options.extra[RequestMetadata.skipNetworkRetry], isTrue);
      expect(options.extra[RequestMetadata.skipAuthRefresh], isTrue);
      handler.resolve(
          Response(requestOptions: options, data: <String, dynamic>{}));
    }));
    await repository.updateProfile({'dailyGoal': 30});
  });
}
