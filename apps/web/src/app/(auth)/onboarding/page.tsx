'use client';

import { useState, useRef } from 'react';
import { useRouter } from 'next/navigation';
import { motion, AnimatePresence } from 'framer-motion';
import { useOnboardingStore } from '@/stores/onboarding';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card, CardContent } from '@/components/ui/card';
import { FoxMascot } from '@/components/brand/fox-mascot';
import {
  Sprout,
  Leaf,
  TreeDeciduous,
  BookOpen,
  Crown,
  Target,
  Plane,
  Briefcase,
  Heart,
  type LucideIcon,
} from 'lucide-react';

const LEVELS: { value: 'N5' | 'N4' | 'N3' | 'N2' | 'N1'; Icon: LucideIcon; label: string; desc: string }[] = [
  {
    value: 'N5',
    Icon: Sprout,
    label: 'N5 — 완전 초보',
    desc: '히라가나부터 시작',
  },
  {
    value: 'N4',
    Icon: Leaf,
    label: 'N4 — 기초',
    desc: '기본 문법과 단어를 알아요',
  },
  {
    value: 'N3',
    Icon: TreeDeciduous,
    label: 'N3 — 중급',
    desc: '일상 회화가 가능해요',
  },
  {
    value: 'N2',
    Icon: BookOpen,
    label: 'N2 — 중상급',
    desc: '뉴스/소설을 읽을 수 있어요',
  },
  {
    value: 'N1',
    Icon: Crown,
    label: 'N1 — 상급',
    desc: '네이티브에 가까워요',
  },
];

type UserGoal = 'JLPT_N5' | 'JLPT_N4' | 'JLPT_N3' | 'JLPT_N2' | 'JLPT_N1' | 'TRAVEL' | 'BUSINESS' | 'HOBBY';

const GOALS: { value: UserGoal; Icon: LucideIcon; label: string }[] = [
  { value: 'JLPT_N5', Icon: Target, label: 'JLPT N5 합격' },
  { value: 'JLPT_N4', Icon: Target, label: 'JLPT N4 합격' },
  { value: 'JLPT_N3', Icon: Target, label: 'JLPT N3 합격' },
  { value: 'JLPT_N2', Icon: Target, label: 'JLPT N2 합격' },
  { value: 'JLPT_N1', Icon: Target, label: 'JLPT N1 합격' },
  { value: 'TRAVEL', Icon: Plane, label: '여행 일본어' },
  { value: 'BUSINESS', Icon: Briefcase, label: '비즈니스 일본어' },
  { value: 'HOBBY', Icon: Heart, label: '취미/문화' },
];

export default function OnboardingPage() {
  const router = useRouter();
  const {
    step,
    nickname,
    jlptLevel,
    goal,
    showKana,
    setStep,
    setNickname,
    setJlptLevel,
    setGoal,
    setShowKana,
  } = useOnboardingStore();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const directionRef = useRef(1); // 1 = forward, -1 = backward

  function goTo(next: 1 | 2 | 3 | 4) {
    directionRef.current = next > step ? 1 : -1;
    setStep(next);
  }

  const slideVariants = {
    enter: (dir: number) => ({ x: dir > 0 ? 80 : -80, opacity: 0 }),
    center: { x: 0, opacity: 1 },
    exit: (dir: number) => ({ x: dir > 0 ? -80 : 80, opacity: 0 }),
  };

  const totalSteps = jlptLevel === 'N5' ? 4 : 3;
  const isGoalStep =
    (step === 3 && jlptLevel !== 'N5') || step === 4;

  async function handleComplete() {
    if (!nickname || !jlptLevel || !goal) return;
    setLoading(true);
    setError('');

    try {
      const res = await fetch('/api/v1/auth/onboarding', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ nickname, jlptLevel, goal, showKana }),
      });

      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.error || '오류가 발생했습니다');
      }

      router.push('/home');
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : '오류가 발생했습니다');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="from-background to-secondary flex min-h-dvh flex-col items-center justify-center bg-gradient-to-b px-6">
      {/* Progress */}
      <div className="mb-8 flex items-center gap-2">
        {Array.from({ length: totalSteps }, (_, i) => i + 1).map((s) => (
          <motion.div
            key={s}
            className="h-1.5 w-12 rounded-full"
            animate={{
              backgroundColor: s <= step ? 'var(--color-primary)' : 'var(--color-border)',
            }}
            transition={{ duration: 0.3 }}
          />
        ))}
      </div>

      <AnimatePresence mode="wait" custom={directionRef.current}>
        {/* Step 1: Nickname */}
        {step === 1 && (
          <motion.div
            key="step-1"
            custom={directionRef.current}
            variants={slideVariants}
            initial="enter"
            animate="center"
            exit="exit"
            transition={{ duration: 0.25, ease: 'easeInOut' }}
            className="w-full max-w-sm"
          >
            <Card>
              <CardContent className="flex flex-col gap-6 p-6">
                <div className="text-center">
                  <FoxMascot size={48} className="mb-2" />
                  <h2 className="text-xl font-bold">반가워요!</h2>
                  <p className="text-muted-foreground mt-1 text-sm">
                    어떻게 불러드릴까요?
                  </p>
                </div>
                <Input
                  placeholder="닉네임을 입력해주세요"
                  value={nickname}
                  onChange={(e) => setNickname(e.target.value)}
                  className="h-12 rounded-xl text-center text-lg"
                  maxLength={20}
                  autoFocus
                />
                <Button
                  className="h-12 rounded-xl text-base"
                  disabled={nickname.trim().length < 1}
                  onClick={() => goTo(2)}
                >
                  다음 →
                </Button>
              </CardContent>
            </Card>
          </motion.div>
        )}

        {/* Step 2: JLPT Level */}
        {step === 2 && (
          <motion.div
            key="step-2"
            custom={directionRef.current}
            variants={slideVariants}
            initial="enter"
            animate="center"
            exit="exit"
            transition={{ duration: 0.25, ease: 'easeInOut' }}
            className="w-full max-w-sm"
          >
            <Card>
              <CardContent className="flex flex-col gap-4 p-6">
                <div className="text-center">
                  <FoxMascot size={48} className="mb-2" />
                  <h2 className="text-xl font-bold">일본어, 얼마나 알고 계세요?</h2>
                </div>
                <div className="flex flex-col gap-2.5">
                  {LEVELS.map((level) => (
                    <button
                      key={level.value}
                      className={`flex items-center gap-3 rounded-xl border-2 p-4 text-left transition-all ${
                        jlptLevel === level.value
                          ? 'border-primary bg-primary/10'
                          : 'border-border hover:border-primary/50'
                      }`}
                      onClick={() => {
                        setJlptLevel(level.value);
                        setShowKana(level.value === 'N5');
                      }}
                    >
                      <span className="flex size-10 items-center justify-center rounded-full bg-primary/10">
                        <level.Icon className="size-5 text-primary" />
                      </span>
                      <div className="flex-1">
                        <p className="font-semibold">{level.label}</p>
                        <p className="text-muted-foreground text-sm">
                          {level.desc}
                        </p>
                      </div>
                    </button>
                  ))}
                </div>
                <div className="flex gap-2">
                  <Button
                    variant="outline"
                    className="h-12 flex-1 rounded-xl"
                    onClick={() => goTo(1)}
                  >
                    ← 이전
                  </Button>
                  <Button
                    className="h-12 flex-1 rounded-xl text-base"
                    disabled={!jlptLevel}
                    onClick={() => goTo(3)}
                  >
                    다음 →
                  </Button>
                </div>
              </CardContent>
            </Card>
          </motion.div>
        )}

        {/* Step 3 (N5 only): Kana question */}
        {step === 3 && jlptLevel === 'N5' && (
          <motion.div
            key="step-3-kana"
            custom={directionRef.current}
            variants={slideVariants}
            initial="enter"
            animate="center"
            exit="exit"
            transition={{ duration: 0.25, ease: 'easeInOut' }}
            className="w-full max-w-sm"
          >
            <Card>
              <CardContent className="flex flex-col gap-4 p-6">
                <div className="text-center">
                  <FoxMascot size={48} className="mb-2" />
                  <h2 className="text-xl font-bold">
                    히라가나/가타카나부터 배워볼까요?
                  </h2>
                  <p className="text-muted-foreground mt-1 text-sm">
                    일본어의 기초 문자를 먼저 학습할 수 있어요
                  </p>
                </div>
                <div className="flex flex-col gap-2.5">
                  <button
                    className={`rounded-xl border-2 p-4 text-left transition-all ${
                      showKana
                        ? 'border-primary bg-primary/10'
                        : 'border-border hover:border-primary/50'
                    }`}
                    onClick={() => setShowKana(true)}
                  >
                    <p className="font-semibold">네, 기초부터 배울래요</p>
                    <p className="text-muted-foreground text-sm">
                      히라가나/가타카나부터 차근차근 시작해요
                    </p>
                  </button>
                  <button
                    className={`rounded-xl border-2 p-4 text-left transition-all ${
                      !showKana
                        ? 'border-primary bg-primary/10'
                        : 'border-border hover:border-primary/50'
                    }`}
                    onClick={() => setShowKana(false)}
                  >
                    <p className="font-semibold">건너뛸게요</p>
                    <p className="text-muted-foreground text-sm">
                      이미 가나를 알고 있어요
                    </p>
                  </button>
                </div>
                <div className="flex gap-2">
                  <Button
                    variant="outline"
                    className="h-12 flex-1 rounded-xl"
                    onClick={() => goTo(2)}
                  >
                    ← 이전
                  </Button>
                  <Button
                    className="h-12 flex-1 rounded-xl text-base"
                    onClick={() => goTo(4)}
                  >
                    다음 →
                  </Button>
                </div>
              </CardContent>
            </Card>
          </motion.div>
        )}

        {/* Goal step: step 3 for non-N5, step 4 for N5 */}
        {isGoalStep && (
          <motion.div
            key="step-goal"
            custom={directionRef.current}
            variants={slideVariants}
            initial="enter"
            animate="center"
            exit="exit"
            transition={{ duration: 0.25, ease: 'easeInOut' }}
            className="w-full max-w-sm"
          >
            <Card>
              <CardContent className="flex flex-col gap-4 p-6">
                <div className="text-center">
                  <FoxMascot size={48} className="mb-2" />
                  <h2 className="text-xl font-bold">목표를 정해볼까요?</h2>
                </div>
                <div className="grid grid-cols-2 gap-2.5">
                  {GOALS.map((g) => (
                    <button
                      key={g.value}
                      className={`flex flex-col items-center gap-1.5 rounded-xl border-2 p-4 transition-all ${
                        goal === g.value
                          ? 'border-primary bg-primary/10'
                          : 'border-border hover:border-primary/50'
                      }`}
                      onClick={() => setGoal(g.value)}
                    >
                      <span className="flex size-10 items-center justify-center rounded-full bg-primary/10">
                        <g.Icon className="size-5 text-primary" />
                      </span>
                      <span className="text-sm font-medium">{g.label}</span>
                    </button>
                  ))}
                </div>

                {error && (
                  <p className="text-destructive text-center text-sm">{error}</p>
                )}

                <div className="flex gap-2">
                  <Button
                    variant="outline"
                    className="h-12 flex-1 rounded-xl"
                    onClick={() => goTo(jlptLevel === 'N5' ? 3 : 2)}
                  >
                    ← 이전
                  </Button>
                  <Button
                    className="h-12 flex-1 rounded-xl text-base"
                    disabled={!goal || loading}
                    onClick={handleComplete}
                  >
                    {loading ? '설정 중...' : '시작하기'}
                  </Button>
                </div>
              </CardContent>
            </Card>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
