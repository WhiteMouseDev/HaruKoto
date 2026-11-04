import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/sizes.dart';
import '../../data/gemini_live_service.dart';
import '../../data/models/conversation_journey_episode.dart';

class VoiceCallHelpSheet extends StatelessWidget {
  const VoiceCallHelpSheet({
    super.key,
    required this.caption,
    required this.isPractice,
    this.journeyEpisode,
  });

  final String caption;
  final bool isPractice;
  final ConversationJourneyEpisode? journeyEpisode;

  @override
  Widget build(BuildContext context) {
    final episode = journeyEpisode;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('대화를 이어갈 도움이 필요해요',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSizes.sm),
            const Text('이 창에서는 내 마이크만 잠시 꺼져요. 상대의 말은 계속 들을 수 있어요.'),
            if (caption.isNotEmpty) ...[
              const SizedBox(height: AppSizes.md),
              Text(caption, style: Theme.of(context).textTheme.bodyLarge),
            ],
            if (episode != null) ...[
              const SizedBox(height: AppSizes.md),
              _JourneyHintPanel(episode: episode),
            ],
            const SizedBox(height: AppSizes.md),
            _action(context, GeminiLiveHelpAction.repeat, LucideIcons.rotateCcw,
                '다시 말해줘'),
            _action(context, GeminiLiveHelpAction.slower, LucideIcons.timer,
                '천천히 말해줘'),
            _action(context, GeminiLiveHelpAction.meaning,
                LucideIcons.languages, '한국어로 뜻 알려줘'),
            if (isPractice)
              _action(context, GeminiLiveHelpAction.replyHint,
                  LucideIcons.lightbulb, '답변 힌트 알려줘'),
            const SizedBox(height: AppSizes.sm),
            const Text('반복·설명 요청을 보내요. 잠시 기다려 주세요.'),
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('대화로 돌아가기')),
          ],
        ),
      ),
    );
  }

  Widget _action(BuildContext context, GeminiLiveHelpAction action,
      IconData icon, String label) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      onTap: () => Navigator.of(context).pop(action),
    );
  }
}

class _JourneyHintPanel extends StatefulWidget {
  const _JourneyHintPanel({required this.episode});

  final ConversationJourneyEpisode episode;

  @override
  State<_JourneyHintPanel> createState() => _JourneyHintPanelState();
}

class _JourneyHintPanelState extends State<_JourneyHintPanel> {
  int? _selectedGoal;
  int _level = 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final episode = widget.episode;
    final selectedGoal = _selectedGoal;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.gap),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('미션 힌트', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSizes.xs),
            Text('말하고 싶은 목표를 골라요', style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSizes.xs),
            Wrap(
              spacing: AppSizes.sm,
              children: [
                for (final (index, goal) in episode.goals.indexed)
                  ChoiceChip(
                    label: Text(goal),
                    selected: selectedGoal == index,
                    onSelected: (selected) {
                      setState(() {
                        _selectedGoal = selected ? index : null;
                        _level = 1;
                      });
                    },
                  ),
              ],
            ),
            if (selectedGoal != null) ...[
              const SizedBox(height: AppSizes.sm),
              Semantics(
                liveRegion: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      switch (_level) {
                        1 => '힌트 1/3 · 말할 뜻',
                        2 => '힌트 2/3 · 일본어 키워드',
                        _ => '힌트 3/3 · 예문과 뜻',
                      },
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSizes.xs),
                    Text(
                      switch (_level) {
                        1 => episode.goals[selectedGoal],
                        2 => episode.keywords[selectedGoal],
                        _ => episode.examples[selectedGoal],
                      },
                      locale: _level > 1 ? const Locale('ja') : null,
                      style: theme.textTheme.bodyLarge,
                    ),
                    if (_level == 3)
                      Text(
                        episode.meanings[selectedGoal],
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              if (_level < 3)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, AppSizes.buttonHeight),
                    ),
                    onPressed: () => setState(() => _level += 1),
                    child: Text(_level == 1 ? '키워드 보기' : '예문 보기'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
