import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/dio_provider.dart';
import '../../../core/services/local_notification_service.dart';
import '../providers/onboarding_provider.dart';
import 'widgets/nickname_step.dart';
import 'widgets/level_step.dart';
import 'widgets/kana_step.dart';
import 'widgets/goal_step.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  bool _loading = false;
  String? _error;

  Future<void> _handleComplete() async {
    final state = ref.read(onboardingProvider);
    if (state.nickname.isEmpty ||
        state.jlptLevel == null ||
        state.goals.isEmpty) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      await dio.post<Map<String, dynamic>>(
        '/auth/onboarding',
        data: {
          'nickname': state.nickname,
          'jlptLevel': state.jlptLevel,
          'goals': state.goals,
          'showKana': state.showKana,
        },
      );

      // 온보딩 완료 후 알림 권한 요청 (맥락이 있는 시점)
      await LocalNotificationService.requestPermission();

      if (mounted) {
        if (state.showKana) {
          context.go('/study/kana');
        } else {
          context.go('/home');
        }
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      final msg = data is Map ? data['error'] as String? : null;
      setState(() => _error = msg ?? '오류가 발생했습니다');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '오류가 발생했습니다');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    final totalSteps = state.jlptLevel == 'ABSOLUTE_ZERO' ? 4 : 3;
    final isGoalStep =
        (state.step == 3 && state.jlptLevel != 'ABSOLUTE_ZERO') ||
            state.step == 4;

    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.colorScheme.surface,
                theme.colorScheme.surfaceContainerHigh,
              ],
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(totalSteps, (i) {
                  final stepNum = i + 1;
                  return Container(
                    width: 48,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: stepNum <= state.step
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _buildStep(state, notifier, isGoalStep),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(
    OnboardingState state,
    OnboardingNotifier notifier,
    bool isGoalStep,
  ) {
    if (state.step == 1) {
      return NicknameStep(
        key: const ValueKey('step-1'),
        nickname: state.nickname,
        onNicknameChanged: notifier.setNickname,
        onNext: () => notifier.setStep(2),
      );
    }

    if (state.step == 2) {
      return LevelStep(
        key: const ValueKey('step-2'),
        selectedLevel: state.jlptLevel,
        onLevelSelected: (level) {
          notifier.setJlptLevel(level);
          notifier.setShowKana(level == 'ABSOLUTE_ZERO');
        },
        onBack: () => notifier.setStep(1),
        onNext: () => notifier.setStep(3),
      );
    }

    if (state.step == 3 && state.jlptLevel == 'ABSOLUTE_ZERO') {
      return KanaStep(
        key: const ValueKey('step-3-kana'),
        showKana: state.showKana,
        onShowKanaChanged: notifier.setShowKana,
        onBack: () => notifier.setStep(2),
        onNext: () => notifier.setStep(4),
      );
    }

    if (isGoalStep) {
      return GoalStep(
        key: const ValueKey('step-goal'),
        selectedGoals: state.goals,
        onGoalToggled: notifier.toggleGoal,
        onBack: () =>
            notifier.setStep(state.jlptLevel == 'ABSOLUTE_ZERO' ? 3 : 2),
        onComplete: _handleComplete,
        loading: _loading,
        error: _error,
      );
    }

    return const SizedBox.shrink();
  }
}
