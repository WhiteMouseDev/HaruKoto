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
          return const VoiceCallEndFlowResult(
            analysisRequest: analysisRequest,
          );
        },
      );

      final result = await handler.end(
        const VoiceCallEndCallInput(
          resources: null,
          request: request,
          durationSeconds: 20,
          wasConnected: true,
        ),
      );

      expect(result.ignored, isFalse);
      expect(result.analysisRequest, same(analysisRequest));
      expect(result.feedbackError, isNull);
      expect(receivedInputs.single.request, same(request));
      expect(receivedInputs.single.durationSeconds, 20);
      expect(receivedInputs.single.wasConnected, isTrue);
    });

    test('wraps a no transcript feedback error result', () async {
      final handler = VoiceCallEndCallHandler(
        endFlow: (_) async {
          return const VoiceCallEndFlowResult(feedbackError: 'no_transcript');
        },
      );

      final result = await handler.end(
        const VoiceCallEndCallInput(
          resources: null,
          request: VoiceCallSessionRequest(characterId: 'char-1'),
          durationSeconds: 1,
          wasConnected: true,
        ),
      );

      expect(result.ignored, isFalse);
      expect(result.analysisRequest, isNull);
      expect(result.feedbackError, 'no_transcript');
    });

    test('ignores duplicate end requests while an end is in progress',
        () async {
      final completer = Completer<VoiceCallAnalysisRequest?>();
      var endCalls = 0;
      final handler = VoiceCallEndCallHandler(
        endFlow: (_) {
          endCalls++;
          return completer.future.then(
            (request) => VoiceCallEndFlowResult(analysisRequest: request),
          );
        },
      );

      final firstResult = handler.end(
        const VoiceCallEndCallInput(
          resources: null,
          request: null,
          durationSeconds: 0,
          wasConnected: false,
        ),
      );
      final duplicateResult = await handler.end(
        const VoiceCallEndCallInput(
          resources: null,
          request: null,
          durationSeconds: 0,
          wasConnected: false,
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
          return const VoiceCallEndFlowResult();
        },
      );

      await handler.end(
        const VoiceCallEndCallInput(
          resources: null,
          request: null,
          durationSeconds: 0,
          wasConnected: false,
        ),
      );
      final ignoredResult = await handler.end(
        const VoiceCallEndCallInput(
          resources: null,
          request: null,
          durationSeconds: 0,
          wasConnected: false,
        ),
      );
      handler.reset();
      final resetResult = await handler.end(
        const VoiceCallEndCallInput(
          resources: null,
          request: null,
          durationSeconds: 0,
          wasConnected: false,
        ),
      );

      expect(ignoredResult.ignored, isTrue);
      expect(resetResult.ignored, isFalse);
      expect(endCalls, 2);
    });
  });
}
