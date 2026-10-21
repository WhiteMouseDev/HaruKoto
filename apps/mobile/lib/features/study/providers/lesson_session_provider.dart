import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_account_provider.dart';
import '../../../core/network/api_exception.dart';
import '../data/lesson_checkpoint_store.dart';
import '../data/models/lesson_models.dart';
import '../domain/lesson_checkpoint.dart';
import '../domain/lesson_flow_policy.dart';
import '../domain/lesson_practice_layout.dart';
import '../domain/lesson_session_state.dart';
import 'lesson_pilot_telemetry_provider.dart';
import 'lesson_session_service.dart';
import 'study_provider.dart';

export '../domain/lesson_session_state.dart';

/// A fresh account-bound GET for every visit; never hydrate an account's draft
/// using a cached detail response belonging to a previous signed-in account.
final lessonResumeDetailProvider = FutureProvider.autoDispose
    .family<LessonDetailModel, String>((ref, lessonId) async {
  final owner = ref.watch(currentAccountIdProvider);
  final detail =
      await ref.read(studyRepositoryProvider).fetchLessonDetail(lessonId);
  if (!ref.mounted || ref.read(currentAccountReaderProvider)() != owner) {
    throw const LessonCheckpointStorageException();
  }
  await ref.read(lessonSessionProvider(lessonId).notifier).initialize(detail);
  return detail;
});

class LessonSessionController extends Notifier<LessonSessionState> {
  LessonSessionController(this.lessonId);
  final String lessonId;

  String? _owner;
  int _generation = 0;
  int _writeVersion = 0;
  bool _initialized = false;
  bool _acknowledged = false;
  bool _closing = false;
  bool _preserveRawCheckpoint = false;
  LessonDetailModel? _detail;
  String _progressStamp = 'null';
  Future<void>? _initializing;

  LessonSessionActions get actions => LessonSessionActions._(this, _generation);

  @override
  LessonSessionState build() {
    _owner = ref.watch(currentAccountIdProvider);
    _generation++;
    _writeVersion = 0;
    _initialized = false;
    _acknowledged = false;
    _closing = false;
    _preserveRawCheckpoint = false;
    _detail = null;
    _initializing = null;
    ref.onDispose(() => _generation++);
    return const LessonSessionState();
  }

  bool _current(int generation) =>
      ref.mounted &&
      generation == _generation &&
      _owner != null &&
      ref.read(currentAccountReaderProvider)() == _owner;

  bool get _editable =>
      _initialized &&
      !_closing &&
      _current(_generation) &&
      !state.submitting &&
      !state.starting &&
      !state.submissionPending &&
      !state.serverRecorded &&
      state.result == null;

  Future<void> initialize(LessonDetailModel detail) {
    if (_initialized) return Future<void>.value();
    final generation = _generation;
    return _initializing ??= _initialize(detail).whenComplete(() {
      if (_current(generation)) _initializing = null;
    });
  }

  Future<void> _initialize(LessonDetailModel detail) async {
    final generation = _generation;
    final owner = _owner;
    if (owner == null) throw const LessonCheckpointStorageException();
    final store = ref.read(lessonCheckpointStoreProvider);
    final raw = await store.read(owner, lessonId);
    if (!_current(generation)) return;
    _detail = detail;
    _progressStamp = lessonProgressStamp(detail.progress);
    final seed = Random.secure().nextInt(1 << 30);
    state = LessonSessionState(
      seed: seed,
      layout: LessonPracticeLayout.create(detail, seed),
      hasRecognitionStep: lessonRecognitionQuestions(detail).isNotEmpty,
      hasReorderStep: lessonReorderQuestions(detail).isNotEmpty,
    );
    _initialized = true;
    if (raw == null) {
      if (detail.progress?.status == 'IN_PROGRESS') {
        state = state.copyWith(
            notice: '이 기기에 저장된 진행이 없어 처음부터 안내해 드려요. 기존 학습 기록은 그대로예요.');
      }
      return;
    }
    try {
      final checkpoint = LessonCheckpoint.decode(raw, detail);
      if (checkpoint.acknowledged) {
        _acknowledged = true;
        state = state.copyWith(
            serverRecorded: true,
            serverProgress: detail.progress,
            notice: '제출이 완료된 레슨이에요. 저장된 답안을 다시 보내지 않아요.');
        await _clearCheckpoint();
      } else if (checkpoint.progressStamp != _progressStamp &&
          !_startOnlyProgressChange(checkpoint, detail.progress)) {
        state = state.copyWith(
            serverRecorded: true,
            serverProgress: detail.progress,
            notice: '서버의 레슨 기록이 변경됐어요. 중복 제출을 막기 위해 저장된 답안을 다시 보내지 않아요.');
        await _clearCheckpoint();
      } else {
        state = checkpoint.state.copyWith(
          notice: checkpoint.state.submissionPending
              ? '제출 결과를 확인하고 있어요. 중복 반영을 막기 위해 답안을 다시 보내지 않아요.'
              : '이 기기에 저장된 위치에서 이어서 학습해요.',
        );
      }
    } on FormatException {
      if (_knownNonPending(raw)) {
        state = state.copyWith(
            notice: '레슨 내용이나 저장 형식이 바뀌어 처음부터 안내해 드려요. 서버의 학습 기록은 그대로예요.');
        await _clearCheckpoint();
        return;
      }
      _preserveRawCheckpoint = true;
      // Unreadable data could contain a pending POST. Do not silently turn it
      // into a new attempt; a local reset must not manufacture exactly-once.
      state = state.copyWith(
          submissionPending: true,
          notice:
              '저장된 이어하기 정보를 안전하게 읽을 수 없어요. 레슨 기록을 확인해 주세요. 답안을 자동으로 다시 보내지 않아요.');
    }
  }

  bool _startOnlyProgressChange(
      LessonCheckpoint checkpoint, LessonProgressModel? progress) {
    if (checkpoint.state.practiceStarted ||
        checkpoint.state.submissionPending ||
        progress?.status != 'IN_PROGRESS' ||
        progress?.attempts != 0) {
      return false;
    }
    try {
      final old = jsonDecode(checkpoint.progressStamp);
      return old == null ||
          (old is Map<String, dynamic> &&
              old['status'] == 'NOT_STARTED' &&
              old['attempts'] == 0);
    } on FormatException {
      return false;
    }
  }

  bool _knownNonPending(String raw) {
    if (raw.length > 512 * 1024) return false;
    try {
      final json = jsonDecode(raw);
      return json is Map<String, dynamic> &&
          json['lessonId'] == lessonId &&
          json['submissionPending'] == false &&
          json['acknowledged'] == false;
    } on FormatException {
      return false;
    }
  }

  Future<bool> _persist() {
    if (_preserveRawCheckpoint) return Future<bool>.value(true);
    final detail = _detail;
    final owner = _owner;
    if (detail == null ||
        owner == null ||
        !_initialized ||
        !_current(_generation)) {
      return Future<bool>.value(false);
    }
    final generation = _generation;
    final version = ++_writeVersion;
    final payload = LessonCheckpoint(
            state: state,
            progressStamp: _progressStamp,
            acknowledged: _acknowledged)
        .encode(detail);
    if (payload.length > 512 * 1024) {
      state = state.copyWith(storageError: true);
      return Future<bool>.value(false);
    }
    final store = ref.read(lessonCheckpointStoreProvider);
    final write = (() async {
      try {
        await store.write(owner, lessonId, payload);
        if (_current(generation) && version == _writeVersion) {
          state = state.copyWith(storageError: false);
        }
        return true;
      } catch (_) {
        if (_current(generation)) state = state.copyWith(storageError: true);
        return false;
      }
    })();
    return write;
  }

  Future<bool> _clearCheckpoint() {
    final owner = _owner;
    if (owner == null || !_current(_generation)) {
      return Future<bool>.value(false);
    }
    final generation = _generation;
    final store = ref.read(lessonCheckpointStoreProvider);
    final version = ++_writeVersion;
    final removal = (() async {
      try {
        await store.remove(owner, lessonId);
        if (_current(generation) && version == _writeVersion) {
          state = state.copyWith(storageError: false);
        }
        return true;
      } catch (_) {
        if (_current(generation)) state = state.copyWith(storageError: true);
        return false;
      }
    })();
    return removal;
  }

  /// Explicit navigation waits for durable writes. OS termination can interrupt
  /// a write; the UI never promises persistence when a write has failed.
  Future<bool> flush() async {
    if (!_initialized) return true;
    if (_acknowledged || state.serverRecorded) return _clearCheckpoint();
    return _persist();
  }

  void _change(LessonSessionState next) {
    if (!_editable) return;
    state = next;
    unawaited(_persist());
  }

  void goToVocabLearning() {
    if (!_editable || state.step != LessonStep.contextPreview) return;
    _trackStepCompleted(state.step);
    _change(state.copyWith(step: LessonStep.vocabLearning));
  }

  void goToGrammarLearning() {
    if (!_editable || state.step != LessonStep.vocabLearning) return;
    _trackStepCompleted(state.step);
    _change(state.copyWith(step: LessonStep.grammarLearning));
  }

  void goToGuidedReading() {
    if (!_editable ||
        (state.step != LessonStep.grammarLearning &&
            !(state.step == LessonStep.vocabLearning &&
                (_detail?.grammarItems.isEmpty ?? true)))) {
      return;
    }
    _trackStepCompleted(state.step);
    _change(state.copyWith(step: LessonStep.guidedReading));
  }

  void setVocabIndex(int index) {
    if (state.step == LessonStep.vocabLearning) {
      _change(state.copyWith(vocabIndex: index));
    }
  }

  void setGrammarIndex(int index) {
    if (state.step == LessonStep.grammarLearning) {
      _change(state.copyWith(grammarIndex: index));
    }
  }

  void selectRecognition(String selected) {
    if (state.step == LessonStep.recognition) {
      _change(state.copyWith(recognitionSelection: selected));
    }
  }

  void updateMatching({required Set<int> matched, int? left, int? right}) {
    if (state.step == LessonStep.matching) {
      _change(state.copyWith(
          matchingMatched: Set<int>.from(matched),
          matchingLeft: left,
          matchingRight: right));
    }
  }

  void updateReorder(
      {required List<String> selected, required List<String> available}) {
    if (state.step == LessonStep.sentenceReorder) {
      _change(state.copyWith(
          reorderSelected: List<String>.from(selected),
          reorderAvailable: List<String>.from(available)));
    }
  }

  void goBack() {
    if (!_editable || state.canPop) return;
    final previousStep = switch (state.step) {
      LessonStep.matching when !state.hasRecognitionStep =>
        LessonStep.guidedReading,
      LessonStep.guidedReading when _detail?.grammarItems.isEmpty ?? true =>
        LessonStep.vocabLearning,
      _ => LessonStep.values[state.step.index - 1],
    };
    _change(state.copyWith(step: previousStep));
  }

  Future<void> startPractice(LessonDetailModel detail) async {
    if (!_initialized) await initialize(detail);
    if (!_editable || state.starting) return;
    if (state.practiceStarted) {
      _change(state.copyWith(
          step: state.hasRecognitionStep
              ? LessonStep.recognition
              : LessonStep.matching));
      return;
    }
    final generation = _generation;
    final service = ref.read(lessonSessionServiceProvider);
    final telemetry = ref.read(lessonPilotTelemetryProvider);
    state = state.copyWith(starting: true, startErrorMessage: null);
    try {
      final progress = await service.startLesson(detail.id);
      if (!_current(generation)) return;
      _progressStamp = lessonProgressStamp(progress);
    } catch (error) {
      if (_current(generation)) {
        state = state.copyWith(
            starting: false, startErrorMessage: _userMessage(error));
      }
      return;
    }
    if (!_current(generation)) return;
    final plan = buildLessonPracticePlan(detail);
    telemetry.trackLessonStarted(
        lessonId: detail.id,
        lessonNo: detail.lessonNo,
        chapterLessonNo: detail.chapterLessonNo,
        hasRecognitionStep: plan.hasRecognitionStep,
        hasReorderStep: plan.hasReorderStep,
        recognitionQuestionCount: plan.recognitionQuestions.length,
        reorderQuestionCount: plan.reorderQuestions.length);
    state = state.copyWith(
        step: plan.hasRecognitionStep
            ? LessonStep.recognition
            : LessonStep.matching,
        hasRecognitionStep: plan.hasRecognitionStep,
        hasReorderStep: plan.hasReorderStep,
        practiceStarted: true,
        starting: false);
    await _persist();
  }

  void skipRecognition() {
    if (!_editable) return;
    _trackStepCompleted(LessonStep.recognition, skipped: true);
    _change(state.copyWith(step: LessonStep.matching));
  }

  void answerRecognition(
      LessonDetailModel detail, Map<String, dynamic> answer) {
    if (!_editable || state.step != LessonStep.recognition) return;
    final questions = lessonRecognitionQuestions(detail);
    final question = questions[state.recognitionIndex];
    if (answer['order'] != question.order) return;
    final answers = Map<int, Map<String, dynamic>>.from(state.answers)
      ..[question.order] = Map<String, dynamic>.from(answer);
    if (state.recognitionIndex < questions.length - 1) {
      _change(state.copyWith(
          answers: answers,
          recognitionSelection: null,
          recognitionIndex: state.recognitionIndex + 1));
    } else {
      _trackStepCompleted(LessonStep.recognition);
      _change(state.copyWith(
          answers: answers,
          recognitionSelection: null,
          step: LessonStep.matching));
    }
  }

  Future<void> completeMatching(
      {required LessonDetailModel detail, String? jlptLevel}) async {
    if (!_editable) return;
    if (state.step != LessonStep.matching) return;
    _trackStepCompleted(LessonStep.matching);
    if (!state.hasReorderStep) {
      await submitAnswers(lessonId: detail.id, jlptLevel: jlptLevel);
    } else {
      _change(state.copyWith(step: LessonStep.sentenceReorder));
    }
  }

  Future<void> answerReorder(
      {required LessonDetailModel detail,
      required Map<String, dynamic> answer,
      String? jlptLevel}) async {
    if (!_editable || state.step != LessonStep.sentenceReorder) return;
    final questions = lessonReorderQuestions(detail);
    final question = questions[state.reorderIndex];
    if (answer['order'] != question.order) return;
    final answers = Map<int, Map<String, dynamic>>.from(state.answers)
      ..[question.order] = Map<String, dynamic>.from(answer);
    if (state.reorderIndex < questions.length - 1) {
      _change(state.copyWith(
          answers: answers,
          reorderIndex: state.reorderIndex + 1,
          reorderSelected: const [],
          reorderAvailable: null));
    } else {
      _trackStepCompleted(LessonStep.sentenceReorder);
      _change(state.copyWith(answers: answers));
      await submitAnswers(lessonId: detail.id, jlptLevel: jlptLevel);
    }
  }

  Future<void> submitAnswers(
      {required String lessonId, String? jlptLevel}) async {
    if (!_initialized || !_editable) return;
    final generation = _generation;
    final service = ref.read(lessonSessionServiceProvider);
    final telemetry = ref.read(lessonPilotTelemetryProvider);
    final ordered = state.answers.keys.toList()..sort();
    final answers = [
      for (final key in ordered) Map<String, dynamic>.from(state.answers[key]!)
    ];
    state = state.copyWith(
        submitting: true,
        submissionPending: true,
        submissionErrorMessage: null);
    // A durable pending marker must precede a non-idempotent POST.
    if (!await _persist()) {
      if (_current(generation)) {
        state = state.copyWith(
            submitting: false,
            submissionPending: false,
            submissionErrorMessage: '답안을 기기에 저장하지 못해 제출하지 않았어요. 저장을 재시도해 주세요.');
      }
      return;
    }
    if (!_current(generation)) return;
    try {
      final result = await service.submitLesson(
          lessonId: lessonId, jlptLevel: jlptLevel, answers: answers);
      if (!_current(generation)) return;
      _acknowledged = true;
      state = state.copyWith(
          step: LessonStep.result,
          result: result,
          submitting: false,
          submissionPending: false,
          submissionErrorMessage: null);
      // If either operation fails, the old pending marker still prevents a
      // duplicate submission after restart. Never remove before writing it.
      await _persist();
      if (_current(generation)) await _clearCheckpoint();
      if (!_current(generation)) return;
      telemetry.trackLessonSubmitted(
          lessonId: lessonId,
          outcome: 'success',
          answerCount: ordered.length,
          status: result.status,
          scoreCorrect: result.scoreCorrect,
          scoreTotal: result.scoreTotal,
          srsItemsRegistered: result.srsItemsRegistered);
      if (result.status == 'COMPLETED') {
        telemetry.trackLessonCompleted(
            lessonId: lessonId,
            scoreCorrect: result.scoreCorrect,
            scoreTotal: result.scoreTotal,
            srsItemsRegistered: result.srsItemsRegistered);
      }
    } catch (error) {
      if (!_current(generation)) return;
      telemetry.trackLessonSubmitted(
          lessonId: lessonId,
          outcome: 'failure',
          answerCount: ordered.length,
          errorType: error.runtimeType.toString());
      state = state.copyWith(
          submitting: false,
          submissionErrorMessage: '${_userMessage(error)} 제출 결과를 먼저 확인해 주세요.',
          notice: '중복 반영을 막기 위해 답안을 다시 보내지 않아요. 아래에서 서버 기록을 확인할 수 있어요.');
      await _persist();
    }
  }

  Future<void> checkSubmission() async {
    if (!_initialized || !state.submissionPending || state.submitting) return;
    final generation = _generation;
    final repository = ref.read(studyRepositoryProvider);
    state = state.copyWith(submitting: true);
    try {
      final detail = await repository.fetchLessonDetail(lessonId);
      if (!_current(generation)) return;
      final stamp = lessonProgressStamp(detail.progress);
      if (stamp != _progressStamp) {
        _detail = detail;
        _progressStamp = stamp;
        state = state.copyWith(
            submitting: false,
            submissionPending: false,
            serverRecorded: true,
            serverProgress: detail.progress,
            notice: '서버의 레슨 기록이 변경됐어요. 저장된 답안을 다시 보내지 않아요.');
        await _clearCheckpoint();
      } else {
        state = state.copyWith(
            submitting: false,
            notice:
                '아직 제출 결과를 확정할 수 없어요. 잠시 후 다시 확인해 주세요. 저장된 답안은 보관하고 다시 보내지 않아요.');
      }
    } catch (error) {
      if (_current(generation)) {
        state = state.copyWith(
            submitting: false, submissionErrorMessage: _userMessage(error));
      }
    }
  }

  void clearStartError() {
    if (state.startErrorMessage != null) {
      state = state.copyWith(startErrorMessage: null);
    }
  }

  void clearSubmissionError() {
    if (state.submissionErrorMessage != null) {
      state = state.copyWith(submissionErrorMessage: null);
    }
  }

  Future<void> reset() async {
    if (!_current(_generation) ||
        state.submissionPending ||
        state.serverRecorded ||
        state.submitting) {
      return;
    }
    final generation = _generation;
    final detail = _detail;
    if (detail == null || !await _clearCheckpoint() || !_current(generation)) {
      return;
    }
    ref
        .read(lessonPilotTelemetryProvider)
        .trackLessonRetryClicked(lessonId: lessonId);
    _initialized = false;
    _acknowledged = false;
    // The previous completed response is not a baseline for a new attempt.
    ref.invalidate(lessonResumeDetailProvider(lessonId));
  }

  void _trackStepCompleted(LessonStep step, {bool skipped = false}) {
    if (step == LessonStep.result) return;
    ref.read(lessonPilotTelemetryProvider).trackLessonStepCompleted(
        lessonId: lessonId, step: step.name, skipped: skipped);
  }
}

String _userMessage(Object error) => switch (error) {
      final ApiException exception => exception.userMessage,
      final DioException exception =>
        ApiException.fromDioException(exception).userMessage,
      _ => '일시적인 오류가 발생했어요. 잠시 후 다시 시도해 주세요.',
    };

final lessonSessionProvider = NotifierProvider.autoDispose
    .family<LessonSessionController, LessonSessionState, String>(
        (lessonId) => LessonSessionController(lessonId));

/// Widget callbacks carry the identity generation of the frame that created
/// them. A disposed animation from account A cannot act on account B's state.
class LessonSessionActions {
  const LessonSessionActions._(this._controller, this._generation);
  final LessonSessionController _controller;
  final int _generation;
  bool get isCurrent => _controller._current(_generation);
  void beginClosing() {
    if (isCurrent) _controller._closing = true;
  }

  void cancelClosing() {
    if (isCurrent) _controller._closing = false;
  }

  bool get _current => isCurrent;
  void goToVocabLearning() {
    if (_current) _controller.goToVocabLearning();
  }

  void goToGrammarLearning() {
    if (_current) _controller.goToGrammarLearning();
  }

  void goToGuidedReading() {
    if (_current) _controller.goToGuidedReading();
  }

  void goBack() {
    if (_current) _controller.goBack();
  }

  void setVocabIndex(int value) {
    if (_current) _controller.setVocabIndex(value);
  }

  void setGrammarIndex(int value) {
    if (_current) _controller.setGrammarIndex(value);
  }

  void selectRecognition(String value) {
    if (_current) _controller.selectRecognition(value);
  }

  void skipRecognition() {
    if (_current) _controller.skipRecognition();
  }

  Future<void> startPractice(LessonDetailModel detail) async {
    if (_current) await _controller.startPractice(detail);
  }

  void answerRecognition(
      LessonDetailModel detail, Map<String, dynamic> answer) {
    if (_current) _controller.answerRecognition(detail, answer);
  }

  void updateMatching({required Set<int> matched, int? left, int? right}) {
    if (_current) {
      _controller.updateMatching(matched: matched, left: left, right: right);
    }
  }

  void updateReorder(
      {required List<String> selected, required List<String> available}) {
    if (_current) {
      _controller.updateReorder(selected: selected, available: available);
    }
  }

  Future<void> completeMatching(
      {required LessonDetailModel detail, String? jlptLevel}) async {
    if (_current) {
      await _controller.completeMatching(detail: detail, jlptLevel: jlptLevel);
    }
  }

  Future<void> answerReorder(
      {required LessonDetailModel detail,
      required Map<String, dynamic> answer,
      String? jlptLevel}) async {
    if (_current) {
      await _controller.answerReorder(
          detail: detail, answer: answer, jlptLevel: jlptLevel);
    }
  }

  Future<void> submitAnswers(
      {required String lessonId, String? jlptLevel}) async {
    if (_current) {
      await _controller.submitAnswers(lessonId: lessonId, jlptLevel: jlptLevel);
    }
  }

  Future<void> checkSubmission() async {
    if (_current) await _controller.checkSubmission();
  }

  Future<void> reset() async {
    if (_current) await _controller.reset();
  }

  Future<bool> flush() async => _current ? await _controller.flush() : false;
}
