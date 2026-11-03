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
import '../data/models/scenario_model.dart';
import '../data/gemini_live_service.dart';
import '../../../core/network/api_exception.dart';
import 'widgets/voice_call_help_sheet.dart';
import 'call_analysis_launch.dart';
import 'conversation_feedback_launch.dart';
import 'widgets/call_waveform.dart';

class VoiceCallPage extends ConsumerStatefulWidget {
  final String? scenarioId;
  final ScenarioModel? scenario;
  final String? characterId;
  final String? characterName;
  final String? avatarUrl;

  const VoiceCallPage({
    super.key,
    this.scenarioId,
    this.scenario,
    this.characterId,
    this.characterName,
    this.avatarUrl,
  });

  @override
  ConsumerState<VoiceCallPage> createState() => _VoiceCallPageState();
}

class _VoiceCallPageState extends ConsumerState<VoiceCallPage>
    with WidgetsBindingObserver {
  ProviderContainer? _container;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(voiceCallSessionProvider.notifier).setAppActive(
            WidgetsBinding.instance.lifecycleState == null ||
                WidgetsBinding.instance.lifecycleState ==
                    AppLifecycleState.resumed,
          );
      unawaited(ref.read(voiceCallSessionProvider.notifier).initialize(
            VoiceCallSessionRequest(
              scenarioId: widget.scenarioId,
              characterId: widget.characterId,
              characterName: widget.characterName,
            ),
          ));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    ref
        .read(voiceCallSessionProvider.notifier)
        .setAppActive(state == AppLifecycleState.resumed);
  }

  Future<void> _resumeMicrophone() async {
    final resumed =
        await ref.read(voiceCallSessionProvider.notifier).resumeMicrophone();
    if (!mounted || resumed) return;
    final session = ref.read(voiceCallSessionProvider);
    if (!session.isConnected ||
        !session.isAppActive ||
        !session.microphoneInterrupted ||
        session.resumingMicrophone) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('마이크를 다시 연결하지 못했어요. 잠시 후 다시 시도해 주세요.'),
    ));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _container ??= ProviderScope.containerOf(context, listen: false);
  }

  Future<void> _endCall() async {
    final result = await ref.read(voiceCallSessionProvider.notifier).endCall();
    if (!mounted || result.ignored) return;

    final analysisRequest = result.analysisRequest;
    if (analysisRequest == null) {
      final feedbackError = result.feedbackError;
      if (feedbackError != null) {
        final navigator = Navigator.of(context);
        openConversationFeedbackPage(
          context,
          conversationId:
              'local-voice-call-${DateTime.now().millisecondsSinceEpoch}',
          initialFeedbackError: feedbackError,
          onRetryVoiceCall: () {
            navigator.pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => VoiceCallPage(
                  scenarioId: widget.scenarioId,
                  scenario: widget.scenario,
                  characterId: widget.characterId,
                  characterName: widget.characterName,
                  avatarUrl: widget.avatarUrl,
                ),
              ),
            );
          },
          replace: true,
        );
        return;
      }
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return;
    }

    openCallAnalysisPage(context, analysisRequest);
  }

  Future<void> _showHelp() async {
    final session = ref.read(voiceCallSessionProvider);
    if (!session.isConnected) return;
    final controller = ref.read(voiceCallSessionProvider.notifier);
    final wasMuted = session.isMuted;
    controller.setMuted(true);
    final action = await showModalBottomSheet<GeminiLiveHelpAction>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => VoiceCallHelpSheet(
        caption: session.currentAiText,
        isPractice: widget.scenarioId != null,
      ),
    );
    if (!mounted) return;
    controller.setMuted(wasMuted);
    if (action == null) return;
    final sent =
        await controller.requestHelp(action, targetText: session.currentAiText);
    if (!mounted) return;
    if (!sent) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            const ApiException(message: '연결을 확인한 뒤 다시 요청해 주세요.').userMessage),
      ));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final container = _container;
    if (container != null) {
      container.invalidate(voiceCallSessionProvider);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = ref.watch(voiceCallSessionProvider);
    const bgColor = AppColors.callBackground;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: PopScope(
        canPop: _allowPop,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_endCall());
        },
        child: Scaffold(
          backgroundColor: bgColor,
          body: SafeArea(
            child: Stack(
              children: [
                // ── Main layout (자막에 영향받지 않음) ──
                LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: IntrinsicHeight(
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
                                  if (session.isConnected)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.onGradient
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        session.formattedDuration,
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
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

                            if (widget.scenario != null) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppSizes.lg),
                                child: Text(
                                  widget.scenario!.title,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppColors.onGradientMuted),
                                ),
                              ),
                              const SizedBox(height: AppSizes.sm),
                            ],
                            // Character name + status
                            Text(
                              widget.scenario?.aiRole.isNotEmpty == true
                                  ? widget.scenario!.aiRole
                                  : widget.characterName ?? '하루',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: AppColors.onGradient,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: AppSizes.sm),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                session.statusLabel,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.onGradient
                                      .withValues(alpha: 0.54),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSizes.xl),

                            // Waveform / Avatar
                            if (session.isConnected &&
                                session.microphoneInterrupted)
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(minHeight: 200),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(LucideIcons.micOff,
                                          color: AppColors.onGradient,
                                          size: 32),
                                      const SizedBox(height: 12),
                                      Text(
                                        '마이크 입력이 멈췄어요.\n준비되면 다시 연결해 주세요.',
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                                color:
                                                    AppColors.onGradientMuted),
                                      ),
                                      const SizedBox(height: 16),
                                      FilledButton(
                                        onPressed: session.isAppActive &&
                                                !session.resumingMicrophone
                                            ? _resumeMicrophone
                                            : null,
                                        child: Text(session.resumingMicrophone
                                            ? '마이크 연결 중...'
                                            : '마이크 다시 연결'),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              CallWaveformWidget(
                                mode: session.isConnected && !session.isMuted
                                    ? 'listening'
                                    : 'idle',
                                avatarUrl: widget.avatarUrl,
                                characterName: widget.characterName,
                              ),

                            const Spacer(flex: 3),

                            // Error
                            if (session.errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppSizes.lg),
                                child: Column(
                                  children: [
                                    Text(
                                      session.errorMessage!,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: AppColors.onGradient
                                            .withValues(alpha: 0.7),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    if (session.hasConnected) ...[
                                      const SizedBox(height: 12),
                                      FilledButton(
                                          onPressed: _endCall,
                                          child: const Text('지금까지의 대화 저장')),
                                    ],
                                    if (session.canRetry &&
                                        !session.hasConnected) ...[
                                      const SizedBox(height: 12),
                                      FilledButton(
                                        onPressed: () => unawaited(
                                          ref
                                              .read(voiceCallSessionProvider
                                                  .notifier)
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  // Mute button
                                  if (session.isConnected)
                                    _ControlButton(
                                      icon: session.isMuted ||
                                              session.microphoneInterrupted
                                          ? LucideIcons.micOff
                                          : LucideIcons.mic,
                                      label: session.isMuted ? '음소거 해제' : '음소거',
                                      onTap: () => ref
                                          .read(
                                              voiceCallSessionProvider.notifier)
                                          .toggleMute(),
                                      color: session.isMuted
                                          ? AppColors.warning(theme.brightness)
                                          : AppColors.callSurface,
                                    ),

                                  if (session.isConnected)
                                    _ControlButton(
                                      icon: LucideIcons.lightbulb,
                                      label: '도움',
                                      onTap: _showHelp,
                                      color: AppColors.callSurface,
                                    ),

                                  // End call button
                                  _ControlButton(
                                    icon: LucideIcons.phoneOff,
                                    label: widget.scenario != null
                                        ? '연습 종료'
                                        : '통화 종료',
                                    onTap: _endCall,
                                    enabled: session.status !=
                                        VoiceCallStatus.ending,
                                    color: AppColors.error(
                                        Theme.of(context).brightness),
                                    size: 64,
                                  ),

                                  // Subtitle toggle
                                  if (session.isConnected)
                                    _ControlButton(
                                      icon: LucideIcons.messageSquare,
                                      label: '자막',
                                      onTap: () => ref
                                          .read(
                                              voiceCallSessionProvider.notifier)
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
                      ),
                    ),
                  ),
                ),

                // ── Subtitle overlay (하단 고정, 메인 레이아웃과 독립) ──
                if (session.showSubtitle &&
                    session.isConnected &&
                    !session.microphoneInterrupted)
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: MediaQuery.paddingOf(context).bottom + 188,
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
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 180),
                              child: SingleChildScrollView(
                                  child: Text(
                                session.currentAiText,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white,
                                  height: 1.4,
                                  shadows: [
                                    Shadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.28),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              )),
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
  final bool enabled;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
    this.size = 52,
    this.enabled = true,
  });

  void _activate() {
    if (!enabled) return;
    unawaited(HapticService().light());
    onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: label,
      enabled: enabled,
      onTap: enabled ? _activate : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? _activate : null,
          child: Column(
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
                    onTap: enabled ? _activate : null,
                    child: Icon(icon,
                        color: AppColors.onGradient, size: size * 0.4),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                    color: AppColors.onGradient.withValues(alpha: 0.6),
                    fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
