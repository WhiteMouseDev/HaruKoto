import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingState {
  final int step; // 1-4
  final String nickname;
  final String? jlptLevel;
  final String? goal;
  final bool showKana;

  const OnboardingState({
    this.step = 1,
    this.nickname = '',
    this.jlptLevel,
    this.goal,
    this.showKana = false,
  });

  OnboardingState copyWith({
    int? step,
    String? nickname,
    String? jlptLevel,
    String? goal,
    bool? showKana,
  }) {
    return OnboardingState(
      step: step ?? this.step,
      nickname: nickname ?? this.nickname,
      jlptLevel: jlptLevel ?? this.jlptLevel,
      goal: goal ?? this.goal,
      showKana: showKana ?? this.showKana,
    );
  }
}

class OnboardingNotifier extends Notifier<OnboardingState> {
  @override
  OnboardingState build() => const OnboardingState();

  void setStep(int step) => state = state.copyWith(step: step);
  void setNickname(String nickname) =>
      state = state.copyWith(nickname: nickname);
  void setJlptLevel(String level) => state = state.copyWith(jlptLevel: level);
  void setGoal(String goal) => state = state.copyWith(goal: goal);
  void setShowKana(bool showKana) => state = state.copyWith(showKana: showKana);
  void reset() => state = const OnboardingState();
}

final onboardingProvider =
    NotifierProvider<OnboardingNotifier, OnboardingState>(
  OnboardingNotifier.new,
);
