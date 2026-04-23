import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/character_assets.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../providers/call_analysis_provider.dart';
import '../providers/voice_call_session_provider.dart';
import 'conversation_feedback_launch.dart';

typedef CallAnalysisFeedbackLauncher = Future<void> Function(
  BuildContext context,
  CallAnalysisState analysis,
);

class CallAnalyzingPage extends ConsumerStatefulWidget {
  const CallAnalyzingPage({
    super.key,
    required this.request,
    this.feedbackLauncher,
  });

  final VoiceCallAnalysisRequest request;
  final CallAnalysisFeedbackLauncher? feedbackLauncher;

  @override
  ConsumerState<CallAnalyzingPage> createState() => _CallAnalyzingPageState();
}

class _CallAnalyzingPageState extends ConsumerState<CallAnalyzingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _navigated = false;
  bool _scheduledPop = false;
  ProviderContainer? _container;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref.read(callAnalysisProvider.notifier).analyze(widget.request),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _container ??= ProviderScope.containerOf(context, listen: false);
  }

  @override
  void dispose() {
    final container = _container;
    if (container != null) {
      Future(() => container.invalidate(callAnalysisProvider));
    }
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openFeedback(CallAnalysisState analysis) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted || analysis.conversationId == null) return;
    final launcher = widget.feedbackLauncher;
    if (launcher != null) {
      await launcher(context, analysis);
      return;
    }
    openConversationFeedbackPage(
      context,
      conversationId: analysis.conversationId!,
      initialFeedback: analysis.feedbackSummary,
      initialFeedbackError: analysis.feedbackError,
      replace: true,
    );
  }

  Future<void> _popAfterError() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Widget _buildStepIndicator(int currentStep) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepCircle(1, '음성 분석', currentStep),
        _buildStepLine(currentStep >= 2),
        _buildStepCircle(2, '피드백 생성', currentStep),
        _buildStepLine(currentStep >= 3),
        _buildStepCircle(3, '완료', currentStep),
      ],
    );
  }

  Widget _buildStepCircle(int step, String label, int currentStep) {
    final isActive = currentStep >= step;
    final isCompleted = currentStep > step;
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? AppColors.callAccent
                : Colors.white.withValues(alpha: 0.15),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(LucideIcons.check, size: 14, color: Colors.white)
                : Text(
                    '$step',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive
                ? Colors.white.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(bool active) {
    return Container(
      width: 40,
      height: 2,
      margin: const EdgeInsets.only(bottom: 20),
      color:
          active ? AppColors.callAccent : Colors.white.withValues(alpha: 0.15),
    );
  }

  Widget _buildAvatar() {
    final localPath = CharacterAssets.pathFor(widget.request.characterName);
    if (localPath != null) {
      return CircleAvatar(
        radius: 56,
        backgroundColor: AppColors.callSurface,
        backgroundImage: AssetImage(localPath),
      );
    }
    return const CircleAvatar(
      radius: 56,
      backgroundColor: AppColors.callSurface,
      child: Icon(
        LucideIcons.barChart,
        size: 40,
        color: AppColors.callAccentLight,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final analysis = ref.watch(callAnalysisProvider);

    ref.listen(callAnalysisProvider, (previous, next) {
      if (!mounted) return;
      if (next.isCompleted && !_navigated) {
        _navigated = true;
        unawaited(_openFeedback(next));
        return;
      }
      if (next.status == CallAnalysisStatus.error && !_scheduledPop) {
        _scheduledPop = true;
        unawaited(_popAfterError());
      }
    });

    return Scaffold(
      backgroundColor: AppColors.callBackground,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.callAccent.withValues(alpha: 0.25),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    child: _buildAvatar(),
                  ),
                  Positioned(
                    bottom: -4,
                    right: -4,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.callSurface,
                        shape: BoxShape.circle,
                      ),
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (_, child) => Transform.rotate(
                          angle: _controller.value * 6.28,
                          child: child,
                        ),
                        child: const Icon(
                          LucideIcons.rotateCw,
                          color: AppColors.callAccentLight,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.lg),
              _buildStepIndicator(analysis.currentStep),
              const SizedBox(height: AppSizes.lg),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  analysis.statusMessage,
                  key: ValueKey(analysis.statusMessage),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.onGradientMuted,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSizes.lg),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  child: LinearProgressIndicator(
                    value: analysis.progress,
                    backgroundColor:
                        AppColors.onGradient.withValues(alpha: 0.12),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.callAccentLight,
                    ),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.sm),
              Text(
                '${(analysis.progress * 100).round()}%',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.onGradient.withValues(alpha: 0.88),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
