import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/sizes.dart';
import '../data/models/conversation_journey_episode.dart';
import '../providers/voice_call_analysis_request_factory.dart';

/// A saved call can end here with feedback as an explicit next action.
class VoiceCallSummaryPage extends StatelessWidget {
  const VoiceCallSummaryPage({
    super.key,
    required this.request,
    required this.onRequestFeedback,
    this.journeyEpisode,
  });

  final VoiceCallAnalysisRequest request;
  final VoidCallback onRequestFeedback;
  final ConversationJourneyEpisode? journeyEpisode;

  @override
  Widget build(BuildContext context) {
    final hasUserSpeech = request.transcript.any(
      (turn) =>
          turn['role'] == 'user' && (turn['text']?.trim().isNotEmpty ?? false),
    );
    final minutes = request.durationSeconds ~/ 60;
    final seconds = request.durationSeconds % 60;
    final isPractice = request.scenarioId != null;
    final episode = journeyEpisode;
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
          if (episode != null) ...[
            _JourneyGoalChecklist(episode: episode),
            const SizedBox(height: AppSizes.lg),
          ],
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
            child: Text(episode == null ? '마치기' : '연습 마치기'),
          ),
        ],
      ),
    );
  }
}

class _JourneyGoalChecklist extends StatefulWidget {
  const _JourneyGoalChecklist({required this.episode});

  final ConversationJourneyEpisode episode;

  @override
  State<_JourneyGoalChecklist> createState() => _JourneyGoalChecklistState();
}

class _JourneyGoalChecklistState extends State<_JourneyGoalChecklist> {
  final _checkedGoals = <String>{};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('도쿄 첫날 · ${widget.episode.title}',
                style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSizes.sm),
            Text('내가 말해본 목표', style: theme.textTheme.titleMedium),
            const Text('이번 대화에서 말해본 항목을 자유롭게 체크해 보세요.'),
            for (final goal in widget.episode.goals)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(goal),
                value: _checkedGoals.contains(goal),
                onChanged: (checked) => setState(() {
                  if (checked == true) {
                    _checkedGoals.add(goal);
                  } else {
                    _checkedGoals.remove(goal);
                  }
                }),
              ),
          ],
        ),
      ),
    );
  }
}
