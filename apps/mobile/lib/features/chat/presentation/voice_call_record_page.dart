import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/sizes.dart';
import '../../../shared/widgets/app_error_retry.dart';
import '../data/models/conversation_model.dart';
import '../providers/conversation_feedback_provider.dart';
import '../providers/voice_call_analysis_request_factory.dart';
import 'call_analysis_launch.dart';
import 'conversation_feedback_launch.dart';

/// Saved voice history never generates feedback merely by being opened.
class VoiceCallRecordPage extends ConsumerWidget {
  const VoiceCallRecordPage({super.key, required this.conversation});
  final ConversationModel conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = ref.watch(conversationDetailProvider(conversation.id));
    return Scaffold(
      appBar: AppBar(title: const Text('대화 기록')),
      body: record.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => AppErrorRetry(
            onRetry: () =>
                ref.invalidate(conversationDetailProvider(conversation.id))),
        data: (detail) {
          final ended = detail.endedAt != null;
          final transcript = detail.messages
              .where((message) =>
                  const ['user', 'assistant', 'ai'].contains(message.role) &&
                  message.messageJa.trim().isNotEmpty)
              .map((message) => <String, String>{
                    'role': message.role == 'user' ? 'user' : 'assistant',
                    'text': message.messageJa,
                  })
              .toList();
          final hasUserSpeech =
              transcript.any((turn) => turn['role'] == 'user');
          final request = VoiceCallAnalysisRequest(
            conversationId: conversation.id,
            transcript: transcript,
            // Persisted ended sessions reuse their original usage. There is no
            // measured duration field in the history API; do not infer it.
            durationSeconds: 0,
            recordSaved: ended,
            wasConnected: ended,
            analysisEnabled: ended,
            characterName: conversation.character?.name,
          );
          return ListView(
            padding: const EdgeInsets.all(AppSizes.lg),
            children: [
              Text(
                  conversation.character != null
                      ? '${conversation.character!.name}와의 통화'
                      : conversation.scenario?.title ?? '음성 대화',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSizes.sm),
              Text(ended
                  ? '저장된 대화 ${transcript.length}개 발화'
                  : '마무리되지 않은 연결 준비 기록'),
              if (!ended) ...[
                const SizedBox(height: AppSizes.md),
                const Text(
                    '앱이 닫히기 전에 저장되지 않은 발화는 복원할 수 없어요. 이 기록을 정리하고 새 대화를 시작할 수 있어요.'),
                const SizedBox(height: AppSizes.md),
                FilledButton(
                  onPressed: () => openCallAnalysisPage(context, request),
                  child: const Text('연결 준비 기록 정리하기'),
                ),
              ] else if (detail.feedbackSummary != null) ...[
                const SizedBox(height: AppSizes.md),
                FilledButton(
                  onPressed: () => openConversationFeedbackPage(context,
                      conversationId: conversation.id,
                      initialFeedback: detail.feedbackSummary),
                  child: const Text('저장된 피드백 보기'),
                ),
              ] else ...[
                const SizedBox(height: AppSizes.md),
                const Text('대화 기록이 저장되어 있어요. 원할 때만 피드백을 요청해 보세요.'),
                if (hasUserSpeech) ...[
                  const SizedBox(height: AppSizes.sm),
                  OutlinedButton(
                    onPressed: () => openCallAnalysisPage(context, request),
                    child: const Text('이 대화 피드백 요청하기'),
                  ),
                ],
              ],
              const SizedBox(height: AppSizes.lg),
              const Text('음성 인식으로 남긴 텍스트라 실제 말한 내용과 다를 수 있어요.'),
              const SizedBox(height: AppSizes.md),
              if (transcript.isEmpty) const Text('저장된 발화가 없어요.'),
              ...transcript.map((turn) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSizes.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(turn['role'] == 'user' ? '나' : '상대',
                            style: Theme.of(context).textTheme.labelMedium),
                        const SizedBox(height: AppSizes.xs),
                        Text(turn['text']!),
                      ],
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }
}
