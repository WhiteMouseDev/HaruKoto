import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_analysis_request_factory.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_connection_service.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_end_call_handler.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_end_flow_coordinator.dart';

void main() {
  group('VoiceCallEndCallHandler', () {
    test('delegates end input and wraps the analysis request result', () async {
      final receivedInputs = <VoiceCallEndFlowInput>[];
      const request = VoiceCallSessionRequest(
        scenarioId: 'scenario-1',
        characterId: 'char-1',
      );
      const analysisRequest = VoiceCallAnalysisRequest(
        transcript: [
          {'role': 'user', 'text': 'もしもし'},
        ],
        durationSeconds: 20,
        characterId: 'char-1',
      );
      final handler = VoiceCallEndCallHandler(
        endFlow: (input) async {
          receivedInputs.add(input);
          return analysisRequest;
        },
      );

      final result = await handler.end(
        const VoiceCallEndCallInput(
          resources: null,
          request: request,
          durationSeconds: 20,
        ),
      );

      expect(result.ignored, isFalse);
      expect(result.analysisRequest, same(analysisRequest));
      expect(receivedInputs.single.request, same(request));
      expect(receivedInputs.single.durationSeconds, 20);
    });

    test('ignores duplicate end requests while an end is in progress',
        () async {
      final completer = Completer<VoiceCallAnalysisRequest?>();
      var endCalls = 0;
      final handler = VoiceCallEndCallHandler(
        endFlow: (_) {
          endCalls++;
          return completer.future;
        },
      );

      final firstResult = handler.end(
        const VoiceCallEndCallInput(
          resources: null,
          request: null,
          durationSeconds: 0,
        ),
      );
      final duplicateResult = await handler.end(
        const VoiceCallEndCallInput(
          resources: null,
          request: null,
          durationSeconds: 0,
        ),
      );
      completer.complete(null);

      expect(duplicateResult.ignored, isTrue);
      expect(endCalls, 1);
      expect((await firstResult).ignored, isFalse);
    });

    test('reset allows a later end request', () async {
      var endCalls = 0;
      final handler = VoiceCallEndCallHandler(
        endFlow: (_) async {
          endCalls++;
          return null;
        },
      );

      await handler.end(
        const VoiceCallEndCallInput(
          resources: null,
          request: null,
          durationSeconds: 0,
        ),
      );
      final ignoredResult = await handler.end(
        const VoiceCallEndCallInput(
          resources: null,
          request: null,
          durationSeconds: 0,
        ),
      );
      handler.reset();
      final resetResult = await handler.end(
        const VoiceCallEndCallInput(
          resources: null,
          request: null,
          durationSeconds: 0,
        ),
      );

      expect(ignoredResult.ignored, isTrue);
      expect(resetResult.ignored, isFalse);
      expect(endCalls, 2);
    });
  });
}
