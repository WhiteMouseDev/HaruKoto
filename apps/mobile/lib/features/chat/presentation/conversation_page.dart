import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../../../shared/widgets/app_error_retry.dart';
import '../data/models/chat_message_model.dart';
import '../data/models/scenario_model.dart';
import '../providers/conversation_bootstrap_provider.dart';
import '../providers/conversation_end_provider.dart';
import '../providers/chat_provider.dart';
import 'conversation_feedback_launch.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/typing_indicator.dart';

const _difficultyLabels = {
  'BEGINNER': '초급',
  'INTERMEDIATE': '중급',
  'ADVANCED': '고급',
};

class ConversationPage extends ConsumerStatefulWidget {
  final String conversationId;
  final ScenarioModel? initialScenario;
  final FirstMessage? firstMessage;

  const ConversationPage({
    super.key,
    required this.conversationId,
    this.initialScenario,
    this.firstMessage,
  });

  @override
  ConsumerState<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends ConsumerState<ConversationPage> {
  final _scrollController = ScrollController();
  final List<ChatMessageModel> _messages = [];
  ScenarioModel? _scenario;
  bool _showTranslation = true;
  bool _isTyping = false;
  String? _currentHint;
  bool _showHint = false;
  final List<VocabularyItem> _allVocabulary = [];
  bool _ending = false;
  bool _bootstrapped = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.firstMessage == null) return;
    _applyBootstrap(
      ConversationBootstrapData(
        scenario: widget.initialScenario,
        messages: [
          ChatMessageModel(
            id: 'ai-0',
            role: 'ai',
            messageJa: widget.firstMessage!.messageJa,
            messageKo: widget.firstMessage!.messageKo,
          ),
        ],
        currentHint: widget.firstMessage!.hint,
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _applyBootstrap(ConversationBootstrapData data) {
    _scenario = data.scenario;
    _currentHint = data.currentHint;
    _messages
      ..clear()
      ..addAll(data.messages);
    _bootstrapped = true;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSendMessage(String text) async {
    final userMsg = ChatMessageModel(
      id: 'user-${DateTime.now().millisecondsSinceEpoch}',
      role: 'user',
      messageJa: text,
    );
    setState(() {
      _messages.add(userMsg);
      _isTyping = true;
      _showHint = false;
      _error = null;
    });
    _scrollToBottom();

    try {
      final repo = ref.read(chatRepositoryProvider);
      final data = await repo.sendMessage(
        conversationId: widget.conversationId,
        message: text,
      );
      if (!mounted) return;

      setState(() {
        // Update user message with feedback
        final idx = _messages.indexWhere((m) => m.id == userMsg.id);
        if (idx >= 0) {
          _messages[idx] = _messages[idx].copyWith(feedback: data.feedback);
        }

        // Add AI response
        _messages.add(ChatMessageModel(
          id: 'ai-${DateTime.now().millisecondsSinceEpoch}',
          role: 'ai',
          messageJa: data.messageJa,
          messageKo: data.messageKo,
        ));
        _currentHint = data.hint;
        _allVocabulary.addAll(data.newVocabulary);
        _isTyping = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '메시지 전송에 실패했습니다.';
        _isTyping = false;
      });
    }
  }

  Future<void> _handleEndConversation() async {
    setState(() {
      _ending = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(conversationEndServiceProvider)
          .endConversation(widget.conversationId);
      if (!mounted) return;
      openConversationFeedbackPage(
        context,
        conversationId: widget.conversationId,
        initialFeedback: result.feedbackSummary,
        vocabulary: _allVocabulary.isEmpty
            ? null
            : List<VocabularyItem>.from(_allVocabulary),
        replace: true,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '대화를 종료할 수 없습니다.';
        _ending = false;
      });
    }
  }

  Widget _buildMessageList(ThemeData theme, ColorScheme colorScheme) {
    final hasScenario =
        _scenario?.situation != null && _scenario!.situation.isNotEmpty;
    // header (scenario) + messages + typing indicator + error
    final extraCount =
        (hasScenario ? 1 : 0) + (_isTyping ? 1 : 0) + (_error != null ? 1 : 0);
    final itemCount = _messages.length + extraCount;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppSizes.md),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        var i = index;

        // Scenario context card
        if (hasScenario) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.md),
              child: Container(
                padding: const EdgeInsets.all(AppSizes.md),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(LucideIcons.clipboardList,
                            size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          '상황 설명',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _scenario!.situation,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '나의 역할: ${_scenario!.yourRole} · AI 역할: ${_scenario!.aiRole}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          i -= 1;
        }

        // Message bubbles
        if (i < _messages.length) {
          final msg = _messages[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.md),
            child: ChatBubble(
              role: msg.role,
              messageJa: msg.messageJa,
              messageKo: msg.messageKo,
              feedback: msg.feedback,
              showTranslation: _showTranslation,
            ),
          );
        }
        i -= _messages.length;

        // Typing indicator
        if (_isTyping) {
          if (i == 0) {
            return const Align(
              alignment: Alignment.centerLeft,
              child: TypingIndicatorWidget(),
            );
          }
          i -= 1;
        }

        // Error
        if (_error != null && i == 0) {
          return Container(
            margin: const EdgeInsets.only(top: AppSizes.sm),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.md, vertical: AppSizes.sm),
            decoration: BoxDecoration(
              color: AppColors.hkRedLight.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: Text(
              _error!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.hkRedLight),
              textAlign: TextAlign.center,
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bootstrapProvider =
        conversationBootstrapProvider(widget.conversationId);

    if (!_bootstrapped) {
      ref.listen<AsyncValue<ConversationBootstrapData>>(
        bootstrapProvider,
        (previous, next) {
          if (!mounted || _bootstrapped) return;
          next.whenData((data) {
            setState(() {
              _applyBootstrap(data);
            });
          });
        },
      );

      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(LucideIcons.arrowLeft),
          ),
        ),
        body: ref.watch(bootstrapProvider).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => AppErrorRetry(
                onRetry: () => ref.invalidate(bootstrapProvider),
              ),
              data: (_) => const Center(child: CircularProgressIndicator()),
            ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(LucideIcons.arrowLeft),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _scenario?.title ?? 'AI 회화',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
            if (_scenario != null)
              Text(
                '${_difficultyLabels[_scenario!.difficulty] ?? _scenario!.difficulty} · 역할: ${_scenario!.yourRole}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () =>
                setState(() => _showTranslation = !_showTranslation),
            icon: Icon(_showTranslation ? LucideIcons.eye : LucideIcons.eyeOff,
                size: 20),
            tooltip: _showTranslation ? '번역 숨기기' : '번역 보기',
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages area
          Expanded(
            child: _buildMessageList(theme, colorScheme),
          ),

          // End conversation button
          if (_messages.length >= 2)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.md, vertical: AppSizes.sm),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Center(
                child: OutlinedButton.icon(
                  onPressed:
                      (_ending || _isTyping) ? null : _handleEndConversation,
                  icon: Icon(LucideIcons.logOut,
                      size: 14,
                      color: colorScheme.onSurface.withValues(alpha: 0.6)),
                  label: Text(
                    _ending ? '종료 중...' : '대화 끝내기',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ),

          // Input area
          ChatInputBar(
            onSend: _handleSendMessage,
            onHint: () => setState(() => _showHint = !_showHint),
            hint: _showHint ? _currentHint : null,
            disabled: _isTyping || _ending,
          ),
        ],
      ),
    );
  }
}
