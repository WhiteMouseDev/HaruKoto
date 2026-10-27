import 'package:flutter/material.dart';

import '../../../../core/constants/sizes.dart';
import '../../../../core/services/tts_service.dart';
import '../../data/models/lesson_models.dart';
import 'lesson_dialogue_bubble.dart';
import 'lesson_dialogue_audio_control.dart';

Future<void> showLessonDialogueSheet(
    BuildContext context, LessonDetailModel detail,
    {TtsService? ttsService}) async {
  final theme = Theme.of(context);
  final tts = ttsService ?? TtsService();
  tts.stop(lessonId: detail.id);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) tts.stop(lessonId: detail.id);
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(AppSizes.md),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSizes.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              '대화 다시 보기',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSizes.md),
            LessonDialogueAudioControl(
                lessonId: detail.id,
                reading: detail.content.reading,
                ttsService: ttsService),
            const SizedBox(height: AppSizes.md),
            ...detail.content.reading.script.asMap().entries.map(
                  (entry) => LessonDialogueBubble(
                    line: entry.value,
                    ttsService: ttsService,
                    lessonId: detail.id,
                    scriptLineIndex: entry.key,
                    showTranslation: true,
                  ),
                ),
          ],
        ),
      ),
    ),
  );
}
