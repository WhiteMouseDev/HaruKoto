import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/sizes.dart';
import '../../../../core/services/tts_service.dart';
import '../../domain/kana_writing_audio.dart';

/// The page owns playback so scrolling this panel offscreen cannot orphan it.
class KanaWritingAudioPanel extends StatelessWidget {
  const KanaWritingAudioPanel({
    super.key,
    required this.audio,
    required this.tts,
    required this.owner,
    required this.selectedText,
    required this.enabled,
    required this.onPlay,
    required this.onStop,
  });

  final KanaWritingAudio audio;
  final TtsService tts;
  final Object owner;
  final String? selectedText;
  final bool enabled;
  final ValueChanged<KanaWritingAudioTarget> onPlay;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TtsPlaybackState>(
        valueListenable: tts.playback,
        builder: (context, playback, _) {
          final targets = [
            if (audio.character != null) audio.character!,
            audio.example
          ];
          final own = identical(playback.owner, owner) &&
              selectedText != null &&
              targets.any((target) => target.text == selectedText);
          final active = own && playback.isActive;
          final error = own ? playback.error : null;
          final status = error?.userMessage ??
              (active
                  ? playback.phase == TtsPlaybackPhase.loading
                      ? '음성 준비 중'
                      : '재생 중'
                  : own && playback.phase == TtsPlaybackPhase.completed
                      ? '다시 들을 수 있어요'
                      : '');
          return Column(
            key: const ValueKey('kana-writing-audio-panel'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('소리로 익히기', style: Theme.of(context).textTheme.titleSmall),
              if (audio.character == null) const Text('이 글자는 예시 안에서 소리를 확인해요.'),
              const SizedBox(height: AppSizes.xs),
              LayoutBuilder(builder: (context, constraints) {
                final vertical = constraints.maxWidth < 300 ||
                    MediaQuery.textScalerOf(context).scale(14) > 18;
                final width = vertical || targets.length == 1
                    ? constraints.maxWidth
                    : (constraints.maxWidth - AppSizes.sm) / 2;
                final style = Theme.of(context).textTheme.labelLarge!;
                final scaler = MediaQuery.textScalerOf(context);
                var height = 48.0;
                // Reserve all action labels up front so loading, errors and
                // retries cannot move a finger that is drawing on the pad.
                for (final target in targets) {
                  for (final label in [
                    target.label,
                    _retryLabel(target),
                    '정지'
                  ]) {
                    final painter = TextPainter(
                      text: TextSpan(text: label, style: style),
                      textDirection: Directionality.of(context),
                      textScaler: scaler,
                    )..layout(maxWidth: math.max(1, width - 56));
                    height = math.max(height, painter.height + 20);
                    painter.dispose();
                  }
                }
                final buttons = [
                  if (audio.character != null)
                    _button(context, audio.character!,
                        'kana-writing-character-audio', active,
                        failed: error != null, size: Size(width, height)),
                  _button(context, audio.example, 'kana-writing-example-audio',
                      active,
                      failed: error != null, size: Size(width, height)),
                ];
                return vertical
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                            for (final (index, button) in buttons.indexed) ...[
                              if (index > 0)
                                const SizedBox(height: AppSizes.xs),
                              button
                            ]
                          ])
                    : Row(children: [
                        for (final (index, button) in buttons.indexed) ...[
                          if (index > 0) const SizedBox(width: AppSizes.sm),
                          button
                        ]
                      ]);
              }),
              SizedBox(
                height: MediaQuery.textScalerOf(context).scale(14) * 1.5 + 3,
                child: Semantics(
                  liveRegion: true,
                  child: Tooltip(
                    message: status,
                    child: Text(status,
                        key: error == null
                            ? null
                            : const ValueKey('kana-writing-audio-error'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: error == null
                                ? null
                                : Theme.of(context).colorScheme.error)),
                  ),
                ),
              ),
            ],
          );
        },
      );

  String _retryLabel(KanaWritingAudioTarget target) =>
      target.label.replaceFirst(' 듣기', ' 다시 듣기');

  Widget _button(BuildContext context, KanaWritingAudioTarget target,
      String key, bool active,
      {required bool failed, required Size size}) {
    final playing = active && target.text == selectedText;
    final retry = failed && target.text == selectedText;
    final button = OutlinedButton.icon(
      key: ValueKey(key),
      onPressed: playing
          ? onStop
          : enabled
              ? () => onPlay(target)
              : null,
      icon: Icon(playing ? Icons.stop : Icons.volume_up, size: 18),
      label: Text(
          playing
              ? '정지'
              : retry
                  ? _retryLabel(target)
                  : target.label,
          style: Theme.of(context).textTheme.labelLarge),
      style: OutlinedButton.styleFrom(
          fixedSize: size,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
    );
    return retry
        ? KeyedSubtree(
            key: const ValueKey('kana-writing-audio-retry'), child: button)
        : button;
  }
}
