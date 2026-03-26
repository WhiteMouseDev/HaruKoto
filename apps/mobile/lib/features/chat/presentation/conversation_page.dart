import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../../../shared/widgets/app_error_retry.dart';
import '../data/models/chat_message_model.dart';
import '../data/models/scenario_model.dart';
import '../providers/conversation_session_provider.dart';
import 'conversation_feedback_launch.dart';
import 'conversation_launch.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/typing_indicator.dart';

const _difficultyLabels = {
  'BEGINNER': '초급',
  'INTERMEDIATE': '중급',
  'ADVANCED': '고급',
};

class ConversationPage extends ConsumerStatefulWidget {
  const ConversationPage({
    super.key,
    required this.conversationId,
    this.initialScenario,
    this.firstMessage,
  });

  final String conversationId;
  final ScenarioModel? initialScenario;
  final FirstMessage? firstMessage;

  @override
  ConsumerState<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends ConsumerState<ConversationPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future(() {
      ref.read(conversationSessionProvider.notifier).initialize(
            ConversationLaunchRequest(
              conversationId: widget.conversationId,
              initialScenario: widget.initialScenario,
              firstMessage: widget.firstMessage,
            ),
          );
    });
  }

  @override
  void dispose() {
    final container = ProviderScope.containerOf(context, listen: false);
    Future(() => container.invalidate(conversationSessionProvider));
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _handleEndConversation() async {
    final result =
        await ref.read(conversationSessionProvider.notifier).endConversation();
    if (!mounted || result == null) return;

    final session = ref.read(conversationSessionProvider);
    openConversationFeedbackPage(
      context,
      conversationId: widget.conversationId,
      initialFeedback: result.feedbackSummary,
      vocabulary: session.allVocabulary.isEmpty
          ? null
          : List<VocabularyItem>.from(session.allVocabulary),
      replace: true,
    );
  }

  Widget _buildMessageList(
    ThemeData theme,
    ColorScheme colorScheme,
    ConversationSessionState session,
  ) {
    final scenario = session.scenario;
    final hasScenario =
        scenario?.situation != null && scenario!.situation.isNotEmpty;
    final extraCount = (hasScenario ? 1 : 0) +
        (session.isTyping ? 1 : 0) +
        (session.errorMessage != null ? 1 : 0);
    final itemCount = session.messages.length + extraCount;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppSizes.md),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        var i = index;

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
                        const Icon(
                          LucideIcons.clipboardList,
                          size: 14,
                          color: AppColors.primary,
                        ),
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
                      scenario.situation,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '나의 역할: ${scenario.yourRole} · AI 역할: ${scenario.aiRole}',
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

        if (i < session.messages.length) {
          final message = session.messages[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.md),
            child: ChatBubble(
              role: message.role,
              messageJa: message.messageJa,
              messageKo: message.messageKo,
              feedback: message.feedback,
              showTranslation: session.showTranslation,
            ),
          );
        }
        i -= session.messages.length;

        if (session.isTyping) {
          if (i == 0) {
            return const Align(
              alignment: Alignment.centerLeft,
              child: TypingIndicatorWidget(),
            );
          }
          i -= 1;
        }

        if (session.errorMessage != null && i == 0) {
          return Container(
            margin: const EdgeInsets.only(top: AppSizes.sm),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md,
              vertical: AppSizes.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.hkRedLight.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: Text(
              session.errorMessage!,
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
    final session = ref.watch(conversationSessionProvider);

    ref.listen(conversationSessionProvider, (previous, next) {
      if (!mounted) return;
      final previousCount = previous?.messages.length ?? 0;
      if (next.messages.length != previousCount ||
          next.isTyping != previous?.isTyping ||
          (previous?.status != next.status && next.isReady)) {
        _scrollToBottom();
      }
    });

    if (session.isLoading) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(LucideIcons.arrowLeft),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (session.hasLoadError) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(LucideIcons.arrowLeft),
          ),
        ),
        body: AppErrorRetry(
          onRetry: () => unawaited(
            ref.read(conversationSessionProvider.notifier).retryBootstrap(),
          ),
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
              session.scenario?.title ?? 'AI 회화',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
            if (session.scenario != null)
              Text(
                '${_difficultyLabels[session.scenario!.difficulty] ?? session.scenario!.difficulty} · 역할: ${session.scenario!.yourRole}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => ref
                .read(conversationSessionProvider.notifier)
                .toggleTranslation(),
            icon: Icon(
              session.showTranslation ? LucideIcons.eye : LucideIcons.eyeOff,
              size: 20,
            ),
            tooltip: session.showTranslation ? '번역 숨기기' : '번역 보기',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildMessageList(theme, colorScheme, session),
          ),
          if (session.canEndConversation)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.md,
                vertical: AppSizes.sm,
              ),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Center(
                child: OutlinedButton.icon(
                  onPressed: session.isInteractionDisabled
                      ? null
                      : _handleEndConversation,
                  icon: Icon(
                    LucideIcons.logOut,
                    size: 14,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  label: Text(
                    session.isEnding ? '종료 중...' : '대화 끝내기',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ),
          ChatInputBar(
            onSend: (text) => unawaited(
              ref.read(conversationSessionProvider.notifier).sendMessage(text),
            ),
            onHint: () =>
                ref.read(conversationSessionProvider.notifier).toggleHint(),
            hint: session.showHint ? session.currentHint : null,
            disabled: session.isInteractionDisabled,
          ),
        ],
      ),
    );
  }
}
