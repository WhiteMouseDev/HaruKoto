import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/core/network/api_exception.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/features/home/providers/study_activity_refresh_provider.dart';
import 'package:harukoto_mobile/features/study/data/lesson_checkpoint_store.dart';
import 'package:harukoto_mobile/features/study/data/lesson_study_activity_repository.dart';
import 'package:harukoto_mobile/features/study/data/models/lesson_models.dart';
import 'package:harukoto_mobile/features/study/domain/lesson_study_activity.dart';
import 'package:harukoto_mobile/features/study/domain/lesson_submission.dart';
import 'package:harukoto_mobile/features/study/domain/study_repository.dart';
import 'package:harukoto_mobile/features/study/providers/lesson_activity_sync_provider.dart';
import 'package:harukoto_mobile/features/study/providers/lesson_session_provider.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const activityOwner = '11111111-1111-4111-8111-111111111111';
const activityOtherOwner = '22222222-2222-4222-8222-222222222222';
const activityLesson = '33333333-3333-4333-8333-333333333333';
const activityOtherLesson = '44444444-4444-4444-8444-444444444444';
const activityWater = '55555555-5555-4555-8555-555555555555';
const activityCoffee = '66666666-6666-4666-8666-666666666666';
final activityVersion = List.filled(64, 'a').join();

LessonStudyActivityDraft activityDraft(
        {String owner = activityOwner,
        String? attemptId,
        String kind = 'RECOGNITION',
        Map<String, dynamic>? answer}) =>
    LessonStudyActivityDraft.create(
        owner: owner,
        attemptId: attemptId ?? newLessonActivityId(),
        contentVersion: activityVersion,
        kind: kind,
        answer: answer ?? {'questionOrder': 1, 'selectedAnswer': 'b'});

LessonDetailModel activityDetail(
        {String? version,
        bool enabled = true,
        bool recognition = true,
        bool reorder = true,
        int reorderCount = 1}) =>
    LessonDetailModel(
      id: activityLesson,
      lessonNo: 1,
      chapterLessonNo: 1,
      title: 'One answer',
      topic: '인사',
      estimatedMinutes: 2,
      activityContentVersion: enabled ? version ?? activityVersion : null,
      content: LessonContentModel(
          reading: const ReadingModel(script: []),
          questions: [
            if (recognition)
              const LessonQuestionModel(
                  order: 1,
                  type: 'VOCAB_MCQ',
                  prompt: '水의 뜻은?',
                  options: [
                    QuizOptionModel(id: 'a', text: '물'),
                    QuizOptionModel(id: 'b', text: '책')
                  ]),
            if (reorder)
              for (var index = 0; index < reorderCount; index++)
                LessonQuestionModel(
                    order: 2 + index,
                    type: 'SENTENCE_REORDER',
                    prompt: '저는 학생입니다.',
                    tokens: ['私', 'です']),
          ]),
      vocabItems: const [
        VocabItemModel(
            id: activityWater,
            word: '水',
            reading: 'みず',
            meaningKo: '물',
            partOfSpeech: '명사'),
        VocabItemModel(
            id: activityCoffee,
            word: 'コーヒー',
            reading: '',
            meaningKo: '커피',
            partOfSpeech: '명사'),
      ],
      grammarItems: const [],
      progress: const LessonProgressModel(
          status: 'IN_PROGRESS', attempts: 0, scoreCorrect: 0, scoreTotal: 0),
    );

class ActivityRepositoryFixture implements LessonStudyActivityRepository {
  final receipts = <String, LessonStudyActivityReceipt>{};
  final posts = <Map<String, dynamic>>[];
  final gets = <String>[];
  final rejectedLessons = <String>{};
  int failures = 0;
  bool commitBeforeFailure = false;
  Completer<void>? postGate;
  Completer<void>? lookupGate;
  DateTime serverNow = DateTime.utc(2026, 11, 2, 6);

  @override
  Future<LessonStudyActivityReceipt> submit(
      String lessonId, LessonStudyActivityDraft request,
      {CancelToken? cancelToken}) async {
    posts.add(request.toJson());
    if (postGate != null) await postGate!.future;
    if (rejectedLessons.contains(lessonId)) {
      throw const ApiException(statusCode: 409, message: '레슨 내용이 바뀌었어요.');
    }
    final receipt = receipts[request.activityId] ??
        LessonStudyActivityReceipt(
            activityId: request.activityId,
            processedAt: serverNow,
            studyDate: serverNow
                .add(const Duration(hours: 9))
                .toIso8601String()
                .substring(0, 10));
    if (commitBeforeFailure) receipts[request.activityId] = receipt;
    if (failures > 0) {
      failures--;
      throw const ApiException(statusCode: 503, message: '다시 확인해 주세요.');
    }
    return receipts.putIfAbsent(request.activityId, () => receipt);
  }

  @override
  Future<LessonStudyActivityReceipt?> lookup(
      String lessonId, String activityId, String owner,
      {CancelToken? cancelToken}) async {
    gets.add(activityId);
    if (lookupGate != null) await lookupGate!.future;
    return receipts[activityId];
  }
}

class ActivityStudyRepositoryFixture extends Fake implements StudyRepository {
  ActivityStudyRepositoryFixture(this.detail);
  final LessonDetailModel detail;
  int submissions = 0;

  @override
  Future<LessonDetailModel> fetchLessonDetail(String id) async => detail;

  @override
  Future<LessonProgressModel> startLesson(String id) async => detail.progress!;

  @override
  Future<LessonSubmissionReceiptModel> submitLessonIdempotent(
      String lessonId, LessonSubmissionDraft draft) async {
    submissions++;
    return LessonSubmissionReceiptModel(
        submissionId: draft.submissionId,
        processedAt: DateTime.utc(2026, 11, 2),
        result: const LessonSubmitResultModel(
            status: 'COMPLETED',
            scoreCorrect: 0,
            scoreTotal: 2,
            srsItemsRegistered: 2,
            results: []));
  }
}

class ActivityHarness {
  ActivityHarness(
      {required SharedPreferences preferences,
      ActivityRepositoryFixture? activityRepository,
      LessonDetailModel? detail,
      PreferencesLessonCheckpointStore? checkpointStore}) {
    store = checkpointStore ?? PreferencesLessonCheckpointStore(preferences);
    repository = activityRepository ?? ActivityRepositoryFixture();
    study = ActivityStudyRepositoryFixture(detail ?? activityDetail());
    container = ProviderContainer(overrides: [
      currentAccountIdProvider.overrideWith((ref) => owner),
      currentAccountReaderProvider.overrideWithValue(() => owner),
      sharedPreferencesProvider.overrideWithValue(preferences),
      lessonCheckpointStoreProvider.overrideWithValue(store),
      lessonStudyActivityRepositoryProvider.overrideWithValue(repository),
      studyRepositoryProvider.overrideWithValue(study),
      studyActivityRefreshProvider
          .overrideWith((ref) => _ActivityRefresh(ref, () => refreshes++)),
    ]);
    container.listen(lessonSessionProvider(activityLesson), (_, __) {});
  }
  String? owner = activityOwner;
  int refreshes = 0;
  late final ProviderContainer container;
  late final PreferencesLessonCheckpointStore store;
  late final ActivityRepositoryFixture repository;
  late final ActivityStudyRepositoryFixture study;

  LessonSessionController get controller =>
      container.read(lessonSessionProvider(activityLesson).notifier);
  LessonSessionState get state =>
      container.read(lessonSessionProvider(activityLesson));
  LessonActivitySyncState get syncState =>
      container.read(lessonActivitySyncProvider);

  Future<void> start() async {
    await controller.initialize(study.detail);
    controller.goToVocabLearning();
    controller.goToGuidedReading();
    await controller.startPractice(study.detail);
  }

  Future<void> sync() =>
      container.read(lessonActivitySyncProvider.notifier).sync();
  void switchAccount(String next) {
    owner = next;
    container.invalidate(currentAccountIdProvider);
    container.read(lessonActivitySyncProvider);
  }

  void dispose() => container.dispose();
}

class _ActivityRefresh extends StudyActivityRefresh {
  _ActivityRefresh(super.ref, this.onRefresh);
  final void Function() onRefresh;
  @override
  void refresh() => onRefresh();
}

Future<void> activityFlush() async {
  for (var i = 0; i < 15; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

String canonicalActivity(LessonStudyActivityDraft value) =>
    jsonEncode(value.toJson());
