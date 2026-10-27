import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/services/tts_service.dart';

class TtsPlayButton extends StatefulWidget {
  final String? vocabId;
  final String? lessonId;
  final int? scriptLineIndex;
  final String? text;
  final String? url;
  final double iconSize;
  final TtsService? ttsService;

  const TtsPlayButton({
    super.key,
    this.vocabId,
    this.lessonId,
    this.scriptLineIndex,
    this.text,
    this.url,
    this.iconSize = 20,
    this.ttsService,
  }) : assert(
          vocabId != null ||
              (lessonId != null && scriptLineIndex != null) ||
              text != null ||
              url != null,
          'Either vocabId, lessonId/scriptLineIndex, text, or url must be provided',
        );

  @override
  State<TtsPlayButton> createState() => _TtsPlayButtonState();
}

class _TtsPlayButtonState extends State<TtsPlayButton>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  final Object _owner = Object();
  late final TtsService _tts;

  @override
  bool get wantKeepAlive =>
      identical(_tts.playback.value.owner, _owner) &&
      _tts.playback.value.isActive;

  void _updateKeepAlive() {
    if (mounted) updateKeepAlive();
  }

  @override
  void initState() {
    _tts = widget.ttsService ?? TtsService();
    super.initState();
    _tts.playback.addListener(_updateKeepAlive);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(TtsPlayButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vocabId != widget.vocabId ||
        oldWidget.lessonId != widget.lessonId ||
        oldWidget.scriptLineIndex != widget.scriptLineIndex ||
        oldWidget.text != widget.text ||
        oldWidget.url != widget.url) {
      _tts.stop(owner: _owner);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _tts.stop(owner: _owner);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tts.playback.removeListener(_updateKeepAlive);
    _tts.stop(owner: _owner);
    super.dispose();
  }

  Future<void> _onTap() async {
    final state = _tts.playback.value;
    if (identical(state.owner, _owner) && state.isActive) {
      _tts.stop(owner: _owner);
      return;
    }
    // A different sentence takes over immediately, cancelling any whole queue.
    if (widget.url != null) {
      await _tts.playUrl(widget.url!, owner: _owner, lessonId: widget.lessonId);
    } else if (widget.vocabId != null) {
      await _tts.play(widget.vocabId!, owner: _owner);
    } else if (widget.lessonId != null && widget.scriptLineIndex != null) {
      await _tts.playLessonScriptLine(widget.lessonId!, widget.scriptLineIndex!,
          owner: _owner);
    } else {
      await _tts.playText(widget.text!, owner: _owner);
    }
    if (!mounted) return;
    final latest = _tts.playback.value;
    if (identical(latest.owner, _owner) && latest.error != null) {
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(latest.error!.userMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return ValueListenableBuilder<TtsPlaybackState>(
      valueListenable: _tts.playback,
      builder: (context, playback, _) {
        final active = identical(playback.owner, _owner) && playback.isActive;
        final loading = active && playback.phase == TtsPlaybackPhase.loading;
        return IconButton(
          tooltip: active ? '음성 정지' : '음성 듣기',
          onPressed: () => unawaited(_onTap()),
          icon: loading
              ? SizedBox(
                  width: widget.iconSize,
                  height: widget.iconSize,
                  child: const CircularProgressIndicator(strokeWidth: 2))
              : Icon(active ? LucideIcons.square : LucideIcons.volume2,
                  size: widget.iconSize,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
        );
      },
    );
  }
}
