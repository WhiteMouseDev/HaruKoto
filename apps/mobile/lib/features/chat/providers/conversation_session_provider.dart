import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_repository.dart' as chat_data;
import '../data/models/chat_message_model.dart';
import '../data/models/scenario_model.dart';
import '../presentation/conversation_launch.dart';
import 'conversation_bootstrap_provider.dart';
import 'conversation_end_provider.dart';
import 'conversation_message_service.dart';

enum ConversationSessionStatus {
  loading,
  ready,
  loadError,
}

class ConversationSessionState {
  const ConversationSessionState({
    this.status = ConversationSessionStatus.loading,
    this.scenario,
    this.messages = const [],
    this.showTranslation = true,
    this.currentHint,
    this.showHint = false,
    this.allVocabulary = const [],
    this.isTyping = false,
    this.isEnding = false,
    this.errorMessage,
  });

  static const _unset = Object();

  final ConversationSessionStatus status;
  final ScenarioModel? scenario;
  final List<ChatMessageModel> messages;
  final bool showTranslation;
  final String? currentHint;
  final bool showHint;
  final List<VocabularyItem> allVocabulary;
  final bool isTyping;
  final bool isEnding;
  final String? errorMessage;

  bool get isLoading => status == ConversationSessionStatus.loading;
  bool get hasLoadError => status == ConversationSessionStatus.loadError;
  bool get isReady => status == ConversationSessionStatus.ready;
  bool get canEndConversation => messages.length >= 2;
  bool get isInteractionDisabled => isTyping || isEnding;

  ConversationSessionState copyWith({
    ConversationSessionStatus? status,
    Object? scenario = _unset,
    List<ChatMessageModel>? messages,
    bool? showTranslation,
    Object? currentHint = _unset,
    bool? showHint,
    List<VocabularyItem>? allVocabulary,
    bool? isTyping,
    bool? isEnding,
    Object? errorMessage = _unset,
  }) {
    return ConversationSessionState(
      status: status ?? this.status,
      scenario: identical(scenario, _unset)
          ? this.scenario
          : scenario as ScenarioModel?,
      messages: messages ?? this.messages,
      showTranslation: showTranslation ?? this.showTranslation,
      currentHint: identical(currentHint, _unset)
          ? this.currentHint
          : currentHint as String?,
      showHint: showHint ?? this.showHint,
      allVocabulary: allVocabulary ?? this.allVocabulary,
      isTyping: isTyping ?? this.isTyping,
      isEnding: isEnding ?? this.isEnding,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class ConversationSessionController extends Notifier<ConversationSessionState> {
  ConversationLaunchRequest? _request;
  bool _disposed = false;
  int _generation = 0;

  @override
  ConversationSessionState build() {
    ref.onDispose(() {
      _disposed = true;
      _generation++;
    });
    return const ConversationSessionState();
  }

  Future<void> initialize(ConversationLaunchRequest request) async {
    _request = request;
    final generation = ++_generation;

    state = const ConversationSessionState();

    final firstMessage = request.firstMessage;
    if (firstMessage != null) {
      state = state.copyWith(
        status: ConversationSessionStatus.ready,
        scenario: request.initialScenario,
        messages: [
          ChatMessageModel(
            id: 'ai-0',
            role: 'ai',
            messageJa: firstMessage.messageJa,
            messageKo: firstMessage.messageKo,
          ),
        ],
        currentHint: firstMessage.hint,
        errorMessage: null,
      );
      return;
    }

    try {
      final bootstrap = await ref.read(
        conversationBootstrapProvider(request.conversationId).future,
      );
      if (_isStale(generation)) return;

      state = state.copyWith(
        status: ConversationSessionStatus.ready,
        scenario: bootstrap.scenario,
        messages: bootstrap.messages,
        currentHint: bootstrap.currentHint,
        errorMessage: null,
      );
    } catch (_) {
      if (_isStale(generation)) return;
      state = state.copyWith(
        status: ConversationSessionStatus.loadError,
        errorMessage: '대화를 불러올 수 없습니다.',
      );
    }
  }

  Future<void> retryBootstrap() async {
    final request = _request;
    if (request == null) return;
    await initialize(request);
  }

  void toggleTranslation() {
    state = state.copyWith(showTranslation: !state.showTranslation);
  }

  void toggleHint() {
    state = state.copyWith(showHint: !state.showHint);
  }

  Future<void> sendMessage(String text) async {
    final request = _request;
    if (request == null || !state.isReady || state.isInteractionDisabled) {
      return;
    }

    final userMessage = ChatMessageModel(
      id: _newMessageId('user'),
      role: 'user',
      messageJa: text,
    );
    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isTyping: true,
      showHint: false,
      errorMessage: null,
    );

    try {
      final reply = await ref.read(conversationMessageServiceProvider).send(
            conversationId: request.conversationId,
            message: text,
            aiMessageId: _newMessageId('ai'),
          );
      if (_disposed) return;

      final updatedMessages = [...state.messages];
      final userIndex =
          updatedMessages.indexWhere((item) => item.id == userMessage.id);
      if (userIndex >= 0) {
        updatedMessages[userIndex] = updatedMessages[userIndex].copyWith(
          feedback: reply.userFeedback,
        );
      }
      updatedMessages.add(reply.aiMessage);

      state = state.copyWith(
        messages: updatedMessages,
        currentHint: reply.hint,
        allVocabulary: [...state.allVocabulary, ...reply.newVocabulary],
        isTyping: false,
      );
    } catch (_) {
      if (_disposed) return;
      state = state.copyWith(
        errorMessage: '메시지 전송에 실패했습니다.',
        isTyping: false,
      );
    }
  }

  Future<chat_data.EndConversationResponse?> endConversation() async {
    final request = _request;
    if (request == null || state.isEnding) return null;

    state = state.copyWith(
      isEnding: true,
      errorMessage: null,
    );

    try {
      final response = await ref
          .read(conversationEndServiceProvider)
          .endConversation(request.conversationId);
      if (_disposed) return null;
      state = state.copyWith(isEnding: false);
      return response;
    } catch (_) {
      if (_disposed) return null;
      state = state.copyWith(
        isEnding: false,
        errorMessage: '대화를 종료할 수 없습니다.',
      );
      return null;
    }
  }

  bool _isStale(int generation) => _disposed || generation != _generation;

  String _newMessageId(String prefix) {
    return '$prefix-${DateTime.now().millisecondsSinceEpoch}';
  }
}

final conversationSessionProvider =
    NotifierProvider<ConversationSessionController, ConversationSessionState>(
  ConversationSessionController.new,
);
