import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/services/haptic_service.dart';
import '../providers/voice_call_session_provider.dart';
import 'call_analysis_launch.dart';
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
  @override
  void initState() {
    super.initState();
    unawaited(
      ref.read(voiceCallSessionProvider.notifier).initialize(
            VoiceCallSessionRequest(
              scenarioId: widget.scenarioId,
              characterId: widget.characterId,
              characterName: widget.characterName,
            ),
          ),
    );
  }

  Future<void> _endCall() async {
    final result = await ref.read(voiceCallSessionProvider.notifier).endCall();
    if (!mounted || result.ignored) return;

    final analysisRequest = result.analysisRequest;
    if (analysisRequest == null) {
      Navigator.of(context).pop();
      return;
    }

    openCallAnalysisPage(context, analysisRequest);
  }

  @override
  void dispose() {
    ref.invalidate(voiceCallSessionProvider);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = ref.watch(voiceCallSessionProvider);
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
                        if (session.isConnected)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.onGradient.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              session.formattedDuration,
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
                    session.statusLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.onGradient.withValues(alpha: 0.54),
                    ),
                  ),
                  const SizedBox(height: AppSizes.xl),

                  // Waveform / Avatar
                  CallWaveformWidget(
                    mode: session.isConnected ? 'speaking' : 'idle',
                    avatarUrl: widget.avatarUrl,
                    characterName: widget.characterName,
                  ),

                  const Spacer(flex: 3),

                  // Error
                  if (session.errorMessage != null)
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSizes.lg),
                      child: Column(
                        children: [
                          Text(
                            session.errorMessage!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  AppColors.onGradient.withValues(alpha: 0.7),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (session.canRetry) ...[
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: () => unawaited(
                                ref
                                    .read(voiceCallSessionProvider.notifier)
                                    .retry(),
                              ),
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
                        if (session.isConnected)
                          _ControlButton(
                            icon: session.isMuted
                                ? LucideIcons.micOff
                                : LucideIcons.mic,
                            label: session.isMuted ? '음소거 해제' : '음소거',
                            onTap: () => ref
                                .read(voiceCallSessionProvider.notifier)
                                .toggleMute(),
                            color: session.isMuted
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
                        if (session.isConnected)
                          _ControlButton(
                            icon: LucideIcons.messageSquare,
                            label: '자막',
                            onTap: () => ref
                                .read(voiceCallSessionProvider.notifier)
                                .toggleSubtitle(),
                            color: session.showSubtitle
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
              if (session.showSubtitle && session.isConnected)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.paddingOf(context).bottom + 188,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: session.currentAiText.isNotEmpty ? 1.0 : 0.0,
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
                              session.currentAiText,
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
