import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/sizes.dart';
import '../../data/gemini_live_service.dart';

class VoiceCallHelpSheet extends StatelessWidget {
  const VoiceCallHelpSheet(
      {super.key, required this.caption, required this.isPractice});

  final String caption;
  final bool isPractice;

  @override
  Widget build(BuildContext context) {
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
