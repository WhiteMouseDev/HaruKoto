import { create } from 'zustand';

type JlptLevel = 'N5' | 'N4' | 'N3' | 'N2' | 'N1';
type UserGoal =
  | 'JLPT_N5'
  | 'JLPT_N4'
  | 'JLPT_N3'
  | 'JLPT_N2'
  | 'JLPT_N1'
  | 'TRAVEL'
  | 'BUSINESS'
  | 'HOBBY';

interface OnboardingState {
  step: 1 | 2 | 3;
  nickname: string;
  jlptLevel: JlptLevel | null;
  goal: UserGoal | null;
  setStep: (step: 1 | 2 | 3) => void;
  setNickname: (nickname: string) => void;
  setJlptLevel: (level: JlptLevel) => void;
  setGoal: (goal: UserGoal) => void;
  reset: () => void;
}

export const useOnboardingStore = create<OnboardingState>((set) => ({
  step: 1,
  nickname: '',
  jlptLevel: null,
  goal: null,
  setStep: (step) => set({ step }),
  setNickname: (nickname) => set({ nickname }),
  setJlptLevel: (jlptLevel) => set({ jlptLevel }),
  setGoal: (goal) => set({ goal }),
  reset: () => set({ step: 1, nickname: '', jlptLevel: null, goal: null }),
}));
