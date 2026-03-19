import 'dart:async';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/services/haptic_service.dart';
import '../../my/data/models/profile_detail_model.dart';
import '../../my/providers/my_provider.dart';
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
  final AudioPlayer _ringtone = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _playRingtone();
    _startCall();
  }

  Future<void> _playRingtone() async {
    try {
      await _ringtone.setReleaseMode(ReleaseMode.loop);
      await _ringtone.setVolume(0.5);
      await _ringtone.play(AssetSource('sounds/ringtone.wav'));
    } catch (e) {
      debugPrint('[VoiceCall] Ringtone play failed: $e');
    }
  }

  Future<void> _stopRingtone() async {
    try {
      await _ringtone.stop();
    } catch (_) {}
  }

  String get _formattedDuration {
    final mins = (_callDuration ~/ 60).toString().padLeft(2, '0');
    final secs = (_callDuration % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  Future<void> _startCall() async {
    debugPrint('[VoiceCall] _startCall() called');
    try {
      final repo = ref.read(chatRepositoryProvider);

      // 0. Load user call settings
      final profileAsync = ref.read(profileDetailProvider);
      final callSettings = profileAsync.hasValue
          ? profileAsync.value!.profile.callSettings
          : const CallSettings();
      _showSubtitle = callSettings.subtitleEnabled;

      // 1. Get ephemeral token
      debugPrint('[VoiceCall] Fetching live token...');
      final tokenResp = await repo.fetchLiveToken(
        characterId: widget.characterId,
      );
      debugPrint(
          '[VoiceCall] Token received: ${tokenResp.token.substring(0, tokenResp.token.length.clamp(0, 30))}...');
      debugPrint('[VoiceCall] Model: ${tokenResp.model}');

      // 2. Get character detail for voice settings
      String? voiceName;
      String? personality;
      if (widget.characterId != null) {
        try {
          final detail = await repo.fetchCharacterDetail(widget.characterId!);
          voiceName = detail.voiceName;
          personality = detail.personality;
        } catch (e) {
          debugPrint('[VoiceCall] Character detail fetch failed: $e');
        }
      }

      // silenceDurationMs: 유저 설정 우선
      final silenceMs = callSettings.silenceDurationMs;

      if (!mounted) return;

      // Fail-fast: 토큰이나 모델이 비어있으면 연결 시도하지 않음
      if (tokenResp.token.isEmpty || tokenResp.model.isEmpty) {
        setState(() => _state = 'error');
        return;
      }

      // 3. Create and start Gemini Live service
      _service = GeminiLiveService(
        wsUri: tokenResp.wsUri,
        token: tokenResp.token,
        model: tokenResp.model,
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
              _stopRingtone();
              _startTimer();
            case GeminiLiveState.ending:
              _state = 'ending';
              _stopRingtone();
            case GeminiLiveState.ended:
              _state = 'ended';
            case GeminiLiveState.error:
              _state = 'error';
              _stopRingtone();
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

  bool _isEnding = false;

  Future<void> _endCall() async {
    if (_isEnding) return; // 중복 호출 방지
    _isEnding = true;

    _timer?.cancel();
    _timer = null;

    final transcript = _service?.transcript ?? [];
    final duration = _callDuration;
    final characterId = widget.characterId;
    final scenarioId = widget.scenarioId;

    await _service?.end();

    if (!mounted) return;

    // 최소 15초 이상 통화해야 분석 진행
    final profileAsync = ref.read(profileDetailProvider);
    final autoAnalysis = profileAsync.hasValue
        ? profileAsync.value!.profile.callSettings.autoAnalysis
        : true;

    if (!autoAnalysis || duration < 15 || transcript.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    unawaited(Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CallAnalyzingPage(
          transcript: transcript.map((e) => e.toJson()).toList(),
          durationSeconds: duration,
          characterId: characterId,
          characterName: widget.characterName,
          scenarioId: scenarioId,
        ),
      ),
    ));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ringtone.dispose();
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
          child: Stack(
            children: [
              // ── Main layout (자막에 영향받지 않음) ──
              Column(
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
                              color:
                                  AppColors.onGradient.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _formattedDuration,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.onGradientMuted,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                          ),
                        const Spacer(),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Character name + status
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
                                : _formattedDuration,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.onGradient.withValues(alpha: 0.54),
                    ),
                  ),
                  const SizedBox(height: AppSizes.xl),

                  // Waveform / Avatar
                  CallWaveformWidget(
                    mode: _state == 'connected' ? 'speaking' : 'idle',
                    avatarUrl: widget.avatarUrl,
                    characterName: widget.characterName,
                  ),

                  const Spacer(flex: 3),

                  // Error
                  if (_error != null)
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSizes.lg),
                      child: Column(
                        children: [
                          Text(
                            _error!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  AppColors.onGradient.withValues(alpha: 0.7),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_state == 'error') ...[
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: () {
                                setState(() {
                                  _state = 'connecting';
                                  _error = null;
                                });
                                _startCall();
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.callAccent,
                                foregroundColor: AppColors.onGradient,
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
                            icon:
                                _isMuted ? LucideIcons.micOff : LucideIcons.mic,
                            label: _isMuted ? '음소거 해제' : '음소거',
                            onTap: () {
                              setState(() => _isMuted = !_isMuted);
                              _service?.isMuted = _isMuted;
                            },
                            color: _isMuted
                                ? AppColors.warning(theme.brightness)
                                : AppColors.callSurface,
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
                                : AppColors.callSurface,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.lg),
                ],
              ),

              // ── Subtitle overlay (하단 고정, 메인 레이아웃과 독립) ──
              if (_showSubtitle && _state == 'connected')
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.paddingOf(context).bottom + 188,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _currentAiText.isNotEmpty ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.35),
                                  Colors.black.withValues(alpha: 0.45),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Text(
                              _currentAiText,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                                height: 1.4,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.28),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
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
        Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                HapticService().light();
                onTap();
              },
              child: Icon(icon, color: AppColors.onGradient, size: size * 0.4),
            ),
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
