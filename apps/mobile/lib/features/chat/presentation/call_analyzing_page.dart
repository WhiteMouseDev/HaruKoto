import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/character_assets.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../providers/chat_provider.dart';
import 'conversation_feedback_page.dart';

class CallAnalyzingPage extends ConsumerStatefulWidget {
  final List<Map<String, String>> transcript;
  final int durationSeconds;
  final String? characterId;
  final String? characterName;
  final String? scenarioId;

  const CallAnalyzingPage({
    super.key,
    required this.transcript,
    required this.durationSeconds,
    this.characterId,
    this.characterName,
    this.scenarioId,
  });

  @override
  ConsumerState<CallAnalyzingPage> createState() => _CallAnalyzingPageState();
}

class _CallAnalyzingPageState extends ConsumerState<CallAnalyzingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  String _status = '통화 내용을 분석하고 있어요...';
  double _progress = 0.0;
  int _currentStep = 1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _startAnalysis();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startAnalysis() async {
    // Phase 1: Show progress
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() {
      _status = 'AI가 피드백을 생성하고 있어요...';
      _progress = 0.3;
      _currentStep = 2;
    });

    try {
      // Phase 2: Call API
      final repo = ref.read(chatRepositoryProvider);
      final result = await repo.sendLiveFeedback(
        transcript: widget.transcript,
        durationSeconds: widget.durationSeconds,
        characterId: widget.characterId,
        scenarioId: widget.scenarioId,
      );

      if (!mounted) return;
      setState(() {
        _status = '분석 완료!';
        _progress = 1.0;
        _currentStep = 3;
      });

      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      // Navigate to feedback page
      unawaited(Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ConversationFeedbackPage(
            conversationId: result.conversationId,
          ),
        ),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = '분석에 실패했습니다';
        _progress = 0.0;
      });

      // Wait and pop back
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepCircle(1, '음성 분석'),
        _buildStepLine(_currentStep >= 2),
        _buildStepCircle(2, '피드백 생성'),
        _buildStepLine(_currentStep >= 3),
        _buildStepCircle(3, '완료'),
      ],
    );
  }

  Widget _buildStepCircle(int step, String label) {
    final isActive = _currentStep >= step;
    final isCompleted = _currentStep > step;
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
      color: active
          ? AppColors.callAccent
          : Colors.white.withValues(alpha: 0.15),
    );
  }

  Widget _buildAvatar() {
    final localPath = CharacterAssets.pathFor(widget.characterName);
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
      child: Icon(LucideIcons.barChart, size: 40, color: AppColors.callAccentLight),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.callBackground,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar with spinner
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

              // Step indicator
              _buildStepIndicator(),
              const SizedBox(height: AppSizes.lg),

              // Status text
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _status,
                  key: ValueKey(_status),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.onGradientMuted,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSizes.lg),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor:
                        AppColors.onGradient.withValues(alpha: 0.12),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.callAccentLight,
                    ),
                    minHeight: 4,
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
