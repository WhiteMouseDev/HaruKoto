import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/services/tts_service.dart';
import '../../data/models/lesson_models.dart';

/// Uses existing sentence audio; no combined URL/content change is required.
class LessonDialogueAudioControl extends StatefulWidget {
  const LessonDialogueAudioControl({
    super.key,
    required this.lessonId,
    required this.reading,
    this.ttsService,
  });

  final String lessonId;
  final ReadingModel reading;
  final TtsService? ttsService;

  @override
  State<LessonDialogueAudioControl> createState() =>
      _LessonDialogueAudioControlState();
}

class _LessonDialogueAudioControlState extends State<LessonDialogueAudioControl>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  final Object _owner = Object();
  late final TtsService _tts;
  bool _hasStarted = false;

  @override
  bool get wantKeepAlive => true;

  List<int> get _indices => widget.reading.script
      .asMap()
      .entries
      .where((entry) => entry.value.text.trim().isNotEmpty)
      .map((entry) => entry.key)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _tts = widget.ttsService ?? TtsService();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(LessonDialogueAudioControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lessonId != widget.lessonId ||
        oldWidget.reading != widget.reading) {
      _tts.stop(owner: _owner);
      _hasStarted = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _tts.stop(owner: _owner);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // An outgoing AnimatedSwitcher child must not stop a new screen's audio.
    _tts.stop(owner: _owner);
    super.dispose();
  }

  void _start() {
    setState(() => _hasStarted = true);
    final indices = _indices;
    if (indices.isNotEmpty) {
      unawaited(
          _tts.playLessonDialogue(widget.lessonId, indices, owner: _owner));
    } else if (widget.reading.audioUrl case final url?) {
      unawaited(_tts.playUrl(url, owner: _owner, lessonId: widget.lessonId));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final indices = _indices;
    if (indices.isEmpty && widget.reading.audioUrl == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return ValueListenableBuilder<TtsPlaybackState>(
      valueListenable: _tts.playback,
      builder: (context, playback, _) {
        final own = identical(playback.owner, _owner);
        final active = own && playback.isActive;
        final loading = active && playback.phase == TtsPlaybackPhase.loading;
        final error = own ? playback.error : null;
        final position = indices.indexOf(playback.lineIndex ?? -1) + 1;
        final status = active
            ? '${loading ? '음성 준비 중' : '재생 중'}${position > 0 ? ' · $position/${indices.length}문장' : ''}'
            : own && playback.phase == TtsPlaybackPhase.completed
                ? '대화를 모두 들었어요'
                : _hasStarted
                    ? '처음부터 다시 들을 수 있어요'
                    : '문장 순서대로 들어보세요';
        final action = FilledButton.tonalIcon(
          key: const ValueKey('dialogue-audio-toggle'),
          onPressed: active ? () => _tts.stop(owner: _owner) : _start,
          icon: loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(
                  active
                      ? LucideIcons.square
                      : _hasStarted
                          ? LucideIcons.rotateCcw
                          : LucideIcons.play,
                  size: 16),
          label: Text(active
              ? '정지'
              : _hasStarted
                  ? '다시 듣기'
                  : '전체 듣기'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
        );
        final heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('대화 전체 듣기',
                style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryStrong)),
            const SizedBox(height: AppSizes.xs),
            Text(status, style: theme.textTheme.bodySmall),
          ],
        );
        return Container(
          padding: const EdgeInsets.all(AppSizes.gap),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(builder: (context, constraints) {
                if (constraints.maxWidth < 300 ||
                    MediaQuery.textScalerOf(context).scale(14) > 18) {
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        heading,
                        const SizedBox(height: AppSizes.sm),
                        action
                      ]);
                }
                return Row(children: [
                  Expanded(child: heading),
                  const SizedBox(width: AppSizes.sm),
                  action
                ]);
              }),
              if (error != null) ...[
                const SizedBox(height: AppSizes.sm),
                Text(error.userMessage,
                    key: const ValueKey('dialogue-audio-error'),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.error)),
              ],
            ],
          ),
        );
      },
    );
  }
}
