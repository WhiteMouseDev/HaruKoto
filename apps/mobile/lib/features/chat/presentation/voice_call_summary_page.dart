import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/sizes.dart';
import '../providers/voice_call_analysis_request_factory.dart';

/// A saved social call ends here; feedback is an explicit next action.
class VoiceCallSummaryPage extends StatelessWidget {
  const VoiceCallSummaryPage({
    super.key,
    required this.request,
    required this.onRequestFeedback,
  });

  final VoiceCallAnalysisRequest request;
  final VoidCallback onRequestFeedback;

  @override
  Widget build(BuildContext context) {
    final hasUserSpeech = request.transcript.any(
      (turn) =>
          turn['role'] == 'user' && (turn['text']?.trim().isNotEmpty ?? false),
    );
    final minutes = request.durationSeconds ~/ 60;
    final seconds = request.durationSeconds % 60;
    final isPractice = request.scenarioId != null;
    return Scaffold(
      appBar: AppBar(title: Text(isPractice ? '연습 마무리' : '통화 마무리')),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.lg),
        children: [
          const Icon(LucideIcons.checkCircle2, size: 48),
          const SizedBox(height: AppSizes.lg),
          Text(
            !request.wasConnected
                ? '통화를 시작하지 못했어요'
                : isPractice
                    ? '오늘의 연습을 마쳤어요'
                    : '${request.characterName ?? '친구'}와의 통화를 마쳤어요',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSizes.sm),
          Text(
              request.wasConnected
                  ? '$minutes분 $seconds초 · 대화 기록 저장 완료'
                  : '연결 기록을 저장했어요',
              textAlign: TextAlign.center),
          const SizedBox(height: AppSizes.xl),
          const Text('그대로 마쳐도 좋아요. 원하면 대화를 돌아보고 기억할 표현을 찾아볼 수 있어요.'),
          const SizedBox(height: AppSizes.lg),
          if (hasUserSpeech)
            OutlinedButton.icon(
              onPressed: onRequestFeedback,
              icon: const Icon(LucideIcons.lightbulb),
              label: const Text('원할 때 피드백 보기'),
            ),
          const SizedBox(height: AppSizes.sm),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('마치기'),
          ),
        ],
      ),
    );
  }
}
