import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/chat_repository.dart';
import 'package:harukoto_mobile/features/chat/providers/call_analysis_service.dart';
import 'package:harukoto_mobile/features/chat/providers/chat_provider.dart';
import 'package:harukoto_mobile/features/chat/providers/conversation_end_provider.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_session_provider.dart';
import 'package:harukoto_mobile/features/home/data/models/dashboard_model.dart';
import 'package:harukoto_mobile/features/home/providers/home_provider.dart';
import 'package:harukoto_mobile/features/home/providers/study_activity_refresh_provider.dart';
import 'package:harukoto_mobile/features/kana/data/kana_repository.dart';
import 'package:harukoto_mobile/features/kana/data/models/kana_stage_model.dart';
import 'package:harukoto_mobile/features/kana/providers/kana_completion_service.dart';
import 'package:harukoto_mobile/features/kana/providers/kana_provider.dart';
import 'package:harukoto_mobile/features/stats/data/models/heatmap_data_model.dart';
import 'package:harukoto_mobile/features/stats/providers/stats_provider.dart';
import 'package:harukoto_mobile/features/study/data/models/lesson_models.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_result_model.dart';
import 'package:harukoto_mobile/features/study/domain/study_repository.dart';
import 'package:harukoto_mobile/features/study/providers/lesson_session_service.dart';
import 'package:harukoto_mobile/features/study/providers/quiz_session_service.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';

void main() {
  test('refresh reloads cached dashboard and both calendar scopes', () async {
    var dashboardCalls = 0;
    var yearlyCalls = 0;
    var monthlyCalls = 0;
    var heatmapCalls = 0;
    final container = ProviderContainer(overrides: [
      dashboardProvider.overrideWith((ref) async {
        dashboardCalls++;
        return DashboardModel.fromJson({});
      }),
      statsHistoryProvider.overrideWith((ref, year) async {
        yearlyCalls++;
        return [];
      }),
      statsMonthHistoryProvider.overrideWith((ref, period) async {
        monthlyCalls++;
        return [];
      }),
      heatmapProvider.overrideWith((ref, year) async {
        heatmapCalls++;
        return const HeatmapResponse(data: []);
      }),
    ]);
    addTearDown(container.dispose);
    container.listen(dashboardProvider, (_, __) {});
    container.listen(statsHistoryProvider(2026), (_, __) {});
    container.listen(
        statsMonthHistoryProvider((year: 2026, month: 9)), (_, __) {});
    container.listen(heatmapProvider(2026), (_, __) {});
    Future<void> readAll() async {
      await container.read(dashboardProvider.future);
      await container.read(statsHistoryProvider(2026).future);
      await container
          .read(statsMonthHistoryProvider((year: 2026, month: 9)).future);
      await container.read(heatmapProvider(2026).future);
    }

    await readAll();
    container.read(studyActivityRefreshProvider).refresh();
    await readAll();
    expect([dashboardCalls, yearlyCalls, monthlyCalls, heatmapCalls],
        [2, 2, 2, 2]);
  });

  for (final kind in [
    'lesson',
    'quiz',
    'kana quiz',
    'kana stage',
    'conversation',
    'call'
  ]) {
    for (final fails in [false, true]) {
      test(
          '$kind ${fails ? 'failure preserves' : 'success refreshes'} activity cache',
          () async {
        final refresh = _RefreshSpy();
        final container = ProviderContainer(overrides: [
          studyActivityRefreshProvider.overrideWithValue(refresh),
          studyRepositoryProvider.overrideWithValue(_StudyRepository(fails)),
          kanaRepositoryProvider.overrideWithValue(_KanaRepository(fails)),
          chatRepositoryProvider.overrideWithValue(_ChatRepository(fails)),
        ]);
        addTearDown(container.dispose);
        final Future<Object?> result = switch (kind) {
          'lesson' => container
              .read(lessonSessionServiceProvider)
              .submitLesson(lessonId: 'lesson', answers: [], jlptLevel: 'N5'),
          'quiz' =>
            container.read(quizSessionServiceProvider).completeQuiz('session'),
          'kana quiz' => container
              .read(kanaCompletionServiceProvider)
              .completeQuiz(sessionId: 'session'),
          'kana stage' => container
              .read(kanaCompletionServiceProvider)
              .completeStage(stageId: 'stage'),
          'conversation' => container
              .read(conversationEndServiceProvider)
              .endConversation('conversation'),
          _ => container.read(callAnalysisServiceProvider).analyze(
              const VoiceCallAnalysisRequest(
                  transcript: [], durationSeconds: 60)),
        };
        if (fails) {
          await expectLater(result, throwsStateError);
        } else {
          await result;
        }
        expect(refresh.calls, fails ? 0 : 1);
      });
    }
  }

  for (final kind in [
    'lesson',
    'quiz',
    'kana quiz',
    'kana stage',
    'conversation',
    'call'
  ]) {
    test('$kind retry refreshes once after a failed completion', () async {
      final refresh = _RefreshSpy();
      final study = _StudyRepository(true);
      final kana = _KanaRepository(true);
      final chat = _ChatRepository(true);
      final container = ProviderContainer(overrides: [
        studyActivityRefreshProvider.overrideWithValue(refresh),
        studyRepositoryProvider.overrideWithValue(study),
        kanaRepositoryProvider.overrideWithValue(kana),
        chatRepositoryProvider.overrideWithValue(chat),
      ]);
      addTearDown(container.dispose);
      await expectLater(_complete(kind, container), throwsStateError);
      expect(refresh.calls, 0);
      study.fails = false;
      kana.fails = false;
      chat.fails = false;
      await _complete(kind, container);
      expect(refresh.calls, 1);
    });
    test('$kind returns its successful result after provider disposal',
        () async {
      final gate = Completer<void>();
      final refresh = _RefreshSpy();
      final container = ProviderContainer(overrides: [
        studyActivityRefreshProvider.overrideWithValue(refresh),
        studyRepositoryProvider
            .overrideWithValue(_StudyRepository(false)..gate = gate),
        kanaRepositoryProvider
            .overrideWithValue(_KanaRepository(false)..gate = gate),
        chatRepositoryProvider
            .overrideWithValue(_ChatRepository(false)..gate = gate),
      ]);
      final pending = _complete(kind, container);
      container.dispose();
      gate.complete();
      await pending;
      expect(refresh.calls, 0);
    });
  }

  test('unaccepted conversation completion does not refresh activity',
      () async {
    final refresh = _RefreshSpy();
    final container = ProviderContainer(overrides: [
      studyActivityRefreshProvider.overrideWithValue(refresh),
      chatRepositoryProvider
          .overrideWithValue(_ChatRepository(false, success: false)),
    ]);
    addTearDown(container.dispose);
    await container
        .read(conversationEndServiceProvider)
        .endConversation('conversation');
    expect(refresh.calls, 0);
  });
}

class _RefreshSpy extends Fake implements StudyActivityRefresh {
  int calls = 0;
  @override
  void refresh() => calls++;
}

class _StudyRepository extends Fake implements StudyRepository {
  _StudyRepository(this.fails);
  bool fails;
  Completer<void>? gate;
  @override
  Future<LessonSubmitResultModel> submitLesson(
      String id, List<Map<String, dynamic>> answers) async {
    await gate?.future;
    if (fails) throw StateError('offline');
    return LessonSubmitResultModel.fromJson({});
  }

  @override
  Future<QuizResultModel> completeQuiz(String sessionId,
      {String? stageId}) async {
    await gate?.future;
    if (fails) throw StateError('offline');
    return QuizResultModel.fromJson({});
  }
}

class _KanaRepository extends Fake implements KanaRepository {
  _KanaRepository(this.fails);
  bool fails;
  Completer<void>? gate;
  @override
  Future<CompleteQuizResponse> completeQuiz({required String sessionId}) async {
    await gate?.future;
    if (fails) throw StateError('offline');
    return CompleteQuizResponse.fromJson({});
  }

  @override
  Future<void> completeStage({required String stageId, int? quizScore}) async {
    await gate?.future;
    if (fails) throw StateError('offline');
  }
}

class _ChatRepository extends Fake implements ChatRepository {
  _ChatRepository(this.fails, {this.success = true});
  bool fails;
  Completer<void>? gate;
  final bool success;
  @override
  Future<EndConversationResponse> endConversation(String id) async {
    await gate?.future;
    if (fails) throw StateError('offline');
    return EndConversationResponse(success: success, xpEarned: 0, events: []);
  }

  @override
  Future<LiveFeedbackResponse> sendLiveFeedback(
      {required List<Map<String, String>> transcript,
      required int durationSeconds,
      String? characterId,
      String? scenarioId}) async {
    await gate?.future;
    if (fails) throw StateError('offline');
    return const LiveFeedbackResponse(
        conversationId: 'conversation', xpEarned: 0, events: []);
  }
}

Future<Object?> _complete(String kind, ProviderContainer container) =>
    switch (kind) {
      'lesson' => container
          .read(lessonSessionServiceProvider)
          .submitLesson(lessonId: 'lesson', answers: [], jlptLevel: 'N5'),
      'quiz' =>
        container.read(quizSessionServiceProvider).completeQuiz('session'),
      'kana quiz' => container
          .read(kanaCompletionServiceProvider)
          .completeQuiz(sessionId: 'session'),
      'kana stage' => container
          .read(kanaCompletionServiceProvider)
          .completeStage(stageId: 'stage'),
      'conversation' => container
          .read(conversationEndServiceProvider)
          .endConversation('conversation'),
      _ => container.read(callAnalysisServiceProvider).analyze(
          const VoiceCallAnalysisRequest(transcript: [], durationSeconds: 60)),
    };
