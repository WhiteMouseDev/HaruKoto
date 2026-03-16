import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../data/gemini_live_service.dart';
import '../providers/chat_provider.dart';
import 'call_analyzing_page.dart';
import 'widgets/call_waveform.dart';

class VoiceCallPage extends ConsumerStatefulWidget {
  final String? scenarioId;
  final String? characterId;
  final String? characterName;
  final String? avatarUrl;

  const VoiceCallPage({
    super.key,
    this.scenarioId,
    this.characterId,
    this.characterName,
    this.avatarUrl,
  });

  @override
  ConsumerState<VoiceCallPage> createState() => _VoiceCallPageState();
}

class _VoiceCallPageState extends ConsumerState<VoiceCallPage> {
  GeminiLiveService? _service;
  String _state = 'connecting';
  int _callDuration = 0;
  bool _isMuted = false;
  bool _showSubtitle = true;
  String? _error;
  String _currentAiText = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCall();
  }

  String get _formattedDuration {
    final mins = (_callDuration ~/ 60).toString().padLeft(2, '0');
    final secs = (_callDuration % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  Future<void> _startCall() async {
    try {
      final repo = ref.read(chatRepositoryProvider);

      // 1. Get ephemeral token
      final tokenResp = await repo.fetchLiveToken(
        characterId: widget.characterId,
      );

      // 2. Get character detail for voice settings
      String? voiceName;
      String? personality;
      int silenceMs = 1200;
      if (widget.characterId != null) {
        try {
          final detail = await repo.fetchCharacterDetail(widget.characterId!);
          voiceName = detail.voiceName;
          personality = detail.personality;
          silenceMs = detail.silenceMs;
        } catch (_) {
          // Use defaults if character fetch fails
        }
      }

      if (!mounted) return;

      // 3. Create and start Gemini Live service
      _service = GeminiLiveService(
        wsUri: tokenResp.wsUri,
        token: tokenResp.token,
        characterName: widget.characterName,
        voiceName: voiceName,
        systemInstruction: personality,
        silenceDurationMs: silenceMs,
        jlptLevel: 'N5', // TODO: get from user profile
      );

      _service!.onStateChange = (state) {
        if (!mounted) return;
        setState(() {
          switch (state) {
            case GeminiLiveState.connecting:
              _state = 'connecting';
            case GeminiLiveState.connected:
              _state = 'connected';
              _startTimer();
            case GeminiLiveState.ending:
              _state = 'ending';
            case GeminiLiveState.ended:
              _state = 'ended';
            case GeminiLiveState.error:
              _state = 'error';
          }
        });
      };

      _service!.onAiTextDelta = (text) {
        if (!mounted) return;
        setState(() => _currentAiText += text);
      };

      _service!.onTranscriptEntry = (entry) {
        if (!mounted) return;
        if (entry.role == 'assistant') {
          setState(() => _currentAiText = '');
        }
      };

      _service!.onError = (message) {
        if (!mounted) return;
        setState(() => _error = message);
      };

      await _service!.start();
    } catch (e) {
      debugPrint('[VoiceCall] Start failed: $e');
      if (!mounted) return;
      setState(() {
        _state = 'error';
        _error = '연결에 실패했습니다: $e';
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _callDuration++);
    });
  }

  Future<void> _endCall() async {
    _timer?.cancel();
    _timer = null;

    final transcript = _service?.transcript ?? [];
    final duration = _callDuration;
    final characterId = widget.characterId;
    final scenarioId = widget.scenarioId;

    await _service?.end();

    if (!mounted) return;

    unawaited(Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CallAnalyzingPage(
          transcript: transcript.map((e) => e.toJson()).toList(),
          durationSeconds: duration,
          characterId: characterId,
          scenarioId: scenarioId,
        ),
      ),
    ));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _service?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const bgColor = AppColors.callBackground;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.all(AppSizes.md),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _endCall,
                      icon: const Icon(LucideIcons.arrowLeft,
                          color: AppColors.onGradientMuted),
                    ),
                    const Spacer(),
                    if (_state == 'connected')
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.onGradient.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _formattedDuration,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.onGradientMuted,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              const Spacer(),

              // Character name
              Text(
                widget.characterName ?? '하루',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: AppColors.onGradient,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSizes.sm),
              Text(
                _state == 'connecting'
                    ? '연결 중...'
                    : _state == 'ending'
                        ? '통화 종료 중...'
                        : _state == 'error'
                            ? '연결 실패'
                            : '통화 중',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.onGradient.withValues(alpha: 0.54),
                ),
              ),
              const SizedBox(height: AppSizes.xl),

              // Waveform / Avatar
              CallWaveformWidget(
                mode: _state == 'connected' ? 'speaking' : 'idle',
                avatarUrl: widget.avatarUrl,
              ),

              const Spacer(),

              // Subtitle overlay
              if (_showSubtitle &&
                  _state == 'connected' &&
                  _currentAiText.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
                  padding: const EdgeInsets.all(AppSizes.md),
                  decoration: BoxDecoration(
                    color: AppColors.overlay(0.54),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _currentAiText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.onGradient,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Error
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
                  child: Column(
                    children: [
                      Text(
                        _error!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                      if (_state == 'error') ...[
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _state = 'connecting';
                              _error = null;
                            });
                            _startCall();
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.onGradient,
                            side: BorderSide(
                                color: AppColors.onGradient
                                    .withValues(alpha: 0.3)),
                          ),
                          child: const Text('다시 연결'),
                        ),
                      ],
                    ],
                  ),
                ),

              // Controls
              Padding(
                padding: const EdgeInsets.all(AppSizes.xl),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mute button
                    if (_state == 'connected')
                      _ControlButton(
                        icon: _isMuted ? LucideIcons.micOff : LucideIcons.mic,
                        label: _isMuted ? '음소거 해제' : '음소거',
                        onTap: () => setState(() => _isMuted = !_isMuted),
                        color: AppColors.onGradient.withValues(alpha: 0.24),
                      ),

                    // End call button
                    _ControlButton(
                      icon: LucideIcons.phoneOff,
                      label: '통화 종료',
                      onTap: _endCall,
                      color: AppColors.error(Theme.of(context).brightness),
                      size: 64,
                    ),

                    // Subtitle toggle
                    if (_state == 'connected')
                      _ControlButton(
                        icon: LucideIcons.messageSquare,
                        label: '자막',
                        onTap: () =>
                            setState(() => _showSubtitle = !_showSubtitle),
                        color: _showSubtitle
                            ? AppColors.callAccent
                            : AppColors.onGradient.withValues(alpha: 0.24),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final double size;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.onGradient, size: size * 0.4),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
              color: AppColors.onGradient.withValues(alpha: 0.6), fontSize: 11),
        ),
      ],
    );
  }
}
